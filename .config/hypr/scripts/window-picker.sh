#!/bin/bash
# Fuzzy window picker — focus any open window by title
# Uses hyprctl to list windows, rofi to pick, hyprctl to focus

SELECTION=$(hyprctl clients -j | jq -r '.[] | "\(.address) | \(.workspace.name // .workspace.id) | \(.class) — \(.title)"' | \
    rofi -dmenu -i -p "Window" \
        -theme-str 'window { width: 700px; }' \
        -theme-str 'listview { lines: 15; }')

if [ -n "$SELECTION" ]; then
    ADDR=$(echo "$SELECTION" | cut -d'|' -f1 | tr -d ' ')
    hyprctl dispatch focuswindow "address:$ADDR"
fi
