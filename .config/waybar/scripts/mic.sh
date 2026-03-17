#!/bin/bash
# Waybar module: Microphone mute status

MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -c MUTED)

if [ "$MUTED" -eq 1 ]; then
    echo '{"text": "", "tooltip": "Mic muted", "class": "muted"}'
else
    echo '{"text": "", "tooltip": "Mic live", "class": "live"}'
fi
