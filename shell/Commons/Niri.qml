pragma Singleton
// Niri.qml — niri IPC service for the Omarchy shell port.
// Exposes Niri.workspaces (list), Niri.focusedWorkspace (object|null), and
// Niri.windows (list) fed from `niri msg --json event-stream`. Windows carry
// {id, app_id, title, workspace_id, window_size}; helper functions map a
// workspace idx to its window count and its biggest window's app_id, so bar
// widgets can show occupancy + app icons without spawning extra processes.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var workspaces: []
  property var focusedWorkspace: null
  // Live toplevel list from niri's WindowsChanged/WindowOpenedOrChanged/
  // WindowClosed stream. Rebuilt wholesale on WindowsChanged, patched on the
  // per-window events so a single open/close does not need a full snapshot.
  property var windows: []

  function _applyWorkspaces(list) {
    root.workspaces = list
    var f = null
    for (var i = 0; i < list.length; i++) {
      if (list[i].is_focused) { f = list[i]; break }
    }
    root.focusedWorkspace = f
  }

  function _refreshFromJson(txt) {
    try {
      var ws = JSON.parse(txt)
      if (Array.isArray(ws)) root._applyWorkspaces(ws)
    } catch (e) {}
  }

  // niri window -> the numeric idx of the workspace it sits on. niri reports
  // window.workspace_id (the internal id), never the idx, so we translate.
  function workspaceIdxForId(id) {
    var values = root.workspaces
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i].idx
    }
    return -1
  }

  function windowCountOn(idx) {
    var values = root.windows
    var count = 0
    for (var i = 0; i < values.length; i++) {
      if (workspaceIdxForId(values[i].workspace_id) === idx) count++
    }
    return count
  }

  // The app_id of the biggest (by screen area) window on a workspace idx,
  // mirroring illogical-impulse's "biggest window" heuristic so the icon shown
  // for a multi-window workspace is the most recognizable one.
  function biggestWindowAppId(idx) {
    var values = root.windows
    var bestApp = ""
    var bestArea = -1
    for (var i = 0; i < values.length; i++) {
      if (workspaceIdxForId(values[i].workspace_id) !== idx) continue
      var size = values[i].window_size || [0, 0]
      var area = (Number(size[0]) || 0) * (Number(size[1]) || 0)
      if (area > bestArea) {
        bestArea = area
        bestApp = String(values[i].app_id || "")
      }
    }
    return bestApp
  }

  function _removeWindow(windowsList, id) {
    var next = []
    for (var i = 0; i < windowsList.length; i++) {
      if (windowsList[i].id !== id) next.push(windowsList[i])
    }
    return next
  }

  function _upsertWindow(windowsList, win) {
    var next = []
    var replaced = false
    for (var i = 0; i < windowsList.length; i++) {
      if (windowsList[i].id === win.id) { next.push(win); replaced = true }
      else next.push(windowsList[i])
    }
    if (!replaced) next.push(win)
    return next
  }

  // Name of the output niri reports as focused (for panel routing).
  property string focusedOutput: ""

  Process {
    id: focusedOut
    command: ["niri", "msg", "--json", "focused-output"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.focusedOutput = String(JSON.parse(text || "{}").name || "") } catch (e) {}
      }
    }
  }

  function focusWorkspace(id) {
    Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(id)])
  }

  Process {
    id: snapshot
    command: ["niri", "msg", "--json", "workspaces"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root._refreshFromJson(text)
    }
  }

  Process {
    id: windowSnapshot
    command: ["niri", "msg", "--json", "windows"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var win = JSON.parse(text)
          if (Array.isArray(win)) root.windows = win
        } catch (e) {}
      }
    }
  }

  Process {
    id: events
    command: ["niri", "msg", "--json", "event-stream"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        if (!line) return
        var msg = null
        try { msg = JSON.parse(line) } catch (e) { return }
        if (msg && msg.WorkspacesChanged && msg.WorkspacesChanged.workspaces)
          root._applyWorkspaces(msg.WorkspacesChanged.workspaces)
        else if (msg && msg.WorkspaceActivated && msg.WorkspaceActivated.id !== undefined) {
          var ws = root.workspaces.map(function(w) {
            var c = Object.assign({}, w); c.is_focused = (c.id === msg.WorkspaceActivated.id); return c
          })
          root._applyWorkspaces(ws)
        }
        else if (msg && msg.WindowsChanged && msg.WindowsChanged.windows)
          root.windows = msg.WindowsChanged.windows
        else if (msg && msg.WindowOpenedOrChanged && msg.WindowOpenedOrChanged.window)
          root.windows = root._upsertWindow(root.windows, msg.WindowOpenedOrChanged.window)
        else if (msg && msg.WindowClosed && msg.WindowClosed.id !== undefined)
          root.windows = root._removeWindow(root.windows, msg.WindowClosed.id)
      }
    }
  }
}
