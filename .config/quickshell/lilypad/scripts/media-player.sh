#!/bin/bash
# Waybar module: Media player (playerctl)
# Shows currently playing track — hides when nothing is playing

STATUS=$(playerctl status 2>/dev/null)

if [ "$STATUS" != "Playing" ] && [ "$STATUS" != "Paused" ]; then
    echo '{"text": "", "tooltip": "", "class": "stopped"}'
    exit 0
fi

ARTIST=$(playerctl metadata artist 2>/dev/null | head -c 25)
TITLE=$(playerctl metadata title 2>/dev/null | head -c 30)
PLAYER=$(playerctl metadata --format '{{playerName}}' 2>/dev/null)

if [ "$STATUS" = "Playing" ]; then
    ICON="󰐊"
    CLASS="playing"
else
    ICON="󰏤"
    CLASS="paused"
fi

if [ -n "$ARTIST" ]; then
    TEXT="${ICON} ${ARTIST} — ${TITLE}"
    TOOLTIP="${PLAYER}: ${ARTIST} — ${TITLE}"
else
    TEXT="${ICON} ${TITLE}"
    TOOLTIP="${PLAYER}: ${TITLE}"
fi

echo "{\"text\": \"${TEXT}\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"${CLASS}\"}"
