#!/bin/bash
# Waybar module: Notification count via swaync

COUNT=$(swaync-client -c 2>/dev/null)
DND=$(swaync-client -D 2>/dev/null)

if [ "$DND" = "true" ]; then
    echo "{\"text\": \"󰂛\", \"tooltip\": \"Do Not Disturb\", \"class\": \"dnd\"}"
elif [ "$COUNT" -gt 0 ]; then
    echo "{\"text\": \"󰂚 ${COUNT}\", \"tooltip\": \"${COUNT} notification(s)\", \"class\": \"unread\"}"
else
    echo '{"text": "󰂜", "tooltip": "No notifications", "class": "clear"}'
fi
