#!/bin/bash
# Fuzzy project picker — opens kitty in selected project directory
# Scans ~/git/ for project dirs

PROJECT=$(find ~/git -maxdepth 1 -mindepth 1 -type d | sort | \
    sed "s|$HOME/git/||" | \
    rofi -dmenu -i -p "Project" \
        -theme-str 'window { width: 500px; }' \
        -theme-str 'listview { lines: 15; }')

if [ -n "$PROJECT" ]; then
    kitty --directory "$HOME/git/$PROJECT" &
fi
