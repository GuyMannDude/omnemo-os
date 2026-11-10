import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A "?" button for the bar. Click it and a card opens that says, icon by
// icon, what the bar does, in the order the icons sit on the bar: the left
// side in one column, the right side in the other, so it fits on a small
// screen. Omarchy's own icons on the right have no hover labels, so this is
// where they get explained. Click the button again, or anywhere else, to
// close it.
BarWidget {
  id: root
  moduleName: "guy.help"

  // Glyphs are written as code points: pasted Nerd Font glyphs get lost.
  function glyph(code) { return String.fromCodePoint(code) }

  readonly property var leftRows: [
    { header: "Left side: your taskbar" },
    { icon: glyph(0xf06a9), name: "AI meter (robot)", what: "Next to the brain: how much of each AI plan you've used, like a fuel gauge" },
    { icon: glyph(0xf003b), color: "apps/gbrainy", name: "Pinned buttons",  what: "AI (brain), Browsers and Web apps pop up a row of choices: click one to open it. Files and Apps open straight away; Settings opens the full Omarchy menu" },
    { icon: glyph(0xf05af), name: "Open windows",    what: "Click to bring up, click again to minimize. Right-click to minimize, add to Favorites or close" },
    { header: "Built in" },
    { icon: glyph(0xf09d1), color: "apps/braindump", name: "Memory", what: root.memoryWhat },
    { header: "Windows won't move or resize?" },
    { icon: glyph(0xf05b2), color: "apps/cs-windows", name: "Press Super + L", what: "Super is the Windows key. Windows have three ways to sit on the screen: free (drag and resize them with the mouse), side by side (they fill the screen and stay put), and a sliding row. Super + L switches to the next one and a note says which. Keep pressing until it says floating and your windows move freely again." }
  ]

  // Memory row: live numbers from `omnemo stats --json`, read each time the
  // guide opens. No numbers (Omnemo missing, slow or broken) = the words only.
  readonly property string memoryAbout: "Your AI helpers share one memory on this computer. Just talk to them and they remember; say \"forget that\" to remove something."
  property string memoryStats: ""
  readonly property string memoryWhat: memoryStats ? memoryStats + " " + memoryAbout : memoryAbout

  function lastUsed(epoch) {
    if (!epoch) return ""
    var then = new Date(epoch * 1000), now = new Date()
    var day = function(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime() }
    var diff = Math.round((day(now) - day(then)) / 86400000)
    if (diff === 0) return "last used today at " + Qt.formatTime(then, "h:mm AP")   // local clock, 12-hour
    if (diff === 1) return "last used yesterday"
    return "last used on " + Qt.formatDate(then, "MMM d")
  }

  function memoryLine(text) {
    try {
      var s = JSON.parse(String(text || ""))
      var n = Number(s.memory_count || 0) - Number(s.superseded || 0)
      var m = Number(s.learned_today || 0)
      if (!isFinite(n) || !isFinite(m)) return ""
      if (n <= 0) return "Memory: nothing saved yet."
      var parts = [n + " saved", m > 0 ? m + " new today" : "none new today"]
      var used = root.lastUsed(Number(s.last_recall_at || 0))
      if (used) parts.push(used)
      return "Memory: " + parts.join(", ") + "."
    } catch (e) { return "" }
  }

  Process {
    id: memoryStatsRead
    command: ["timeout", "3", Quickshell.env("HOME") + "/.local/bin/omnemo", "stats", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.memoryStats = root.memoryLine(text)
    }
    onExited: function(code) { if (code !== 0) root.memoryStats = "" }
  }
  onPopupOpenChanged: if (popupOpen && !memoryStatsRead.running) memoryStatsRead.running = true
  Component.onCompleted: memoryStatsRead.running = true   // so the first open already has numbers

  readonly property var rightRows: [
    { header: "Middle: two menus around the ?" },
    { icon: "Tools", color: "apps/applications-utilities", name: "Tools (left of ?)", what: "Calculator, Screenshot (saved in your Pictures folder), Record screen, Color picker, Emoji, Clipboard, Shortcuts, Terminal, Theme, Lock, Restart or shut down" },
    { icon: "Fav", color: "status/starred", name: "Favorites (right of ?)", what: "Your favorite apps in one click. Add one: right-click its window on the taskbar. Remove one: right-click it here" },
    { header: "Right side" },
    { icon: "\uf021",        name: "Update",          what: "Shows only when an Omarchy update is ready: click it to install" },
    { icon: glyph(0xf0141), name: "Hidden icons (‹)", what: "Click to show the icons kept out of the way, and apps running in the background" },
    { icon: glyph(0xf05b7), color: "apps/preferences-system", name: "Settings (wrench)", what: "Wi-Fi, Bluetooth, Display, Sound, Weather, World clocks and Calendar, by name" },
    { icon: glyph(0xf057e), name: "Sound",           what: "Click for volume, speakers and microphone; scroll on it to change the volume" },
    { icon: glyph(0xf0954), color: "apps/org.gnome.clocks", name: "Clock", what: "Hover for the day, date and time. Click for the calendar" },
    { icon: glyph(0xf0425), name: "Power",           what: "Battery, power mode, lock, restart, shut down" }
  ]

  readonly property string footer: "Click the same icon again, or anywhere else, to close a panel"
  readonly property int columnWidth: Style.space(330)

  property bool popupOpen: false
  function close() { popupOpen = false }
  // `omarchy-shell shell summon guy.help {}` opens this menu (for shortcuts and help).
  function open() { popupOpen = true }
  readonly property bool opened: popupOpen

  // Hover labels for Omarchy's own icons, which come without any. This is a
  // deliberate reach past the plugin API: the labels are set on the live
  // buttons (Omarchy's files are left alone), only where a button has no label
  // of its own, and set again now and then since a restarted bar rebuilds its
  // buttons. If Omarchy changes its widgets, this quietly does nothing.
  readonly property var hoverLabels: ({
    "omarchy.weather":   "Weather: click for today and the next days",
    "omarchy.agents":    "AI meter: how much of each AI plan you've used",
    "omarchy.monitor":   "Display: brightness and screens",
    "omarchy.audio":     "Sound: volume, speakers and microphone",
    "omarchy.network":   "Network: Wi-Fi and internet",
    "omarchy.bluetooth": "Bluetooth: connect headphones, mice and more",
    "omarchy.power":     "Battery and power: lock, restart, shut down"
  })

  function labelButtons(item, text) {
    if (!item) return
    if (item.tooltipHovered !== undefined && item.tooltipText !== undefined && item.tooltipText === "") item.tooltipText = text
    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) root.labelButtons(kids[i], text)
  }

  // The plugin API only reaches this widget's own copies, so walk the bar's
  // item tree: up to its top, then down to each widget named in the list.
  function findWidgets(item, found) {
    if (!item) return
    var text = item.moduleName !== undefined ? root.hoverLabels[item.moduleName] : undefined
    if (text) { root.labelButtons(item, text); found.n++; return }
    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) root.findWidgets(kids[i], found)
  }

  function applyHoverLabels() {
    try {
      var top = root
      while (top.parent) top = top.parent
      root.findWidgets(top, { n: 0 })
    } catch (e) {}
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.applyHoverLabels()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: colorIcon.status === Image.Ready ? "" : root.glyph(0xf02d7)
    hasVisualContent: colorIcon.status === Image.Ready
    active: root.popupOpen
    tooltipText: root.popupOpen ? "" : "How to use this taskbar: click for a guide to every icon"
    onPressed: function(b) { root.popupOpen = !root.popupOpen }

    // Colored icon (Papirus); the glyph above shows only if it is missing.
    Image {
      id: colorIcon
      anchors.centerIn: parent
      width: 22
      height: 22
      sourceSize.width: 48
      sourceSize.height: 48
      smooth: true
      source: "file://" + Quickshell.env("HOME") + "/.local/share/omnemo-os/icons/48x48/apps/help-browser.svg"
      visible: status === Image.Ready
    }
  }

  // One line of the guide: a header, or an icon with its name and what it does.
  component GuideRow: Item {
    id: entry
    required property var modelData
    required property int index
    readonly property bool isHeader: modelData.header !== undefined

    width: root.columnWidth
    height: isHeader ? headerText.implicitHeight + (index > 0 ? Style.space(8) : 0) : Math.max(iconText.implicitHeight, body.implicitHeight)

    Text {
      id: headerText
      visible: entry.isHeader
      anchors.bottom: parent.bottom
      width: parent.width
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
      text: entry.isHeader ? entry.modelData.header : ""
      color: Commons.Color.accent
      font.family: Style.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Image {
      id: rowColor
      visible: !entry.isHeader && status === Image.Ready
      x: (Style.space(40) - width) / 2
      width: Style.font.body + 6
      height: Style.font.body + 6
      sourceSize.width: 48
      sourceSize.height: 48
      smooth: true
      source: !entry.isHeader && entry.modelData.color ? "file://" + Quickshell.env("HOME") + "/.local/share/omnemo-os/icons/48x48/" + entry.modelData.color + ".svg" : ""
    }

    Text {
      id: iconText
      visible: !entry.isHeader
      opacity: rowColor.visible ? 0 : 1
      width: Style.space(40)
      horizontalAlignment: Text.AlignHCenter
      textFormat: Text.PlainText
      text: entry.isHeader ? "" : entry.modelData.icon
      color: Commons.Color.foreground
      font.family: entry.modelData.iconFont || (root.bar ? root.bar.fontFamily : Style.fontFamily)
      font.pixelSize: Style.font.body + 2
    }

    Column {
      id: body
      visible: !entry.isHeader
      anchors.left: iconText.right
      anchors.leftMargin: Style.space(8)
      anchors.right: parent.right

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: entry.isHeader ? "" : entry.modelData.name
        color: Commons.Color.foreground
        font.family: Style.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: entry.isHeader ? "" : entry.modelData.what
        color: Util.alpha(Commons.Color.foreground, 0.75)
        font.family: Style.fontFamily
        font.pixelSize: Style.font.body
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(guide.implicitWidth + popup.padding * 2 + 4)
    contentHeight: popup.fittedContentHeight(guide.implicitHeight)

    // Scrolls only if the screen is too short to show it all.
    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: guide.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: guide
        spacing: Style.space(10)

        Row {
          spacing: Style.space(24)

          Column {
            spacing: Style.space(6)
            Repeater { model: root.leftRows; delegate: GuideRow {} }
          }

          Column {
            spacing: Style.space(6)
            Repeater { model: root.rightRows; delegate: GuideRow {} }
          }
        }

        Text {
          width: root.columnWidth * 2 + Style.space(24)
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: root.footer
          color: Commons.Color.accent
          font.family: Style.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
      }
    }
  }
}
