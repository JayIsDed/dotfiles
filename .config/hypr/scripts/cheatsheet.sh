#!/usr/bin/env bash
# cheatsheet.sh — keybind reference from live state. Binds carrying a
# description in binds.lua appear here automatically; no parallel doc to rot.
hyprctl -j binds | jq -r '
  .[] | select(.description != "") |
  [.modmask_readable // "", .key] as $k |
  "\(.description)\t\($k | join(" + "))"' 2>/dev/null \
  | column -t -s $'\t' \
  | rofi -dmenu -i -p "keys" -no-custom
