import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import qs.Ui

// The bar as a flag (Guy, 2026-11-07): blue fields behind each group of
// icons, red and white horizontal stripes in the open space between them.
// This widget takes no room on the bar. It paints on its own layer just
// under the bar, which must be clear (bar background-alpha = 0 in
// ~/.config/omarchy/shell.toml) for the flag to show through. Clicks pass
// straight through to the bar.
BarWidget {
  id: root
  moduleName: "guy.flag"

  implicitWidth: 0
  implicitHeight: 0

  // Colours: [flag] keys in ~/.config/omarchy/shell.toml, else Old Glory.
  readonly property color red: Commons.Color.pick("flag.red", "#B22234")
  readonly property color white: Commons.Color.pick("flag.white", "#FFFFFF")
  readonly property color blue: Commons.Color.pick("flag.blue", "#3C3B6E")
  readonly property int stripes: Math.max(3, Math.min(7, Number(Commons.Color.pick("flag.stripes", "5")) || 5))
  readonly property int fieldPad: 6       // blue reaches this far past the icons
  readonly property int joinGap: 28       // icons closer than this share one field

  readonly property var barWindow: root.QsWindow.window
  property var fields: []

  // Every bar widget (Omarchy's and ours) is a BarWidget with a moduleName,
  // so the groups are found by walking the bar for them; nothing private.
  function collect(item, out) {
    if (!item || item.visible === false || item.opacity === 0) return
    if (item.moduleName !== undefined && item !== root) {
      if (item.width > 1) {
        var p = item.mapToItem(null, 0, 0)
        out.push({ x: p.x, w: item.width })
      }
      return
    }
    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) collect(kids[i], out)
  }

  function refresh() {
    if (!barWindow || !barWindow.contentItem) return
    var items = []
    collect(barWindow.contentItem, items)
    items.sort(function(a, b) { return a.x - b.x })
    var out = []
    for (var i = 0; i < items.length; i++) {
      var a = items[i].x, b = items[i].x + items[i].w
      var last = out.length ? out[out.length - 1] : null
      if (last && a - last.b < joinGap) last.b = Math.max(last.b, b)
      else out.push({ a: a, b: b })
    }
    var next = out.map(function(f) { return { x: Math.round(f.a - fieldPad), w: Math.round(f.b - f.a + fieldPad * 2) } })
    if (JSON.stringify(next) !== JSON.stringify(fields)) fields = next
  }

  // Cheap: a few dozen items. Catches windows opening, the tray drawer, etc.
  Timer {
    interval: 700
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  PanelWindow {
    id: flag
    screen: root.barWindow ? root.barWindow.screen : null
    visible: !!root.barWindow && root.barWindow.visible
    anchors { left: true; right: true; bottom: true }
    // The bar's own thickness (its window spans the whole screen).
    implicitHeight: root.bar && root.bar.barSize > 0 ? root.bar.barSize : 30
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "guy-flag"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region {}

    Column {
      anchors.fill: parent
      Repeater {
        model: root.stripes
        delegate: Rectangle {
          required property int index
          width: flag.width
          // Spread any leftover pixel over the last stripe.
          height: index === root.stripes - 1 ? flag.height - Math.floor(flag.height / root.stripes) * (root.stripes - 1)
                                             : Math.floor(flag.height / root.stripes)
          color: index % 2 === 0 ? root.red : root.white
        }
      }
    }

    Repeater {
      model: root.fields
      delegate: Rectangle {
        required property var modelData
        x: modelData.x
        width: modelData.w
        height: flag.height
        color: root.blue
      }
    }
  }
}
