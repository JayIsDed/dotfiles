#!/bin/bash
# Waybar module: Arch package updates

UPDATES=$(checkupdates 2>/dev/null | wc -l)

if [ "$UPDATES" -eq 0 ]; then
    echo '{"text": "", "tooltip": "System up to date", "class": "updated"}'
else
    TOOLTIP=$(checkupdates 2>/dev/null | head -20 | awk '{printf "%s %s -> %s\\n", $1, $2, $4}')
    echo "{\"text\": \" ${UPDATES}\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"pending\"}"
fi
