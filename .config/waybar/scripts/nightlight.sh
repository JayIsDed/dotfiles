#!/bin/bash
# Waybar module: Night light toggle (hyprsunset)

if pgrep -x hyprsunset > /dev/null; then
    echo '{"text": "", "tooltip": "Night light on", "class": "on"}'
else
    echo '{"text": "", "tooltip": "Night light off", "class": "off"}'
fi
