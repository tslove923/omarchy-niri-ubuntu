import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui
import "IsoWeek.js" as IsoWeek

// Time / date / ISO work-week label, styled after illogical-impulse's
// ClockWidget.qml + services/DateTime.qml: big time, then a "date • WWnn"
// tail separated by bullets. No popup/calendar -- just the label.
BarWidget {
  id: root
  moduleName: "trevor.ii-clock"

  readonly property string timeFormat: setting("format", "h:mm ap")
  readonly property string dateFormat: setting("dateFormat", "ddd, MM/dd")
  readonly property bool showDate: setting("showDate", true) === true

  property date now: new Date()

  readonly property string timeText: Qt.formatDateTime(root.now, root.timeFormat)
  readonly property string dateText: Qt.formatDateTime(root.now, root.dateFormat)
  readonly property string weekText: IsoWeek.isoWeekLabel(root.now)

  function refresh() { root.now = new Date() }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "trevor.ii-clock"
    function refresh(): void { root.broadcast("refresh") }
  }

  implicitWidth: row.implicitWidth + Style.spacing.controlPaddingX * 2
  implicitHeight: root.barSize

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(4)
    visible: !root.vertical

    Text {
      text: root.timeText
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
    }

    Text {
      visible: root.showDate
      text: "•"
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      opacity: 0.6
    }

    Text {
      visible: root.showDate
      text: root.dateText
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      opacity: 0.85
    }

    Text {
      visible: root.showDate
      text: "•"
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      opacity: 0.6
    }

    Text {
      visible: root.showDate
      text: root.weekText
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      opacity: 0.85
    }
  }

  // Vertical bars aren't in scope for this port; fall back to a bare time
  // stack rather than rendering nothing if the bar is ever turned sideways.
  Column {
    anchors.centerIn: parent
    visible: root.vertical
    spacing: Style.space(2)

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.timeText
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
    }
  }
}
