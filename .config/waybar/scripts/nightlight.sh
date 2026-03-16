#!/bin/bash
# Waybar module: Night light toggle (hyprsunset)

if pgrep -x hyprsunset > /dev/null; then
    echo '{"text": "󰛨", "tooltip": "Night light on (click to disable)", "class": "on"}'
else
    echo '{"text": "󰛩", "tooltip": "Night light off (click to enable)", "class": "off"}'
fi
