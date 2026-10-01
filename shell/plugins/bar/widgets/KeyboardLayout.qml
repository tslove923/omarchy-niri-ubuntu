import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "KeyboardLayoutModel.js" as KeyboardLayoutModel

// Ported for niri: reads `niri msg --json keyboard-layouts` ({names, current_idx})
// instead of `hyprctl -j devices`. Reuses KeyboardLayoutModel.shortLabel for the
// brief label. Hides itself when only one layout is configured.
BarWidget {
  id: root
  moduleName: "omarchy.keyboard-layout"

  property var layoutNames: []
  property int currentIdx: 0
  property var layoutBriefs: ({})

  readonly property string layoutFull: (currentIdx >= 0 && currentIdx < layoutNames.length) ? String(layoutNames[currentIdx]) : ""
  readonly property string layoutLabel: KeyboardLayoutModel.shortLabel(layoutFull, layoutBriefs)
  readonly property bool multipleLayouts: layoutNames.length > 1

  function refresh() { queryProc.running = true }
  function cycleLayout() {
    root.bar && root.bar.run ? root.bar.run("niri msg action switch-layout next")
                             : Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])
    refreshTimer.restart()
  }

  Component.onCompleted: { briefsProc.running = true; refresh() }

  Process {
    id: queryProc
    command: ["niri", "msg", "--json", "keyboard-layouts"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (Array.isArray(d.names)) {
            root.layoutNames = d.names
            root.currentIdx = (typeof d.current_idx === "number") ? d.current_idx : 0
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: briefsProc
    command: ["xkbcli", "list", "--load-exotic"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.layoutBriefs = KeyboardLayoutModel.layoutBriefs(text)
    }
  }

  Timer { id: refreshTimer; interval: 600; onTriggered: root.refresh() }

  // Re-poll so an xkb change reaches the label even without an event.
  Timer { interval: 10000; running: root.multipleLayouts; repeat: true; onTriggered: root.refresh() }

  visible: layoutLabel !== "" && multipleLayouts
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.layoutLabel
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: root.layoutFull
    onPressed: function() { root.cycleLayout() }
  }
}
