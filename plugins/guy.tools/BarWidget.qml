import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A "Tools ▴" button for the middle of the bar, left of the "?". Its label says out loud that
// more sits above it; hovering names what is there, and clicking pops up a
// row of handy tools. Click one to open it; click the button again, press
// Esc, or click anywhere else to close the row.
BarWidget {
  id: root
  moduleName: "guy.tools"

  // Glyphs are written as code points: pasted Nerd Font glyphs get lost.
  function glyph(code) { return String.fromCodePoint(code) }
  function panel(id) { return "omarchy-shell shell toggle " + id }
  function menu(page) { return "omarchy-shell shell toggle omarchy.menu '{\"menu\":\"" + page + "\"}'" }

  readonly property var tools: [
    { glyph: glyph(0xf00ec), color: "apps/accessories-calculator", label: "Calculator",   command: "uwsm-app -- omacalc" },
    { glyph: glyph(0xf0100), color: "apps/org.gnome.Screenshot", label: "Screenshot",   command: "omarchy-capture-screenshot" },
    { glyph: glyph(0xf044b), color: "apps/simplescreenrecorder", label: "Record screen", command: "omarchy-capture-screenrecording --stop-recording || omarchy-menu toggle trigger.capture.screenrecord" },
    { glyph: glyph(0xf020a), color: "apps/gpick", label: "Color picker", command: "pkill hyprpicker || hyprpicker -a" },
    { glyph: glyph(0xf01f5), color: "apps/org.gnome.Characters", label: "Emoji",        command: root.panel("omarchy.emojis") },
    { glyph: glyph(0xf0a38), color: "apps/gpaste", label: "Clipboard",    command: root.panel("omarchy.clipboard") },
    { glyph: glyph(0xf097b), color: "apps/preferences-desktop-keyboard-shortcuts", label: "Keyboard shortcuts", command: "omarchy-menu-keybindings" },
    { glyph: glyph(0xf018d), color: "apps/utilities-terminal", label: "Terminal",     command: "xdg-terminal-exec" },
    { glyph: glyph(0xf03d8), color: "apps/preferences-desktop-wallpaper", label: "Theme & wallpaper", command: root.menu("appearance") },
    { glyph: glyph(0xf033e), color: "apps/system-lock-screen", label: "Lock",         command: "omarchy-system-lock" },
    { glyph: glyph(0xf0425), color: "apps/system-shutdown", label: "Restart or shut down", command: root.menu("system") }
  ]

  property bool popupOpen: false
  function close() { popupOpen = false }
  // `omarchy-shell shell summon guy.tools {}` opens this menu (for shortcuts and help).
  function open() { popupOpen = true }
  readonly property bool opened: popupOpen

  function run(command) {
    Quickshell.execDetached(["sh", "-c", command])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "Tools " + root.glyph(0xf0143)
    active: root.popupOpen
    useActiveColor: false
    tooltipText: root.popupOpen ? "" : "More tools above: Calculator, Screenshot, Record screen, Color picker, Emoji, Clipboard, Shortcuts, Terminal, Theme, Lock, Restart or shut down"
    onPressed: function(b) { if (b === Qt.LeftButton) root.popupOpen = !root.popupOpen }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    // Four across, so it pops up on the left of the "?".
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

          // Colored icon (Papirus); the glyph below shows only if it is missing.
          Image {
            id: tileColor
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Style.space(8)
            width: Style.space(30)
            height: Style.space(30)
            sourceSize.width: 48
            sourceSize.height: 48
            smooth: true
            source: choice.modelData.color ? "file://" + Quickshell.env("HOME") + "/.local/share/omnemo-os/icons/48x48/" + choice.modelData.color + ".svg" : ""
            visible: status === Image.Ready
          }

          Text {
            visible: tileColor.status !== Image.Ready
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
