import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Taskbar, laid out like the Windows one, living inside the bar: buttons for
// the common actions first, then one icon per open window. Click a window to
// bring it up, click the one in front to minimize it, click a minimized one
// to restore it. Right-click a window for Minimize/Restore and Close.
// Hovering any icon shows the bar's own tooltip saying what it is.
BarWidget {
  id: root
  moduleName: "guy.taskbar"
  fixedEdge: "start"

  readonly property int iconSize: 18

  // The pinned buttons. A button with `items` (or a `group` filled from the
  // installed apps) is a category: clicking it pops up a row of choices above
  // it. A category with only one choice opens it straight away.
  readonly property var buttons: [
    { icon: String.fromCodePoint(0xf09d1), label: "AI",       hint: "Pick an AI helper",     items: root.aiItems },
    { icon: String.fromCodePoint(0xf059f), label: "Browsers", hint: "Pick a web browser",    group: "browsers" },
    { icon: String.fromCodePoint(0xf08c6), label: "Web apps", hint: "Pick a web app",        group: "webapps" },
    { icon: String.fromCodePoint(0xf0770), label: "Files",    hint: "Open the file manager", command: "omarchy-launch-nautilus" },
    { icon: String.fromCodePoint(0xf003b), label: "Apps",     hint: "Pick an app to open",   command: "omarchy-menu toggle apps" },
    { icon: String.fromCodePoint(0xf0493), label: "Settings", hint: "Open the Omarchy menu", command: "omarchy-menu toggle" },
    { icon: String.fromCodePoint(0xf05b7), label: "Utils",    hint: "Display, sound, network, Bluetooth, calendar", items: root.utilItems }
  ]

  // Omarchy's own panels. Their icons sit folded in the bar's tray drawer
  // (shell.json bar.layout.tray), since a panel only opens while its icon is
  // on the bar; summoning one from here opens the drawer and the panel.
  function panel(id) { return "omarchy-shell shell summon " + id + " '{}'" }
  readonly property var utilItems: [
    { glyph: String.fromCodePoint(0xf0379), label: "Display",   command: root.panel("omarchy.monitor") },
    { glyph: String.fromCodePoint(0xf057e), label: "Sound",     command: root.panel("omarchy.audio") },
    { glyph: String.fromCodePoint(0xf05a9), label: "Network",   command: root.panel("omarchy.network") },
    { glyph: String.fromCodePoint(0xf00af), label: "Bluetooth", command: root.panel("omarchy.bluetooth") },
    { glyph: String.fromCodePoint(0xf00ed), label: "Calendar",  command: root.panel("guy.clock") }
  ]

  // The OpenAI logo lives in the omarchy font, the same glyph Omarchy's menu uses.
  readonly property var aiItems: [
    { glyph: String.fromCodePoint(0xf018d), label: "Claude",   command: "xdg-terminal-exec claude" },
    { glyph: "", glyphFont: "omarchy", label: "ChatGPT", command: "uwsm-app -- chatgpt" },
    { glyph: String.fromCodePoint(0xf0169), label: "Codex",    command: "xdg-terminal-exec codex" },
    { glyph: String.fromCodePoint(0xf018d), label: "OpenCode", command: "xdg-terminal-exec opencode" }
  ]

  // Installed apps for a category, from the desktop entries: browsers by their
  // WebBrowser category, web apps by the Omarchy web app launcher they run.
  function groupItems(button) {
    if (button.items) return button.items
    var values = DesktopEntries.applications.values
    var out = []
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (!entry || entry.noDisplay) continue
      var exec = String(entry.execString || (entry.command || []).join(" "))
      var match = button.group === "browsers"
        ? (entry.categories || []).indexOf("WebBrowser") !== -1
        : /omarchy-(launch-webapp|webapp-handler)/.test(exec)
      if (!match) continue
      out.push({ entryIcon: entry.icon, label: entry.name, command: ["uwsm-app", "--", String(entry.id) + ".desktop"] })
    }
    out.sort(function(a, b) { return a.label.localeCompare(b.label) })
    return out
  }

  // The category whose choices are showing, and the button they sit above.
  property var flyoutItems: []
  property Item flyoutTile: null
  property bool flyoutOpen: false
  function close() { flyoutOpen = false }

  function buttonPressed(tile, button) {
    if (!button.items && !button.group) {
      root.close()
      root.run(button.command)
      return
    }
    var items = root.groupItems(button)
    if (items.length === 1) {
      root.close()
      root.run(items[0].command)
      return
    }
    if (root.flyoutOpen && root.flyoutTile === tile) {
      root.close()
      return
    }
    root.flyoutItems = items
    root.flyoutTile = tile
    root.flyoutOpen = true
  }

  // Friendly app names for the labels; anything else shows its desktop name.
  readonly property var appNames: ({ "foot": "Terminal", "google-chrome": "Chrome" })

  implicitWidth: row.implicitWidth
  implicitHeight: barSize

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

  // Window addresses come from Hyprland, but check their shape anyway before
  // one goes into a dispatch.
  function validAddress(address) { return /^0x[0-9a-f]+$/.test(String(address)) }

  // Open windows from `hyprctl clients -j`, in the order they were opened.
  // (Quickshell's own window list comes back empty on this Hyprland.)
  property var windows: []

  Process {
    id: listWindows
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Hold the list still while a right-click menu is open on one of its icons.
        if (root.menuFor !== null) return
        var listed
        try { listed = JSON.parse(text || "[]") } catch (e) { return }
        var next = listed
          .filter(function(c) { return c.mapped !== false && (c.title || c["class"]) })
          .sort(function(a, b) { return a.pid - b.pid })
          .map(function(c) {
            var minimized = String(c.workspace && c.workspace.name || "").indexOf("special:minimized") === 0
            return { address: c.address, appId: c["class"], title: c.title, minimized: minimized, activated: c.focusHistoryID === 0 && !minimized }
          })
        // Only swap the list when something changed: a new list rebuilds every
        // icon, which would pull an open right-click menu out from under the mouse.
        if (JSON.stringify(next) !== JSON.stringify(root.windows)) root.windows = next
      }
    }
  }

  function refresh() {
    if (!listWindows.running) listWindows.running = true
  }

  Timer {
    interval: 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  function focusWindow(address) {
    if (!root.validAddress(address)) return
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + address + "\" })"])
    root.refresh()
  }

  // Hyprland has no minimize, so a minimized window is parked on a hidden
  // workspace and brought back to whichever workspace is showing.
  function minimizeWindow(address) {
    if (!root.validAddress(address)) return
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = \"special:minimized\", follow = false, window = \"address:" + address + "\" })"])
    root.refresh()
  }

  function restoreWindow(address) {
    if (!root.validAddress(address)) return
    var target = "address:" + address
    Quickshell.execDetached(["sh", "-c",
      "ws=$(hyprctl activeworkspace -j | jq -r .id); " +
      "hyprctl dispatch \"hl.dsp.window.move({ workspace = \\\"$ws\\\", follow = true, window = \\\"" + target + "\\\" })\"; " +
      "hyprctl dispatch \"hl.dsp.focus({ window = \\\"" + target + "\\\" })\""])
    root.refresh()
  }

  function closeWindow(address) {
    if (!root.validAddress(address)) return
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close({ window = \"address:" + address + "\" })"])
    root.refresh()
  }

  function windowClicked(w) {
    if (w.minimized) root.restoreWindow(w.address)
    else if (w.activated) root.minimizeWindow(w.address)
    else root.focusWindow(w.address)
  }

  function appName(w) {
    var id = String(w.appId || "")
    if (root.appNames[id]) return root.appNames[id]
    var entry = DesktopEntries.heuristicLookup(id)
    return entry && entry.name ? entry.name : id
  }

  function windowIcon(w) {
    var id = String(w.appId || "")
    var entry = DesktopEntries.heuristicLookup(id)
    var path = Quickshell.iconPath(entry && entry.icon ? entry.icon : id, true)
    return path.length > 0 ? path : Quickshell.iconPath("application-x-executable", true)
  }

  function windowLabel(w) {
    var title = String(w.title || "")
    var name = root.appName(w)
    var label = title.length > 0 ? name + ": " + title : name
    if (w.minimized) label += "  (minimized, click to bring back)"
    return label + "  · right-click for Close"
  }

  // The right-click menu: which window it is for and the icon it sits on.
  property var menuFor: null
  property Item menuTile: null

  function openMenu(tile, w) {
    menuTile = null
    menuFor = w
    Qt.callLater(function() { root.menuTile = tile })
  }
  function closeMenu() {
    menuTile = null
    menuFor = null
  }
  // Act on the window first, then close the menu.
  function menuAction(action) {
    var w = root.menuFor
    if (w) {
      if (action === "close") root.closeWindow(w.address)
      else if (w.minimized) root.restoreWindow(w.address)
      else root.minimizeWindow(w.address)
    }
    root.closeMenu()
  }

  Row {
    id: row
    height: parent.height

    Repeater {
      model: root.buttons

      delegate: WidgetButton {
        id: pinnedTile
        required property var modelData
        bar: root.bar
        text: modelData.icon
        fontFamily: modelData.iconFont || (root.bar ? root.bar.fontFamily : Style.font.family)
        active: root.flyoutOpen && root.flyoutTile === pinnedTile
        useActiveColor: false
        tooltipText: root.flyoutOpen && root.flyoutTile === pinnedTile ? "" : modelData.label + ": " + modelData.hint
        onPressed: function(b) { if (b === Qt.LeftButton) root.buttonPressed(pinnedTile, modelData) }
      }
    }

    // A thin line between the buttons and the open windows.
    Item {
      visible: windowRepeater.count > 0
      width: Style.space(9)
      height: parent.height
      Rectangle {
        anchors.centerIn: parent
        width: 1
        height: parent.height * 0.5
        color: Util.alpha(Commons.Color.foreground, 0.25)
      }
    }

    Repeater {
      id: windowRepeater
      model: root.windows

      delegate: WidgetButton {
        id: windowTile
        required property var modelData
        bar: root.bar
        text: ""
        hasVisualContent: true
        fixedWidth: Style.bar.iconSlot + Style.space(4)
        tooltipText: root.windowLabel(modelData)
        onPressed: function(b) {
          if (b === Qt.RightButton) root.openMenu(windowTile, windowTile.modelData)
          else if (b === Qt.LeftButton) root.windowClicked(windowTile.modelData)
        }

        IconImage {
          anchors.centerIn: parent
          opacity: windowTile.modelData.minimized ? 0.4 : 1
          implicitSize: root.iconSize + 2
          source: root.windowIcon(windowTile.modelData)
        }

        // The window in front gets a line under its icon.
        Rectangle {
          visible: windowTile.modelData.activated
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 2
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width - 12
          height: 2
          radius: 1
          color: Commons.Color.accent
        }
      }
    }
  }

  // A category's choices: a row of icons with names, popping up above the
  // button that was clicked. Click one to open it; click the button again or
  // anywhere else to close the row.
  PopupCard {
    id: flyout
    anchorItem: root.flyoutTile || root
    bar: root.bar
    owner: root
    open: root.flyoutOpen
    contentWidth: flyout.fittedContentWidth(Math.min(root.flyoutItems.length, 7) * Style.space(96) + flyout.padding * 2 + 4)
    contentHeight: flyout.fittedContentHeight(choices.implicitHeight)

    Flow {
      id: choices
      anchors.fill: parent
      spacing: Style.space(4)
      // Esc closes the row, like any pop-up menu.
      focus: root.flyoutOpen
      Keys.onEscapePressed: function(event) { root.close(); event.accepted = true }

      Repeater {
        model: root.flyoutItems

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
            font.family: choice.modelData.glyphFont || (root.bar ? root.bar.fontFamily : Style.fontFamily)
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

  // Right-click menu for one window: Minimize (or Restore) and Close. It is
  // the bar's own pop-up card, like the category rows, so clicks land the same
  // way; clicking anywhere else or pressing Esc closes it.
  QtObject {
    id: menuOwner
    function close() { root.closeMenu() }
  }

  PopupCard {
    id: menuPopup
    anchorItem: root.menuTile || root
    bar: root.bar
    owner: menuOwner
    open: root.menuTile !== null && root.menuFor !== null
    contentWidth: menuPopup.fittedContentWidth(Style.space(170) + menuPopup.padding * 2)
    contentHeight: menuPopup.fittedContentHeight(menuColumn.implicitHeight)

    Column {
      id: menuColumn
      anchors.fill: parent
      focus: menuPopup.open
      Keys.onEscapePressed: function(event) { root.closeMenu(); event.accepted = true }

      Repeater {
        model: root.menuFor === null ? [] : [
          { text: root.menuFor.minimized ? "Restore" : "Minimize", action: "minimize" },
          { text: "Close window", action: "close" }
        ]

        delegate: Rectangle {
          id: menuRow
          required property var modelData
          width: menuColumn.width
          height: Style.space(30)
          radius: 4
          color: rowMouse.pressed ? Style.pressedFill : (rowMouse.containsMouse ? Style.hoverFill : "transparent")

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            textFormat: Text.PlainText
            text: menuRow.modelData.text
            color: menuRow.modelData.action === "close" && rowMouse.containsMouse ? Commons.Color.accent : Commons.Color.foreground
            font.family: Style.fontFamily
            font.pixelSize: Style.font.body
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // Hand off to root in one call: closing the menu empties this
            // Repeater, which destroys this row while its handler still runs.
            onClicked: root.menuAction(menuRow.modelData.action)
          }
        }
      }
    }
  }
}
