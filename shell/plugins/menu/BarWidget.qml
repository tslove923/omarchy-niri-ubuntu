import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\ue900"
    fontFamily: "omarchy"
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) {
        root.bar.run("xdg-terminal-exec")
        return
      }
      // Summon/toggle the menu through the shell object in-process. Shelling
      // out to `omarchy-shell` fails on this port because Util.execDetached
      // runs `bash -lc`, whose login shell has neither OMARCHY_PATH nor
      // WAYLAND_DISPLAY set, so the wrapper exits before reaching IPC.
      var s = root.bar.shell
      if (s && typeof s.toggle === "function") {
        s.toggle("omarchy.menu", "{\"menu\":\"root\"}")
      } else if (s && typeof s.summon === "function") {
        s.summon("omarchy.menu", "{\"menu\":\"root\"}")
      } else {
        root.bar.run("env OMARCHY_PATH=\"$OMARCHY_PATH\" WAYLAND_DISPLAY=\"$WAYLAND_DISPLAY\" omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
      }
    }
  }
}
