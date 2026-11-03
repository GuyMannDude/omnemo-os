import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A clock icon in place of the clock's text, to save room on the bar. Hover
// it for the day, date and time; click it for a month calendar with today
// marked. The arrows page through months; click the month name to come back
// to today. Esc, a click elsewhere, or the icon again closes it.
BarWidget {
  id: root
  moduleName: "guy.clock"

  property date now: new Date()
  // The month the calendar shows: its year and month (0-11).
  property int shownYear: now.getFullYear()
  property int shownMonth: now.getMonth()

  property bool popupOpen: false
  readonly property bool opened: popupOpen
  // The shell's summon (the Utils strip's Calendar) calls these.
  function open() { root.showToday(); popupOpen = true }
  function close() { popupOpen = false }

  function showToday() {
    root.now = new Date()
    root.shownYear = root.now.getFullYear()
    root.shownMonth = root.now.getMonth()
  }
  function page(step) {
    var d = new Date(root.shownYear, root.shownMonth + step, 1)
    root.shownYear = d.getFullYear()
    root.shownMonth = d.getMonth()
  }

  // Six weeks of days starting on the Sunday on or before the 1st.
  readonly property var days: {
    var first = new Date(root.shownYear, root.shownMonth, 1)
    var start = new Date(root.shownYear, root.shownMonth, 1 - first.getDay())
    var out = []
    for (var i = 0; i < 42; i++) {
      var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
      out.push({
        day: d.getDate(),
        inMonth: d.getMonth() === root.shownMonth,
        today: d.toDateString() === root.now.toDateString()
      })
    }
    return out
  }

  Timer {
    interval: 15000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: colorIcon.status === Image.Ready ? "" : String.fromCodePoint(0xf0954)
    hasVisualContent: colorIcon.status === Image.Ready
    active: root.popupOpen
    useActiveColor: false
    tooltipText: root.popupOpen ? "" : Qt.formatDateTime(root.now, "dddd, MMMM d  ·  h:mm AP") + "  · click for the calendar"
    onPressed: function(b) {
      if (b !== Qt.LeftButton) return
      if (root.popupOpen) root.close()
      else root.open()
    }

    // Colored icon (Papirus); the glyph above shows only if it is missing.
    Image {
      id: colorIcon
      anchors.centerIn: parent
      width: 22
      height: 22
      sourceSize.width: 48
      sourceSize.height: 48
      smooth: true
      source: "file://" + Quickshell.env("HOME") + "/.local/share/omnemo-os/icons/48x48/apps/org.gnome.clocks.svg"
      visible: status === Image.Ready
    }
  }

  readonly property int cell: Style.space(34)

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(root.cell * 7 + popup.padding * 2 + 4)
    contentHeight: popup.fittedContentHeight(calendar.implicitHeight)

    Column {
      id: calendar
      spacing: Style.space(6)
      focus: root.popupOpen
      Keys.onEscapePressed: function(event) { root.close(); event.accepted = true }
      Keys.onLeftPressed: root.page(-1)
      Keys.onRightPressed: root.page(1)

      // Today in words, big.
      Text {
        width: root.cell * 7
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: Qt.formatDateTime(root.now, "h:mm AP")
        color: Commons.Color.foreground
        font.family: Style.fontFamily
        font.pixelSize: Style.font.body * 2
        font.bold: true
      }
      Text {
        width: root.cell * 7
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: Qt.formatDate(root.now, "dddd, MMMM d, yyyy")
        color: Util.alpha(Commons.Color.foreground, 0.75)
        font.family: Style.fontFamily
        font.pixelSize: Style.font.body
      }

      // ‹  October 2026  ›
      Item {
        width: root.cell * 7
        height: root.cell

        Repeater {
          model: [{ step: -1, glyph: 0xf0141, left: true }, { step: 1, glyph: 0xf0142, left: false }]
          delegate: Rectangle {
            required property var modelData
            width: root.cell
            height: root.cell
            x: modelData.left ? 0 : parent.width - width
            radius: 6
            color: arrowMouse.containsMouse ? Style.hoverFill : "transparent"
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: String.fromCodePoint(parent.modelData.glyph)
              color: Commons.Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
              font.pixelSize: Style.font.body + 4
            }
            MouseArea {
              id: arrowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.page(parent.modelData.step)
            }
          }
        }

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: Qt.formatDate(new Date(root.shownYear, root.shownMonth, 1), "MMMM yyyy")
          color: Commons.Color.accent
          font.family: Style.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showToday()
          }
        }
      }

      // Weekday initials, then the days.
      Grid {
        columns: 7

        Repeater {
          model: ["S", "M", "T", "W", "T", "F", "S"]
          delegate: Text {
            required property var modelData
            width: root.cell
            height: Style.space(22)
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: modelData
            color: Util.alpha(Commons.Color.foreground, 0.55)
            font.family: Style.fontFamily
            font.pixelSize: Style.font.body - 1
          }
        }

        Repeater {
          model: root.days
          delegate: Rectangle {
            required property var modelData
            width: root.cell
            height: root.cell - Style.space(4)
            radius: 6
            color: modelData.today ? Commons.Color.accent : "transparent"
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: String(parent.modelData.day)
              color: parent.modelData.today ? Commons.Color.background
                : (parent.modelData.inMonth ? Commons.Color.foreground : Util.alpha(Commons.Color.foreground, 0.3))
              font.family: Style.fontFamily
              font.pixelSize: Style.font.body
              font.bold: parent.modelData.today
            }
          }
        }
      }
    }
  }
}
