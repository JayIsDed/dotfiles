#!/bin/bash
# Waybar module: Microphone mute status

MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -c MUTED)
VOL=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk '{printf "%.0f", $2 * 100}')

if [ "$MUTED" -eq 1 ]; then
    echo "{\"text\": \"󰍭\", \"tooltip\": \"Mic muted\", \"class\": \"muted\"}"
else
    echo "{\"text\": \"󰍬 ${VOL}%\", \"tooltip\": \"Mic volume: ${VOL}%\", \"class\": \"live\"}"
fi
