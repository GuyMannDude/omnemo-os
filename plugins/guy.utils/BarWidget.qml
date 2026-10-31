import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A wrench on the right of the bar, next to the sound icon. Omarchy's own
// panels (Wi-Fi, Bluetooth, Display, Weather, World clocks) sit folded in the
// bar's "^" tray drawer, since a panel only opens while its widget is on the
// bar; this pops up a row of them WITH names, and clicking one opens the
// drawer and that panel. Click the wrench again, press Esc, or click anywhere
// else to close the row.
BarWidget {
  id: root
  moduleName: "guy.utils"

  // Glyphs are written as code points: pasted Nerd Font glyphs get lost.
  function glyph(code) { return String.fromCodePoint(code) }
  // Every command is a fixed argument list (no shell line); the ids are
  // constants written right here.
  function panel(id) { return ["omarchy-shell", "shell", "summon", id, "{}"] }

  readonly property var tools: [
    { glyph: glyph(0xf05a9), label: "Wi-Fi & internet", command: root.panel("omarchy.network") },
    { glyph: glyph(0xf00af), label: "Bluetooth",        command: root.panel("omarchy.bluetooth") },
    { glyph: glyph(0xf0379), label: "Display",          command: root.panel("omarchy.monitor") },
    { glyph: glyph(0xf057e), label: "Sound",            command: root.panel("omarchy.audio") },
    { glyph: glyph(0xf0595), label: "Weather",          command: root.panel("omarchy.weather") },
    { glyph: glyph(0xf01e7), label: "World clocks",     command: root.panel("omarchy.elsewhen") },
    { glyph: glyph(0xf00ed), label: "Calendar",         command: root.panel("guy.clock") },
    { glyph: glyph(0xf0493), label: "All settings",     command: ["omarchy-menu", "toggle"] }
  ]

  property bool popupOpen: false
  function close() { popupOpen = false }

  function run(command) {
    // A list that came through a Repeater's modelData is a Qt list; copy it
    // into a plain array of strings first.
    var argv = []
    for (var i = 0; i < command.length; i++) argv.push(String(command[i]))
    Quickshell.execDetached(argv)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph(0xf05b7)
    active: root.popupOpen
    useActiveColor: false
    tooltipText: root.popupOpen ? "" : "Settings: Wi-Fi, Bluetooth, Display, Sound, Weather, World clocks, Calendar"
    onPressed: function(b) { if (b === Qt.LeftButton) root.popupOpen = !root.popupOpen }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    // Four across, two rows.
    contentWidth: popup.fittedContentWidth(4 * Style.space(96) + popup.padding * 2 + 4)
    contentHeight: popup.fittedContentHeight(choices.implicitHeight)

    Flow {
      id: choices
      anchors.fill: parent
      spacing: Style.space(4)
      // Esc closes the row, like any pop-up menu.
      focus: root.popupOpen
      Keys.onEscapePressed: function(event) { root.close(); event.accepted = true }

      Repeater {
        model: root.tools

        delegate: Rectangle {
          id: choice
          required property var modelData

          width: Style.space(92)
          height: Style.space(86)
          radius: 6
          color: choiceMouse.pressed ? Style.pressedFill : (choiceMouse.containsMouse ? Style.hoverFill : "transparent")

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Style.space(8)
            height: Style.space(30)
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: choice.modelData.glyph
            color: choiceMouse.containsMouse ? Commons.Color.accent : Commons.Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
            font.pixelSize: Style.space(24)
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(6)
            width: parent.width - Style.space(6)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: choice.modelData.label
            color: Commons.Color.foreground
            font.family: Style.fontFamily
            font.pixelSize: Style.font.body - 1
          }

          MouseArea {
            id: choiceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.close()
              root.run(choice.modelData.command)
            }
          }
        }
      }
    }
  }
}
