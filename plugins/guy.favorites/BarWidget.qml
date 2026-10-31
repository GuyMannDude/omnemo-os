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

  // Glyphs are written as code points: pasted Nerd Font glyphs get lost.
  function glyph(code) { return String.fromCodePoint(code) }

  // "All apps" first, then the dock's pins in the dock's order.
  property var pinnedIds: []
  readonly property var tools: {
    var appsRevision = DesktopEntries.applications.values.length
    var out = [{ glyph: glyph(0xf003b), label: "All apps", command: "omarchy-menu toggle apps" }]
    for (var i = 0; i < root.pinnedIds.length; i++) {
      var entry = DesktopEntries.byId(root.pinnedIds[i])
      if (!entry) continue
      out.push({ entryIcon: entry.icon, label: entry.name, command: ["uwsm-app", "--", String(entry.id) + ".desktop"] })
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
  function close() { popupOpen = false }

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
    tooltipText: root.popupOpen ? "" : "Your favorite apps above: the ones pinned to the dock"
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
    // Four across, so it pops up on the right of the "?".
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

          IconImage {
            visible: !!choice.modelData.entryIcon
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Style.space(8)
            implicitSize: Style.space(30)
            source: choice.modelData.entryIcon ? Quickshell.iconPath(choice.modelData.entryIcon, "application-x-executable") : ""
          }

          Text {
            visible: !choice.modelData.entryIcon
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Style.space(8)
            height: Style.space(30)
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: choice.modelData.glyph || ""
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
            onClicked: root.launch(choice.modelData.command)
          }
        }
      }
    }
  }
}
