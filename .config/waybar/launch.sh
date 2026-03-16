#!/bin/bash
# Kill existing waybar and relaunch
pkill waybar 2>/dev/null
sleep 0.2
waybar &
