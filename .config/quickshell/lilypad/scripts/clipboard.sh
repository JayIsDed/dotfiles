#!/bin/bash
# Waybar module: Clipboard history (cliphist)

COUNT=$(cliphist list 2>/dev/null | wc -l)

if [ "$COUNT" -eq 0 ]; then
    echo '{"text": "", "tooltip": "Clipboard empty", "class": "empty"}'
else
    LAST=$(cliphist list 2>/dev/null | head -1 | cut -f2 | head -c 50)
    echo "{\"text\": \"\", \"tooltip\": \"${COUNT} items\\nLast: ${LAST}\", \"class\": \"has-items\"}"
fi
