import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Ui

// Workspace indicator styled after illogical-impulse's Workspaces.qml: a
// fixed row of slots, an animated pill sliding under the focused workspace,
// occupied workspaces drawn as a translucent capsule that joins with its
// occupied neighbors instead of showing as separate rounded rectangles, and
// the "biggest window's" app icon overlaid on an occupied slot.
//
// PORTED for the Omarchy niri session: reads the port's Niri singleton
// (niri msg --json event-stream) instead of the Quickshell Hyprland
// singleton and dispatches `niri msg action focus-workspace` on click.
// niri reports a workspace's windows via the WindowsChanged stream
// (app_id + workspace_id + window_size), so occupancy and the app-icon
// lookup come from Niri.windowCountOn()/Niri.biggestWindowAppId().
BarWidget {
  id: root
  moduleName: "trevor.ii-workspaces"

  readonly property int shown: Math.max(1, Math.round(Number(setting("shown", 5))))
  readonly property bool showAppIcons: setting("showAppIcons", true) === true
  readonly property real slotSize: root.vertical ? root.barSize : Style.space(20)
  readonly property real pillMargin: 2
  readonly property real iconSize: root.slotSize * 0.62

  // niri: `idx` is the user-facing 1..N workspace number; `id` is a stable
  // internal handle that does NOT match idx. The ii widget draws fixed slots
  // 1..shown, so we key everything on idx.
  function workspaceByIndex(idx) {
    var values = Niri.workspaces
    for (var i = 0; i < values.length; i++) {
      if (values[i].idx === idx) return values[i]
    }
    return null
  }

  function occupied(idx) {
    var workspace = workspaceByIndex(idx)
    if (workspace === null) return false
    return Niri.windowCountOn(idx) > 0
      || (workspace.active_window_id !== null && workspace.active_window_id !== undefined)
  }

  // Best-effort desktop-entry / themed-icon lookup for a window app_id, the
  // same fallback chain the rest of the bar uses (desktop entry -> themed
  // icon name -> generic executable icon).
  function iconSourceForAppId(appId) {
    if (!appId) return ""
    var entry = DesktopEntries.byId ? DesktopEntries.byId(appId) : null
    if (!entry) entry = webappEntryForAppId(appId)
    if (!entry && DesktopEntries.heuristicLookup) entry = DesktopEntries.heuristicLookup(appId)
    if (entry && entry.icon) {
      var path = Quickshell.iconPath(entry.icon, true)
      if (path.length > 0) return path
    }
    var themed = Quickshell.iconPath(appId, true)
    if (themed.length > 0) return themed
    return ""
  }

  // Chromium webapp windows (an omakub/omarchy webapp launcher) get a class
  // chromium derives from the app URL itself (e.g.
  // "chrome-teams.live.com__v2_-Default"), not the app's real desktop-entry
  // id -- so byId()/heuristicLookup() never match them. Recover the app by
  // matching a webapp desktop entry on its StartupWMClass or on the URL host
  // appearing in the class string (the same recovery the Hyprland version used).
  function webappEntryForAppId(appId) {
    var lower = appId.toLowerCase()
    var apps = DesktopEntries.applications ? DesktopEntries.applications.values : []
    for (var i = 0; i < apps.length; i++) {
      var startup = String(apps[i].startupClass || "").toLowerCase()
      if (startup && lower.indexOf(startup) !== -1) return apps[i]
      var exec = apps[i].execString || ""
      var match = exec.match(/(?:omakub|omarchy)-launch-webapp\s+"?([^"\s]+)"?/)
      if (!match) continue
      var host = match[1].replace(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//, "").split(/[\/:?#]/)[0].toLowerCase()
      if (host && lower.indexOf(host) !== -1) return apps[i]
    }
    return null
  }

  readonly property int focusedIdx: Niri.focusedWorkspace ? Niri.focusedWorkspace.idx : 1
  // Recomputed whenever the workspace list, window list, or focus changes so
  // the occupied capsule, active pill, and icons all stay in sync with niri.
  property var occupiedStates: computeOccupiedStates()
  property var iconSources: computeIconSources()

  function computeOccupiedStates() {
    var states = []
    for (var i = 0; i < root.shown; i++) states.push(occupied(i + 1))
    return states
  }

  function computeIconSources() {
    var sources = []
    for (var i = 0; i < root.shown; i++)
      sources.push(iconSourceForAppId(Niri.biggestWindowAppId(i + 1)))
    return sources
  }

  function refreshStates() {
    occupiedStates = computeOccupiedStates()
    iconSources = computeIconSources()
  }

  Connections {
    target: Niri
    function onWorkspacesChanged() { root.refreshStates() }
    function onWindowsChanged() { root.refreshStates() }
    function onFocusedWorkspaceChanged() { root.refreshStates() }
  }

  function focusWorkspace(idx) {
    Niri.focusWorkspace(idx)
  }

  // Slots are square (slotSize) but the widget occupies the full bar height so
  // it lines up with the default Workspaces indicator; the slot row is then
  // centered inside that box rather than hugging the top edge.
  implicitWidth: root.vertical ? slotSize : slotSize * root.shown
  implicitHeight: root.vertical ? slotSize * root.shown : root.barSize

  Item {
    id: slotRow
    anchors.centerIn: parent
    width: root.vertical ? root.slotSize : root.slotSize * root.shown
    height: root.vertical ? root.slotSize * root.shown : root.slotSize

  // ---- Occupied capsule: one rounded rect per slot, radius on the side
  //      facing an unoccupied neighbor only, so adjacent occupied slots melt
  //      into a single pill instead of showing a seam.
  Item {
    id: occupiedLayer
    anchors.fill: parent

    Repeater {
      model: root.shown

      Rectangle {
        required property int index

        readonly property bool isOccupied: root.occupiedStates[index] === true
        readonly property bool leftJoined: index > 0 && root.occupiedStates[index - 1] === true
        readonly property bool rightJoined: index < root.shown - 1 && root.occupiedStates[index + 1] === true

        x: root.vertical ? 0 : index * root.slotSize
        y: root.vertical ? index * root.slotSize : 0
        width: root.slotSize
        height: root.slotSize
        radius: root.slotSize / 2
        topLeftRadius: leftJoined ? 0 : radius
        bottomLeftRadius: leftJoined ? 0 : radius
        topRightRadius: rightJoined ? 0 : radius
        bottomRightRadius: rightJoined ? 0 : radius
        color: Color.foreground
        opacity: isOccupied ? 0.12 : 0

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on topLeftRadius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on bottomLeftRadius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on bottomRightRadius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }
    }
  }

  // ---- Active workspace pill: slides to the focused slot.
  Rectangle {
    id: activePill
    radius: width < height ? width / 2 : height / 2
    color: root.bar ? root.bar.urgent : Color.urgent

    readonly property int activeIndex: Math.max(0, Math.min(root.shown - 1, root.focusedIdx - 1))

    x: root.vertical ? root.pillMargin : activeIndex * root.slotSize + root.pillMargin
    y: root.vertical ? activeIndex * root.slotSize + root.pillMargin : root.pillMargin
    width: root.slotSize - root.pillMargin * 2
    height: root.slotSize - root.pillMargin * 2

    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  }

  // ---- App icons: one per occupied slot, behind the number/click layer so
  //      a click still lands on the WidgetButton above it.
  Item {
    anchors.fill: parent
    visible: root.showAppIcons

    Repeater {
      model: root.shown

      IconImage {
        required property int index
        readonly property bool hasIcon: root.occupiedStates[index] === true && root.iconSources[index] !== ""

        x: root.vertical ? (root.slotSize - implicitSize) / 2 : index * root.slotSize + (root.slotSize - implicitSize) / 2
        y: root.vertical ? index * root.slotSize + (root.slotSize - implicitSize) / 2 : (root.slotSize - implicitSize) / 2
        implicitSize: root.iconSize
        source: hasIcon ? root.iconSources[index] : ""
        // The focused slot keeps its number legible; the icon recedes there.
        opacity: hasIcon ? (root.focusedIdx === index + 1 ? 0 : 0.75) : 0

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }
    }
  }

  // ---- Clickable slots + numbers, on top of the pill and icon layers.
  GridLayout {
    anchors.fill: parent
    columns: root.vertical ? 1 : root.shown
    rows: root.vertical ? root.shown : 1
    columnSpacing: 0
    rowSpacing: 0

    Repeater {
      model: root.shown

      WidgetButton {
        required property int index
        readonly property int workspaceIdx: index + 1
        readonly property bool isFocused: root.focusedIdx === workspaceIdx
        readonly property bool isOccupied: root.occupiedStates[index] === true
        readonly property bool showIcon: root.showAppIcons && isOccupied && root.iconSources[index] !== ""

        bar: root.bar
        // The number recedes once an icon takes over an occupied, unfocused
        // slot -- focused always shows the number so the pill stays legible.
        text: workspaceIdx === 10 ? "0" : String(workspaceIdx)
        opacity: (showIcon && !isFocused) ? 0 : 1
        useActiveColor: false
        foreground: isFocused ? (root.bar ? root.bar.background : Color.background)
          : (isOccupied ? (root.bar ? root.bar.barForeground : Color.foreground) : Color.muted)
        fixedWidth: root.slotSize
        fixedHeight: root.slotSize
        onPressed: function() { root.focusWorkspace(workspaceIdx) }

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }
    }
  }
  }
}
