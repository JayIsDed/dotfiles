#!/bin/bash
# Waybar module: Disk usage (root)

PERCENT=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')

if [ -z "$PERCENT" ]; then
    echo '{"text": " ?", "tooltip": "Disk info unavailable"}'
    exit 0
fi

TOOLTIP=$(df -h --type=btrfs --type=ext4 --type=xfs --type=zfs 2>/dev/null | awk 'NR>1 {printf "%s: %s/%s (%s)\\n", $6, $3, $2, $5}')

if [ "$PERCENT" -ge 90 ]; then
    CLASS="critical"
elif [ "$PERCENT" -ge 75 ]; then
    CLASS="warning"
else
    CLASS="normal"
fi

echo "{\"text\": \" ${PERCENT}%\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"${CLASS}\"}"
