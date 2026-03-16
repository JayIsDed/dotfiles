#!/bin/bash
# Waybar module: Bluetooth status + connected devices

POWERED=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')

if [ "$POWERED" != "yes" ]; then
    echo '{"text": "󰂲", "tooltip": "Bluetooth off", "class": "off"}'
    exit 0
fi

CONNECTED=$(bluetoothctl devices Connected 2>/dev/null)
COUNT=$(echo "$CONNECTED" | grep -c "Device")

if [ "$COUNT" -eq 0 ]; then
    echo '{"text": "󰂯", "tooltip": "Bluetooth on — no devices", "class": "on"}'
else
    NAMES=$(echo "$CONNECTED" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//' | paste -sd '\\n')
    echo "{\"text\": \"󰂱 ${COUNT}\", \"tooltip\": \"Connected:\\n${NAMES}\", \"class\": \"connected\"}"
fi
