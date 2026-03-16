#!/bin/bash
# Launch waybar as 3 dynamic islands

pkill waybar 2>/dev/null
sleep 0.3

CONFIG_DIR="$HOME/.config/waybar"

waybar -c "$CONFIG_DIR/config-left.jsonc"   -s "$CONFIG_DIR/style.css" &
waybar -c "$CONFIG_DIR/config-center.jsonc" -s "$CONFIG_DIR/style.css" &
waybar -c "$CONFIG_DIR/config-right.jsonc"  -s "$CONFIG_DIR/style.css" &
