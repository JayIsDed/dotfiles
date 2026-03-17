#!/bin/bash
# Waybar module: Docker container health from LXC 112

RESULT=$(ssh -o ConnectTimeout=3 docker-services "docker ps --format '{{.Names}}\t{{.Status}}'" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo '{"text": " ?", "tooltip": "Cannot reach docker-services", "class": "disconnected"}'
    exit 0
fi

RUNNING=$(echo "$RESULT" | grep -c "Up")
TOTAL=$(echo "$RESULT" | wc -l)
TOOLTIP=$(echo "$RESULT" | awk -F'\t' '{printf "%s: %s\\n", $1, $2}')

if [ "$RUNNING" -eq "$TOTAL" ]; then
    CLASS="healthy"
else
    CLASS="degraded"
fi

echo "{\"text\": \" ${RUNNING}/${TOTAL}\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"${CLASS}\"}"
