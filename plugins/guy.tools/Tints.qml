import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// Omnemo OS menu look (same file in guy.tools, guy.utils, guy.favorites and
// guy.taskbar: plugins cannot import each other's files, so it is copied).
// Tile colors come from the ACTIVE theme's colors.toml (red, green, blue...),
// so they follow theme changes. A theme without a named color falls back to
// the theme accent turned to that color's hue.
QtObject {
  id: tints

  // The look, in one place. Every menu reads these.
  readonly property int tileW: Commons.Style.space(70)
  readonly property int tileH: Commons.Style.space(72)
  readonly property int tileRadius: 8
  readonly property int gap: Commons.Style.space(3)
  readonly property int maxAcross: 6
  readonly property int pill: Commons.Style.space(34)
  readonly property int pillRadius: 10
  readonly property int pillTop: Commons.Style.space(5)
  readonly property int icon: Commons.Style.space(22)
  readonly property real pillAlpha: 0.16
  readonly property real pillHoverAlpha: 0.32
  readonly property real hairlineAlpha: 0.12

  // Up to six across, rows filled evenly (11 tiles = 6 + 5, never 5 + 5 + 1).
  function across(count) {
    var n = Math.max(1, count)
    var rows = Math.ceil(n / maxAcross)
    return Math.ceil(n / rows)
  }
  function cardWidth(count, padding) {
    return across(count) * (tileW + gap) + padding * 2 + 4
  }

  property var named: ({})
  readonly property var hues: ({ red: 0.97, orange: 0.05, yellow: 0.11, green: 0.27, cyan: 0.5, blue: 0.62, magenta: 0.76 })
  readonly property var order: ["blue", "cyan", "green", "yellow", "orange", "red", "magenta"]

  function get(name) {
    if (named[name]) return named[name]
    var a = Commons.Color.accent
    var h = hues[name]
    if (h === undefined) return a
    return Qt.hsla(h, Math.max(0.45, a.hslSaturation), Math.min(0.7, Math.max(0.5, a.hslLightness)), 1)
  }
  // A steady color for things without one (apps, windows): same name, same color.
  function forName(text) {
    var s = String(text || ""), n = 0
    for (var i = 0; i < s.length; i++) n = (n * 31 + s.charCodeAt(i)) % 9973
    return get(order[n % order.length])
  }
  function fill(c, hovered) { return Commons.Util.alpha(c, hovered ? pillHoverAlpha : pillAlpha) }
  function hairline() { return Commons.Util.alpha(Commons.Color.foreground, hairlineAlpha) }

  function parse(raw) {
    var out = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([a-z_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (m && hues[m[1]] !== undefined) out[m[1]] = m[2]
    }
    named = out
  }

  property FileView file: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: tints.parse(text())
    onLoadFailed: tints.parse("")
  }
  // A theme switch changes the accent; re-read the palette then too.
  readonly property color accentNow: Commons.Color.accent
  onAccentNowChanged: file.reload()
}
