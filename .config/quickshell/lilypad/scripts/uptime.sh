#!/bin/bash
# Waybar module: System uptime

UPTIME=$(uptime -p 2>/dev/null | sed 's/up //')
SHORT=$(echo "$UPTIME" | sed 's/ hours\?/h/g; s/ minutes\?/m/g; s/ days\?/d/g; s/, / /g')
BOOT=$(uptime -s 2>/dev/null)

echo "{\"text\": \" ${SHORT}\", \"tooltip\": \"Boot: ${BOOT}\"}"
