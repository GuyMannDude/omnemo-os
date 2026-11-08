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

  // The shared menu look (Tints.qml in this folder).
  Tints { id: tints }

  // Glyphs are written as code points: pasted Nerd Font glyphs get lost.
  function glyph(code) { return String.fromCodePoint(code) }
  function panel(id) { return "omarchy-shell shell toggle " + id }
  function menu(page) { return "omarchy-shell shell toggle omarchy.menu '{\"menu\":\"" + page + "\"}'" }

  readonly property var tools: [
    { glyph: glyph(0xf00ec), color: "apps/accessories-calculator", tint: "green", label: "Calculator",   command: "uwsm-app -- omacalc" },
    { glyph: glyph(0xf0100), color: "apps/org.gnome.Screenshot", tint: "orange", label: "Screenshot",   command: "omarchy-capture-screenshot" },
    { glyph: glyph(0xf044b), color: "apps/simplescreenrecorder", tint: "red", label: "Record screen", command: "omarchy-capture-screenrecording --stop-recording || omarchy-menu toggle trigger.capture.screenrecord" },
    { glyph: glyph(0xf020a), color: "apps/gpick", tint: "yellow", label: "Color picker", command: "pkill hyprpicker || hyprpicker -a" },
    { glyph: glyph(0xf01f5), color: "apps/org.gnome.Characters", tint: "yellow", label: "Emoji",        command: root.panel("omarchy.emojis") },
    { glyph: glyph(0xf0a38), color: "apps/gpaste", tint: "cyan", label: "Clipboard",    command: root.panel("omarchy.clipboard") },
    { glyph: glyph(0xf097b), color: "apps/preferences-desktop-keyboard-shortcuts", tint: "blue", label: "Shortcuts", command: "omarchy-menu-keybindings" },
    { glyph: glyph(0xf018d), color: "apps/utilities-terminal", tint: "green", label: "Terminal",     command: "xdg-terminal-exec" },
    { glyph: glyph(0xf03d8), color: "apps/preferences-desktop-wallpaper", tint: "magenta", label: "Theme", command: root.menu("appearance") },
    { glyph: glyph(0xf033e), color: "apps/system-lock-screen", tint: "red", label: "Lock",         command: "omarchy-system-lock" },
    { glyph: glyph(0xf0425), color: "apps/system-shutdown", tint: "red", label: "Restart or shut down", command: root.menu("system") }
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
    // A thin hairline instead of the heavy accent frame.
    borderSpec: Border.flat(tints.hairline(), 1)
    // Four across, so it pops up on the left of the "?".
    contentWidth: popup.fittedContentWidth(tints.cardWidth(root.tools.length, popup.padding))
    contentHeight: popup.fittedContentHeight(choices.implicitHeight)

    Flow {
      id: choices
      anchors.fill: parent
      spacing: tints.gap
      // Esc closes the row, like any pop-up menu.
      focus: root.popupOpen
      Keys.onEscapePressed: function(event) { root.close(); event.accepted = true }

      Repeater {
        model: root.tools

        delegate: Rectangle {
          id: choice
          required property var modelData

          width: tints.tileW
          height: tints.tileH
          radius: tints.tileRadius
          color: choiceMouse.pressed ? Style.pressedFill : (choiceMouse.containsMouse ? Style.hoverFill : "transparent")

          // A soft pill in the tile's own theme color behind the icon.
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: tints.pillTop
            width: tints.pill
            height: tints.pill
            radius: tints.pillRadius
            color: tints.fill(tints.get(choice.modelData.tint), choiceMouse.containsMouse)
            Behavior on color { ColorAnimation { duration: 120 } }
          }

          // Colored icon (Papirus); the glyph below shows only if it is missing.
          Image {
            id: tileColor
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: tints.pillTop + (tints.pill - tints.icon) / 2
            width: tints.icon
            height: tints.icon
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
            anchors.topMargin: tints.pillTop + (tints.pill - tints.icon) / 2
            height: tints.icon
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: choice.modelData.glyph
            color: tints.get(choice.modelData.tint)
            font.family: root.bar ? root.bar.fontFamily : Style.fontFamily
            font.pixelSize: Style.space(18)
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(4)
            width: parent.width - Style.space(4)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: choice.modelData.label
            color: Commons.Color.foreground
            font.family: Style.fontFamily
            font.pixelSize: Style.font.body - 2
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
