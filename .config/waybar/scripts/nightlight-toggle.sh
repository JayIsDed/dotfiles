#!/bin/bash
# Toggle hyprsunset night light

if pgrep -x hyprsunset > /dev/null; then
    pkill hyprsunset
else
    hyprsunset -t 4000 &
    disown
fi
