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

  readonly property int iconSize: 20

  // Colored icons: the Papirus 48x48 set in ~/.local/share/omnemo-os/icons (downloaded and
  // kept current by Omnemo OS). Any icon it lacks falls back to the theme
  // icon, then to the old one-color glyph, so a missing set never blanks a button.
  readonly property string colorIcons: Quickshell.env("HOME") + "/.local/share/omnemo-os/icons/48x48/"
  function colorIcon(rel) { return "file://" + root.colorIcons + rel + ".svg" }

  // Omarchy's own apps have no Papirus icon under their own names.
  readonly property var colorAlias: ({ "omacalc": "accessories-calculator", "omawrite": "accessories-text-editor" })
  function aliasIcon(name) { return root.colorAlias[name] || name }

  // The pinned buttons. A button with `items` (or a `group` filled from the
  // installed apps) is a category: clicking it pops up a row of choices above
  // it. A category with only one choice opens it straight away.
  readonly property var buttons: [
    { icon: String.fromCodePoint(0xf09d1), color: "apps/gbrainy", label: "AI",       hint: "Pick an AI helper",     items: root.aiItems },
    { icon: String.fromCodePoint(0xf059f), color: "apps/applications-webbrowsers", label: "Browsers", hint: "Pick a web browser",    group: "browsers" },
    { icon: String.fromCodePoint(0xf08c6), color: "apps/applications-webapps", label: "Web apps", hint: "Pick a web app",        group: "webapps" },
    { icon: String.fromCodePoint(0xf0770), color: "places/folder", label: "Files",    hint: "Open the file manager", command: "omarchy-launch-nautilus" },
    { icon: String.fromCodePoint(0xf003b), color: "apps/appgrid", label: "Apps",     hint: "Pick an app to open",   command: "omarchy-menu toggle apps" },
    { icon: String.fromCodePoint(0xf0493), color: "apps/org.gnome.Settings", label: "Settings", hint: "Open the Omarchy menu", command: "omarchy-menu toggle" }
  ]
  // (The Utils wrench moved to the right of the bar as its own widget, guy.utils.)

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

  // None of the AI helpers come with Omarchy. Claude and ChatGPT open their
  // installed app when there is one and their website otherwise; the coding
  // tools (Codex, OpenCode) only show up once they are installed.
  property var aiCommands: []

  Process {
    id: findAi
    command: ["sh", "-c", "for c in claude codex opencode; do command -v \"$c\" >/dev/null 2>&1 && echo \"$c\"; done"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.aiCommands = String(text || "").split("\n").filter(function(l) { return l.length > 0 })
    }
  }

  // The OpenAI logo lives in the omarchy font, the same glyph Omarchy's menu uses.
  readonly property var aiItems: {
    var appsRevision = DesktopEntries.applications.values.length
    var has = function(c) { return root.aiCommands.indexOf(c) !== -1 }
    var out = []
    out.push({ glyph: String.fromCodePoint(0xf018d), color: "apps/utilities-terminal", label: "Claude",
               command: has("claude") ? "xdg-terminal-exec claude" : "omarchy-launch-webapp https://claude.ai/" })
    out.push({ glyph: "", glyphFont: "omarchy", label: "ChatGPT",
               command: DesktopEntries.byId("chatgpt") ? "uwsm-app -- chatgpt" : "omarchy-launch-webapp https://chatgpt.com/" })
    if (has("codex")) out.push({ glyph: String.fromCodePoint(0xf0169), color: "apps/utilities-terminal", label: "Codex", command: "xdg-terminal-exec codex" })
    if (has("opencode")) out.push({ glyph: String.fromCodePoint(0xf018d), color: "apps/utilities-terminal", label: "OpenCode", command: "xdg-terminal-exec opencode" })
    return out
  }

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
    if (button.label === "AI" && !findAi.running) findAi.running = true
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
    root.measureRoom()
  }

  // Window icons stop before the next widget on the bar (the menus in the
  // middle); the windows that don't fit sit behind a "+N" button.
  readonly property int windowSlot: Style.bar.iconSlot + Style.space(4)
  property int slotsThatFit: 999

  function measureRoom() {
    try {
      var top = root
      while (top.parent) top = top.parent
      var start = separator.mapToItem(top, separator.width, 0).x
      var limit = top.width
      var stack = [top]
      while (stack.length > 0) {
        var item = stack.pop()
        if (item !== root && item.moduleName !== undefined && item.moduleName !== "" && item.visible && item.width > 0) {
          var x = item.mapToItem(top, 0, 0).x
          if (x > start && x < limit) limit = x
          continue
        }
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) stack.push(kids[i])
      }
      var fit = Math.floor((limit - start - Style.space(12)) / root.windowSlot)
      if (fit !== root.slotsThatFit) root.slotsThatFit = Math.max(1, fit)
    } catch (e) {}
  }

  // The windows shown on the bar, in the order they were opened; the one in
  // front always stays visible.
  readonly property var shownWindows: {
    var all = root.windows
    if (all.length <= root.slotsThatFit) return all
    var n = Math.max(0, root.slotsThatFit - 1)
    var shown = all.slice(0, n)
    for (var i = n; i < all.length; i++) {
      if (all[i].activated && n > 0) { shown[n - 1] = all[i]; break }
    }
    return shown
  }
  readonly property var hiddenWindows: {
    var shown = root.shownWindows.map(function(w) { return w.address })
    return root.windows.filter(function(w) { return shown.indexOf(w.address) === -1 })
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

  function windowIconName(w) {
    var id = String(w.appId || "")
    var entry = DesktopEntries.heuristicLookup(id)
    return entry && entry.icon ? String(entry.icon) : id
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
    return label + "  · right-click for more"
  }

  // The right-click menu: which window it is for and the icon it sits on.
  property var menuFor: null
  property Item menuTile: null

  function openMenu(tile, w) {
    if (!readPins.running) readPins.running = true
    menuTile = null
    menuFor = w
    Qt.callLater(function() { root.menuTile = tile })
  }
  function closeMenu() {
    menuTile = null
    menuFor = null
  }
  // Act on the window first, then close the menu.
  // The app's desktop entry id, which is what Favorites keeps; empty when the
  // window belongs to nothing launchable.
  function favoriteId(w) {
    var entry = w ? DesktopEntries.heuristicLookup(String(w.appId || "")) : null
    return entry && entry.id ? String(entry.id) : ""
  }

  // The apps in Favorites, read fresh each time a right-click menu opens, so
  // the menu offers to add an app or to take it out.
  property var pinnedIds: []

  Process {
    id: readPins
    command: ["omarchy", "dock", "pinned"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.pinnedIds = String(text || "").split("\n").map(function(l) { return l.trim() }).filter(function(l) { return l.length > 0 })
    }
  }

  function menuRows(w) {
    if (w === null) return []
    var rows = [
      { text: w.minimized ? "Restore" : "Minimize", action: "minimize" },
      { text: "Close window", action: "close" }
    ]
    var id = root.favoriteId(w)
    if (id !== "") {
      var pinned = root.pinnedIds.indexOf(id) !== -1
      rows.splice(1, 0, pinned ? { text: "Remove from Favorites", action: "unfavorite" } : { text: "Add to Favorites", action: "favorite" })
    }
    return rows
  }

  function menuAction(action) {
    var w = root.menuFor
    if (w) {
      if (action === "favorite") root.run(["omarchy", "dock", "pin", root.favoriteId(w)])
      else if (action === "unfavorite") root.run(["omarchy", "dock", "unpin", root.favoriteId(w)])
      else if (action === "close") root.closeWindow(w.address)
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
        // The glyph shows only if the colored icon is missing.
        text: pinnedColor.status === Image.Ready ? "" : modelData.icon
        hasVisualContent: pinnedColor.status === Image.Ready
        fontFamily: modelData.iconFont || (root.bar ? root.bar.fontFamily : Style.font.family)
        active: root.flyoutOpen && root.flyoutTile === pinnedTile
        useActiveColor: false
        tooltipText: root.flyoutOpen && root.flyoutTile === pinnedTile ? "" : modelData.label + ": " + modelData.hint
        onPressed: function(b) { if (b === Qt.LeftButton) root.buttonPressed(pinnedTile, modelData) }

        Image {
          id: pinnedColor
          anchors.centerIn: parent
          width: root.iconSize + 2
          height: root.iconSize + 2
          sourceSize.width: 48
          sourceSize.height: 48
          smooth: true
          source: pinnedTile.modelData.color ? root.colorIcon(pinnedTile.modelData.color) : ""
          visible: status === Image.Ready
        }
      }
    }

    // A thin line between the buttons and the open windows.
    Item {
      id: separator
      visible: root.windows.length > 0
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
      model: root.shownWindows

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

        Image {
          id: windowColor
          anchors.centerIn: parent
          opacity: windowTile.modelData.minimized ? 0.4 : 1
          width: root.iconSize + 2
          height: root.iconSize + 2
          sourceSize.width: 48
          sourceSize.height: 48
          smooth: true
          source: root.colorIcon("apps/" + root.aliasIcon(root.windowIconName(windowTile.modelData)))
          visible: status === Image.Ready
        }
        IconImage {
          anchors.centerIn: parent
          visible: windowColor.status !== Image.Ready
          opacity: windowTile.modelData.minimized ? 0.4 : 1
          implicitSize: root.iconSize + 2
          source: visible ? root.windowIcon(windowTile.modelData) : ""
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

    WidgetButton {
      id: moreWindows
      visible: root.hiddenWindows.length > 0
      bar: root.bar
      text: "+" + root.hiddenWindows.length
      fixedWidth: root.windowSlot
      active: root.flyoutOpen && root.flyoutTile === moreWindows
      useActiveColor: false
      tooltipText: root.flyoutOpen && root.flyoutTile === moreWindows ? "" : root.hiddenWindows.length + " more open windows: click to see them"
      onPressed: function(b) {
        if (b !== Qt.LeftButton) return
        if (root.flyoutOpen && root.flyoutTile === moreWindows) { root.close(); return }
        root.flyoutItems = root.hiddenWindows.map(function(w) {
          return { iconSource: root.windowIcon(w), label: root.appName(w) + (w.title ? ": " + w.title : ""), window: w }
        })
        root.flyoutTile = moreWindows
        root.flyoutOpen = true
      }
    }
  }

  // A choice in a pop-up row: a hidden window comes forward, anything else opens.
  function pickChoice(choice) {
    root.close()
    if (choice.window) root.windowClicked(choice.window)
    else root.run(choice.command)
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
            source: choice.modelData.color ? root.colorIcon(choice.modelData.color) : (choice.modelData.entryIcon ? root.colorIcon("apps/" + root.aliasIcon(String(choice.modelData.entryIcon))) : "")
            visible: status === Image.Ready
          }

          IconImage {
            visible: !!(choice.modelData.entryIcon || choice.modelData.iconSource) && tileColor.status !== Image.Ready
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Style.space(8)
            implicitSize: Style.space(30)
            source: choice.modelData.iconSource || (choice.modelData.entryIcon ? Quickshell.iconPath(choice.modelData.entryIcon, "application-x-executable") : "")
          }

          Text {
            visible: !(choice.modelData.entryIcon || choice.modelData.iconSource) && tileColor.status !== Image.Ready
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
            onClicked: root.pickChoice(choice.modelData)
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
        model: root.menuRows(root.menuFor)

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
