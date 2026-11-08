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

  // The shared menu look (Tints.qml in this folder).
  Tints { id: tints }

  // Glyphs are written as code points: pasted Nerd Font glyphs get lost.
  function glyph(code) { return String.fromCodePoint(code) }
  // Every command is a fixed argument list (no shell line); the ids are
  // constants written right here.
  function panel(id) { return ["omarchy-shell", "shell", "summon", id, "{}"] }

  readonly property var tools: [
    { glyph: glyph(0xf05a9), color: "apps/nm-device-wireless", tint: "blue", label: "Wi-Fi & internet", command: root.panel("omarchy.network") },
    { glyph: glyph(0xf00af), color: "apps/blueman", tint: "blue", label: "Bluetooth",        command: root.panel("omarchy.bluetooth") },
    { glyph: glyph(0xf0379), color: "devices/video-display", tint: "cyan", label: "Display",          command: root.panel("omarchy.monitor") },
    { glyph: glyph(0xf057e), color: "apps/preferences-desktop-sound", tint: "cyan", label: "Sound",            command: root.panel("omarchy.audio") },
    { glyph: glyph(0xf0595), color: "apps/org.gnome.Weather", tint: "yellow", label: "Weather",          command: root.panel("omarchy.weather") },
    { glyph: glyph(0xf01e7), color: "apps/org.gnome.clocks", tint: "orange", label: "World clocks",     command: root.panel("omarchy.elsewhen") },
    { glyph: glyph(0xf00ed), color: "apps/org.gnome.Calendar", tint: "magenta", label: "Calendar",         command: root.panel("guy.clock") },
    { glyph: glyph(0xf0493), color: "apps/org.gnome.Settings", tint: "green", label: "All settings",     command: ["omarchy-menu", "toggle"] }
  ]

  property bool popupOpen: false
  function close() { popupOpen = false }
  // `omarchy-shell shell summon guy.utils {}` opens this menu (for shortcuts and help).
  function open() { popupOpen = true }
  readonly property bool opened: popupOpen

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
    text: colorIcon.status === Image.Ready ? "" : root.glyph(0xf05b7)
    hasVisualContent: colorIcon.status === Image.Ready
    active: root.popupOpen
    useActiveColor: false
    tooltipText: root.popupOpen ? "" : "Settings: Wi-Fi, Bluetooth, Display, Sound, Weather, World clocks, Calendar"
    onPressed: function(b) { if (b === Qt.LeftButton) root.popupOpen = !root.popupOpen }

    // Colored icon (Papirus); the glyph above shows only if it is missing.
    Image {
      id: colorIcon
      anchors.centerIn: parent
      width: 22
      height: 22
      sourceSize.width: 48
      sourceSize.height: 48
      smooth: true
      source: "file://" + Quickshell.env("HOME") + "/.local/share/omnemo-os/icons/48x48/apps/preferences-system.svg"
      visible: status === Image.Ready
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    // A thin hairline instead of the heavy accent frame.
    borderSpec: Border.flat(tints.hairline(), 1)
    // Four across, two rows.
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
