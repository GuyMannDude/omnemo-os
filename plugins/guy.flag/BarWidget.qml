import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.Commons as Commons
import qs.Ui

// The bar as a flag (Guy, 2026-11-07), now alive (Guy, 2026-11-09: "make it
// pop"): the red and white stripes ripple like cloth in a light breeze, the
// blue fields behind each group of icons are glass with a white star in their
// end caps, and now and then a glint of light crosses the whole bar.
//
// This widget takes no room on the bar. It paints on its own layer just under
// the bar, which must be clear (bar background-alpha = 0 in
// ~/.config/omarchy/shell.toml) for the flag to show through. Clicks pass
// straight through to the bar.
//
// Motion: [flag] motion = "auto" (default) | "full" | "calm" | "off" in
// shell.toml. auto = full on mains power, calm on battery. It stops while a
// fullscreen window covers the bar.
BarWidget {
  id: root
  moduleName: "guy.flag"

  implicitWidth: 0
  implicitHeight: 0

  // Colours: [flag] keys in ~/.config/omarchy/shell.toml.
  readonly property color red: Commons.Color.pick("flag.red", "#C21F35")
  readonly property color white: Commons.Color.pick("flag.white", "#FFFFFF")
  readonly property color blue: Commons.Color.pick("flag.blue", "#3C3B6E")
  readonly property int stripes: Math.max(3, Math.min(7, Number(Commons.Color.pick("flag.stripes", "5")) || 5))
  readonly property int fieldPad: 6       // blue reaches this far past the icons
  readonly property int capPad: 21        // ...or this far where there is room for a star
  // Depth (Guy 11-07: "make it pop"). [flag] depth = 0 gives the flat flag, no motion.
  readonly property bool depth: Commons.Color.pick("flag.depth", "1") !== "0"
  readonly property bool stars: Commons.Color.pick("flag.stars", "1") !== "0"
  readonly property int fade: 14          // blue dissolves into the stripes over this many px
  readonly property int maxFields: 6      // fixed pool: rescans move fields, never rebuild them
  readonly property int topShade: 6       // soft shadow cast above the bar
  readonly property int joinGap: 50       // icons closer than this share one field

  // --- motion ---------------------------------------------------------------
  readonly property string motionPref: String(Commons.Color.pick("flag.motion", "auto"))
  readonly property bool covered: !!(Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.hasFullscreen)
  readonly property string motion: {
    if (!depth || motionPref === "off") return "off"
    if (motionPref === "calm" || motionPref === "full") return motionPref
    return UPower.onBattery ? "calm" : "full"
  }
  readonly property bool moving: motion !== "off" && !covered && flag.visible
  // One slow clock for the cloth: 0..2*pi over 24 seconds, then round again.
  // A timer, not an animation, so the frame rate is ours to choose: about 30
  // pictures a second at full, 10 when calm.
  property real phase: 0
  property real waveAmt: motion === "full" ? 1.0 : (motion === "calm" ? 0.6 : 0.0)
  Behavior on waveAmt { NumberAnimation { duration: 900 } }
  Timer {
    interval: root.motion === "full" ? 33 : 100
    running: root.moving
    repeat: true
    onTriggered: root.phase = (root.phase + interval / 1000 * (2 * Math.PI / 24)) % (2 * Math.PI)
  }

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
    // A field grows a star cap on each end that has room for one (not at the
    // screen edges).
    var full = barWindow.width
    var next = out.map(function(f) {
      var sl = root.stars && root.depth && f.a - capPad >= 4
      var sr = root.stars && root.depth && f.b + capPad <= full - 4
      var x0 = f.a - (sl ? capPad : fieldPad), x1 = f.b + (sr ? capPad : fieldPad)
      return { x: Math.round(x0), w: Math.round(x1 - x0), sl: sl, sr: sr }
    })
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

  // A five-point star that twinkles now and then.
  component Star: Item {
    id: st
    property real r: 6.5
    property int wait: 5000
    width: r * 2
    height: r * 2
    opacity: 0.80
    readonly property var pts: {
      var out = [], inner = r * 0.42
      for (var i = 0; i <= 10; i++) {
        var a = -Math.PI / 2 + i * Math.PI / 5
        var rad = i % 2 === 0 ? r : inner
        out.push(Qt.point(r + rad * Math.cos(a), r + rad * Math.sin(a)))
      }
      return out
    }
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: "white"
        strokeColor: "transparent"
        PathPolyline { path: st.pts }
      }
    }
    SequentialAnimation {
      running: root.moving
      loops: Animation.Infinite
      PauseAnimation { duration: st.wait }
      ParallelAnimation {
        NumberAnimation { target: st; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutQuad }
        NumberAnimation { target: st; property: "scale"; to: 1.28; duration: 380; easing.type: Easing.OutQuad }
      }
      ParallelAnimation {
        NumberAnimation { target: st; property: "opacity"; to: 0.80; duration: 800; easing.type: Easing.InOutQuad }
        NumberAnimation { target: st; property: "scale"; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
      }
      PauseAnimation { duration: 7000 }
    }
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

      // The cloth: stripes that ripple, drawn by a small graphics program
      // (flag.frag, compiled to flag.frag.qsb next to this file).
      ShaderEffect {
        anchors.fill: parent
        visible: root.depth
        blending: false
        property real phase: root.phase
        property real pxw: width
        property real pxh: height
        property real stripes: root.stripes
        property real wave: root.waveAmt
        property color red: root.red
        property color white: root.white
        fragmentShader: Qt.resolvedUrl("flag.frag.qsb")
      }

      // The flat flag ([flag] depth = 0): plain stripes, no motion.
      Column {
        anchors.fill: parent
        visible: !root.depth
        Repeater {
          model: root.depth ? 0 : root.stripes
          delegate: Rectangle {
            required property int index
            width: band.width
            height: index === root.stripes - 1 ? band.height - Math.floor(band.height / root.stripes) * (root.stripes - 1)
                                               : Math.floor(band.height / root.stripes)
            color: index % 2 === 0 ? root.red : root.white
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

          // The pill: glass. Bright on top, deep below, a soft shadow so it
          // floats above the stripes.
          Rectangle {
            id: pill
            anchors.fill: parent
            radius: root.depth ? height / 2 : 0
            gradient: Gradient {
              GradientStop { position: 0.0; color: root.depth ? Qt.lighter(root.blue, 1.32) : root.blue }
              GradientStop { position: 0.55; color: root.blue }
              GradientStop { position: 1.0; color: root.depth ? Qt.darker(root.blue, 1.5) : root.blue }
            }
            layer.enabled: root.depth
            layer.effect: MultiEffect {
              shadowEnabled: true
              shadowColor: Qt.rgba(0, 0, 0, 0.42)
              shadowBlur: 0.7
              shadowVerticalOffset: 2
              shadowHorizontalOffset: 0
              blurMax: 14
              autoPaddingEnabled: true
            }
          }
          // The shine on the upper half of the glass.
          Rectangle {
            visible: root.depth
            x: 2
            y: 1
            width: parent.width - 4
            height: parent.height * 0.48
            radius: height
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.26) }
              GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
          }
          // A thin lit rim.
          Rectangle {
            visible: root.depth
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.20)
          }

          // A star in each end cap that has room.
          Star {
            visible: !!field.f && field.f.sl === true
            x: 6
            y: (field.height - height) / 2
            wait: 2500 + field.index * 2700
          }
          Star {
            visible: !!field.f && field.f.sr === true
            x: field.width - width - 6
            y: (field.height - height) / 2
            wait: 6500 + field.index * 3100
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

      // The glint: a slanted streak of light that crosses the bar now and
      // then (full motion only).
      Item {
        id: glint
        anchors.fill: parent
        clip: true
        property real gx: -400
        property int pause: 4000
        Rectangle {
          x: glint.gx
          y: -24
          width: 110
          height: band.height + 48
          rotation: 24
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 0.36; color: Qt.rgba(1, 1, 1, 0.13) }
            GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, 0.42) }
            GradientStop { position: 0.64; color: Qt.rgba(1, 1, 1, 0.13) }
            GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.0) }
          }
        }
        SequentialAnimation {
          running: root.moving && root.motion === "full"
          loops: Animation.Infinite
          PauseAnimation { duration: glint.pause }
          NumberAnimation { target: glint; property: "gx"; from: -200; to: band.width + 200; duration: 2600; easing.type: Easing.InOutSine }
          ScriptAction { script: { glint.gx = -400; glint.pause = 40000 } }
        }
      }
    }
  }
}
