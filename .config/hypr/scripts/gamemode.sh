#!/bin/bash
# Game mode toggle — strip desktop effects + enable performance optimizations
# SUPER+ALT+G to toggle

STATUS_FILE="/tmp/hypr-gamemode"

if [ -f "$STATUS_FILE" ]; then
    # Game mode OFF — restore normal desktop
    hyprctl reload
    rm "$STATUS_FILE"
    notify-send "Game Mode OFF" "Desktop effects restored"
else
    # Game mode ON — strip everything for max FPS
    hyprctl --batch "\
        keyword animations:enabled false;\
        keyword decoration:blur:enabled false;\
        keyword decoration:shadow:enabled false;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0;\
        keyword decoration:active_opacity 1.0;\
        keyword decoration:inactive_opacity 1.0"
    touch "$STATUS_FILE"
    notify-send "Game Mode ON" "Effects disabled — launch games with gamemoderun"
fi
