import QtQuick
import QtQuick.Effects
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
  // Depth (Guy 11-07: "make it pop"). [flag] depth = 0 turns it all off.
  readonly property bool depth: Commons.Color.pick("flag.depth", "1") !== "0"
  readonly property bool stars: Commons.Color.pick("flag.stars", "0") === "1"
  readonly property int fade: 14          // blue dissolves into the stripes over this many px
  readonly property int maxFields: 6      // fixed pool: rescans move fields, never rebuild them
  readonly property int topShade: 6       // soft shadow cast above the bar
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
    // The bar's own thickness (its window spans the whole screen), plus a
    // little room above it for the shelf shadow.
    readonly property int barH: root.bar && root.bar.barSize > 0 ? root.bar.barSize : 30
    implicitHeight: barH + (root.depth ? root.topShade : 0)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "guy-flag"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region {}

    // Shelf shadow above the bar: the bar sits on the desktop, not on top of it.
    Rectangle {
      visible: root.depth
      width: flag.width
      height: root.topShade
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
      }
    }

    Item {
      id: band
      y: flag.height - flag.barH
      width: flag.width
      height: flag.barH

      // Stripes, each with a little material: red darkens toward its foot,
      // white goes faintly cool with a sheen line on top.
      Column {
        anchors.fill: parent
        Repeater {
          model: root.stripes
          delegate: Rectangle {
            id: stripe
            required property int index
            readonly property bool isRed: index % 2 === 0
            readonly property color base: isRed ? root.red : root.white
            width: band.width
            height: index === root.stripes - 1 ? band.height - Math.floor(band.height / root.stripes) * (root.stripes - 1)
                                               : Math.floor(band.height / root.stripes)
            gradient: Gradient {
              GradientStop { position: 0.0; color: stripe.base }
              GradientStop { position: 1.0; color: !root.depth ? stripe.base : (stripe.isRed ? Qt.darker(stripe.base, 1.09) : "#F2F3F6") }
            }
            Rectangle {
              visible: root.depth && !stripe.isRed
              width: parent.width
              height: 1
              color: Qt.rgba(1, 1, 1, 0.25)
            }
          }
        }
      }

      // The blue fields: a fixed pool, moved by the rescan, never rebuilt.
      Repeater {
        model: root.maxFields
        delegate: Item {
          id: field
          required property int index
          readonly property var f: index < root.fields.length ? root.fields[index] : null
          visible: !!f
          x: f ? f.x : 0
          width: f ? f.w : 0
          height: band.height

          // Ends dissolve into the stripes instead of stopping hard.
          Rectangle {
            visible: root.depth
            x: -root.fade + height / 2
            width: root.fade
            height: parent.height
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 1.0; color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.85) }
            }
          }
          Rectangle {
            visible: root.depth
            x: parent.width - height / 2
            width: root.fade
            height: parent.height
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.85) }
              GradientStop { position: 1.0; color: "transparent" }
            }
          }

          // The pill: lighter on top, deeper below, a lit top edge, and a
          // soft shadow so it floats above the stripes.
          Rectangle {
            id: pill
            anchors.fill: parent
            radius: root.depth ? height / 2 : 0
            gradient: Gradient {
              GradientStop { position: 0.0; color: root.depth ? Qt.lighter(root.blue, 1.12) : root.blue }
              GradientStop { position: 1.0; color: root.depth ? Qt.darker(root.blue, 1.15) : root.blue }
            }
            layer.enabled: root.depth
            layer.effect: MultiEffect {
              shadowEnabled: true
              shadowColor: Qt.rgba(0, 0, 0, 0.35)
              shadowBlur: 0.6
              shadowVerticalOffset: 2
              shadowHorizontalOffset: 0
              blurMax: 12
              autoPaddingEnabled: true
            }
            Rectangle {
              visible: root.depth
              x: pill.radius * 0.6
              width: pill.width - pill.radius * 1.2
              height: 1
              color: Qt.rgba(1, 1, 1, 0.18)
            }
          }

          // A few faint stars in the first field (off unless [flag] stars = "1").
          Repeater {
            model: root.stars && field.index === 0 ? [0.14, 0.27, 0.41, 0.55, 0.69, 0.83] : []
            delegate: Rectangle {
              required property var modelData
              required property int index
              x: field.width * modelData
              y: index % 2 === 0 ? field.height * 0.28 : field.height * 0.6
              width: 2
              height: 2
              radius: 1
              color: Qt.rgba(1, 1, 1, 0.12)
            }
          }
        }
      }

      // A lit edge along the very top of the bar.
      Rectangle {
        visible: root.depth
        width: band.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.10)
      }
    }
  }
}
