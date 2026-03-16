#!/bin/bash
# Screen recording toggle — wf-recorder
# Records to ~/Videos/ with timestamp filename

PIDFILE="/tmp/hypr-recording-pid"

if [ -f "$PIDFILE" ]; then
    # Stop recording
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm "$PIDFILE"
    notify-send "Recording" "Saved to ~/Videos/"
else
    # Pick area or full screen
    mkdir -p ~/Videos
    OUTFILE="$HOME/Videos/recording-$(date '+%Y%m%d-%H%M%S').mp4"

    AREA=$(slurp 2>/dev/null)
    if [ -n "$AREA" ]; then
        wf-recorder -g "$AREA" -f "$OUTFILE" &
    else
        wf-recorder -f "$OUTFILE" &
    fi

    echo $! > "$PIDFILE"
    notify-send "Recording" "Started — SUPER+SHIFT+R to stop"
fi
