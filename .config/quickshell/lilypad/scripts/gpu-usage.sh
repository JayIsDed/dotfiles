#!/bin/bash
# Waybar module: NVIDIA GPU usage + temp

USAGE=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
MEM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
MEM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')

if [ -z "$USAGE" ]; then
    echo '{"text": " ?", "tooltip": "nvidia-smi not available"}'
    exit 0
fi

TOOLTIP="GPU: ${USAGE}%\nTemp: ${TEMP}C\nVRAM: ${MEM_USED}/${MEM_TOTAL} MiB"

echo "{\"text\": \" ${USAGE}%\", \"tooltip\": \"${TOOLTIP}\"}"
