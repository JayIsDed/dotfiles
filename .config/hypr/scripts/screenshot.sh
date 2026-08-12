#!/usr/bin/env bash
# screenshot.sh — rofi menu over grim+slurp. Area bind (SUPER+SHIFT+S) skips
# the menu and calls grim directly from binds.lua.
set -euo pipefail

dir="$HOME/Pictures"
file="$dir/screenshot_$(date +%Y%m%d_%H%M%S).png"
mkdir -p "$dir"

choice=$(printf "area\nactive window\nfull (all monitors)\ncurrent monitor" \
  | rofi -dmenu -i -p "shot" -no-custom) || exit 0

case "$choice" in
  "area")
    grim -g "$(slurp)" "$file" ;;
  "active window")
    geo=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    grim -g "$geo" "$file" ;;
  "full (all monitors)")
    grim "$file" ;;
  "current monitor")
    mon=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
    grim -o "$mon" "$file" ;;
  *) exit 0 ;;
esac

wl-copy < "$file"
notify-send -a "Screenshot" -i "$file" "Saved + copied" "$(basename "$file")"
