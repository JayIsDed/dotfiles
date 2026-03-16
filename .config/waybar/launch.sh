#!/bin/bash
# Launch waybar (single instance, islands via CSS)
pkill waybar 2>/dev/null
sleep 0.2
waybar &
