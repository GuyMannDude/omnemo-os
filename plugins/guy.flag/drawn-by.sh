#!/bin/sh
# Prints one word: "software" when this desktop is drawn by the processor
# alone (no working graphics card, as in most virtual machines), else "gpu".
# The flag bar reads it once at start. A moving flag makes the whole desktop
# repaint many times a second; without a graphics card that keeps a processor
# core busy, so the flag then holds still unless motion is set by hand.
#
# What it checks, in this order:
#  1. LIBGL_ALWAYS_SOFTWARE set: the person asked for software drawing.
#  2. The line Hyprland writes in its own log at start, naming what it draws
#     with ("Renderer: ..."). llvmpipe, softpipe and swrast are Mesa's
#     software drawers.
#  3. No log to read: a computer with no render device in /dev/dri has no
#     graphics card that programs can use.
# It only reads; it changes nothing.

case "${LIBGL_ALWAYS_SOFTWARE:-}" in
  1|true) echo software; exit 0 ;;
esac

run="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
log="$run/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/hyprland.log"
if [ ! -r "$log" ]; then
  log="$(ls -t "$run"/hypr/*/hyprland.log 2>/dev/null | head -n 1)"
fi

line=""
if [ -n "$log" ] && [ -r "$log" ]; then
  line="$(grep -a -m 1 ' Renderer: ' "$log" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
fi

if [ -n "$line" ]; then
  case "$line" in
    *llvmpipe*|*softpipe*|*swrast*|*"software rasterizer"*) echo software ;;
    *) echo gpu ;;
  esac
  exit 0
fi

for node in "${OMNEMO_DRI_DIR:-/dev/dri}"/renderD*; do
  if [ -e "$node" ]; then echo gpu; exit 0; fi
done
echo software
