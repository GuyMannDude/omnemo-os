import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A "Favorites ▴" button for the middle of the bar, right of the "?". It pops
// up the apps pinned to the dock (the same list, read fresh each time it
// opens), so the dock's apps are one visible click away. Click one to open
// it; click the button again, press Esc, or click anywhere else to close.
BarWidget {
  id: root
  moduleName: "guy.favorites"

  // The shared menu look (Tints.qml in this folder).
  Tints { id: tints }

  // Glyphs are written as code points: pasted Nerd Font glyphs get lost.
  function glyph(code) { return String.fromCodePoint(code) }

  // "All apps" first, then the dock's pins in the dock's order.
  property var pinnedIds: []
  readonly property var tools: {
    var appsRevision = DesktopEntries.applications.values.length
    var out = [{ glyph: glyph(0xf003b), color: "apps/appgrid", label: "All apps", command: "omarchy-menu toggle apps" }]
    for (var i = 0; i < root.pinnedIds.length; i++) {
      var entry = DesktopEntries.byId(root.pinnedIds[i])
      if (!entry) continue
      out.push({ id: String(entry.id), entryIcon: entry.icon, label: entry.name, command: ["uwsm-app", "--", String(entry.id) + ".desktop"] })
    }
    return out
  }

  Process {
    id: readPins
    command: ["omarchy", "dock", "pinned"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.pinnedIds = String(text || "").split("\n").filter(function(l) { return l.trim().length > 0 }).map(function(l) { return l.trim() })
    }
  }

  property bool popupOpen: false

  // Omarchy's own apps have no Papirus icon under their own names.
  readonly property var colorAlias: ({ "omacalc": "accessories-calculator", "omawrite": "accessories-text-editor" })
  function aliasIcon(name) { return root.colorAlias[name] || name }
  function close() { popupOpen = false }
  // `omarchy-shell shell summon guy.favorites {}` opens this menu (for shortcuts and help).
  function open() { popupOpen = true }
  readonly property bool opened: popupOpen

  // A right-clicked favorite asks "Remove?" and goes on the next click; moving
  // off it, or closing the pop-up, changes nothing.
  property string removing: ""
  onPopupOpenChanged: if (!popupOpen) removing = ""

  function unpin(id) {
    root.run(["omarchy", "dock", "unpin", id])
    root.pinnedIds = root.pinnedIds.filter(function(other) { return other !== id })
    root.removing = ""
  }

  // Start the app first, then close the pop-up, all inside root, since
  // closing can rebuild the tiles and destroy the one that was clicked.
  function launch(command) {
    root.run(command)
    root.close()
  }

  // A command is either an argument list, run as is, or a line for the shell.
  // A list that came through a Repeater's modelData is a Qt list, which
  // Array.isArray does not recognize, so copy it into a plain array first.
  function run(command) {
    if (typeof command === "string") {
      Quickshell.execDetached(["sh", "-c", command])
      return
    }
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
    text: "Favorites " + root.glyph(0xf0143)
    active: root.popupOpen
    useActiveColor: false
    tooltipText: root.popupOpen ? "" : "Your favorite apps. To add one, right-click its window on the taskbar. To remove one, right-click it here"
    onPressed: function(b) {
      if (b !== Qt.LeftButton) return
      if (!root.popupOpen && !readPins.running) readPins.running = true
      root.popupOpen = !root.popupOpen
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
    // Four across, so it pops up on the right of the "?".
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
            color: tints.fill(tints.forName(choice.modelData.label), choiceMouse.containsMouse)
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
            source: choice.modelData.color ? "file://" + Quickshell.env("HOME") + "/.local/share/omnemo-os/icons/48x48/" + choice.modelData.color + ".svg" : (choice.modelData.entryIcon ? "file://" + Quickshell.env("HOME") + "/.local/share/omnemo-os/icons/48x48/" + "apps/" + root.aliasIcon(String(choice.modelData.entryIcon)) + ".svg" : "")
            visible: status === Image.Ready
          }

          IconImage {
            visible: !!choice.modelData.entryIcon && tileColor.status !== Image.Ready
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: tints.pillTop + (tints.pill - tints.icon) / 2
            implicitSize: tints.icon
            source: choice.modelData.entryIcon ? Quickshell.iconPath(choice.modelData.entryIcon, "application-x-executable") : ""
          }

          Text {
            visible: !choice.modelData.entryIcon && tileColor.status !== Image.Ready
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: tints.pillTop + (tints.pill - tints.icon) / 2
            height: tints.icon
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: choice.modelData.glyph || ""
            color: choiceMouse.containsMouse ? Commons.Color.accent : Commons.Color.foreground
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
            text: root.removing !== "" && root.removing === choice.modelData.id ? "Remove?" : choice.modelData.label
            color: root.removing !== "" && root.removing === choice.modelData.id ? Commons.Color.accent : Commons.Color.foreground
            font.family: Style.fontFamily
            font.pixelSize: Style.font.body - 2
          }

          MouseArea {
            id: choiceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onExited: if (root.removing === choice.modelData.id) root.removing = ""
            onClicked: function(mouse) {
              var id = choice.modelData.id || ""
              if (mouse.button === Qt.RightButton) { if (id) root.removing = id }
              else if (id && root.removing === id) root.unpin(id)
              else root.launch(choice.modelData.command)
            }
          }
        }
      }
    }
  }
}
