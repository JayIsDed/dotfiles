#!/bin/bash
# Waybar module: CPU temperature (AMD Ryzen via k10temp)

TEMP=$(sensors -j 2>/dev/null | jq -r '."k10temp-pci-00c3"."Tctl"."temp1_input" // empty' 2>/dev/null)

if [ -z "$TEMP" ]; then
    # Fallback: try any CPU temp
    TEMP=$(sensors 2>/dev/null | grep -i "tctl\|temp1" | head -1 | grep -oP '\+\K[0-9.]+')
fi

if [ -z "$TEMP" ]; then
    echo '{"text": "", "tooltip": "No temp sensor", "class": "unknown"}'
    exit 0
fi

TEMP_INT=${TEMP%.*}

if [ "$TEMP_INT" -ge 85 ]; then
    CLASS="critical"
elif [ "$TEMP_INT" -ge 70 ]; then
    CLASS="warm"
else
    CLASS="normal"
fi

echo "{\"text\": \" ${TEMP_INT}°C\", \"tooltip\": \"CPU: ${TEMP}°C\", \"class\": \"${CLASS}\"}"
