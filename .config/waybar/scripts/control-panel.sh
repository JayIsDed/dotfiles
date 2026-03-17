#!/bin/bash
# Control Panel — rofi-based settings/toggles/launchers
# Opened from waybar panel button, re-invokes on toggle to show updated state

# ── Read colors from rofi colors.rasi ──
COLORS_FILE="$HOME/.config/rofi/colors.rasi"
get_color() {
    grep -oP "$1:\s*\K[^;]+" "$COLORS_FILE" 2>/dev/null | tr -d ' '
}

COL_ON=$(get_color "primary")
COL_OFF=$(get_color "outline")
COL_ERR=$(get_color "error")

[ -z "$COL_ON" ] && COL_ON="#96d5a6"
[ -z "$COL_OFF" ] && COL_OFF="#8b938a"
[ -z "$COL_ERR" ] && COL_ERR="#ffb4ab"

# ── Gather toggle states ──
wifi_on() { nmcli radio wifi 2>/dev/null | grep -q "enabled"; }
bt_on() { bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; }
nightlight_on() { pgrep -x wlsunset >/dev/null 2>&1; }
mic_muted() { wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q "MUTED"; }
dnd_on() { [ "$(swaync-client -D 2>/dev/null)" = "true" ]; }

indicator() {
    if $1; then
        echo "<span color='${COL_ON}'>●</span>"
    else
        echo "<span color='${COL_OFF}'>○</span>"
    fi
}

# ── Build menu entries ──
SEP="───────────────────────"

WIFI_I=$(indicator wifi_on)
BT_I=$(indicator bt_on)
NL_I=$(indicator nightlight_on)
MIC_I=$(if mic_muted; then echo "<span color='${COL_ERR}'>●</span>"; else echo "<span color='${COL_ON}'>○</span>"; fi)
DND_I=$(indicator dnd_on)

WIFI_S=$(wifi_on && echo "ON" || echo "OFF")
BT_S=$(bt_on && echo "ON" || echo "OFF")
NL_S=$(nightlight_on && echo "ON" || echo "OFF")
MIC_S=$(mic_muted && echo "MUTED" || echo "LIVE")
DND_S=$(dnd_on && echo "ON" || echo "OFF")

ENTRIES="${WIFI_I}  WiFi            ${WIFI_S}
${BT_I}  Bluetooth       ${BT_S}
${NL_I}  Night Light     ${NL_S}
${MIC_I}  Mic Mute        ${MIC_S}
${DND_I}  Do Not Disturb  ${DND_S}
${SEP}
   Audio Settings
   Files
   Terminal
   Wallpaper
   Displays
${SEP}
   Lock
   Suspend
   Logout
   Reboot
   Shutdown"

# ── Show rofi ──
CHOICE=$(echo "$ENTRIES" | rofi -dmenu -markup-rows -p "" \
    -theme "$HOME/.config/rofi/panel.rasi")

[ -z "$CHOICE" ] && exit 0

# Strip markup to get clean text
CLEAN=$(echo "$CHOICE" | sed 's/<[^>]*>//g' | xargs)

# ── Handle selection ──
relaunch() { exec "$0"; }

case "$CLEAN" in
    *WiFi*)
        if wifi_on; then nmcli radio wifi off; else nmcli radio wifi on; fi
        relaunch ;;
    *Bluetooth*)
        if bt_on; then bluetoothctl power off; else bluetoothctl power on; fi
        sleep 0.5; relaunch ;;
    *"Night Light"*)
        if nightlight_on; then pkill wlsunset; else wlsunset -t 4000 -T 6500 & disown; fi
        sleep 0.3; relaunch ;;
    *"Mic Mute"*)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        relaunch ;;
    *"Do Not Disturb"*)
        swaync-client -d
        relaunch ;;
    *"Audio"*)
        pavucontrol & ;;
    *Files*)
        thunar & ;;
    *Terminal*)
        kitty & ;;
    *Wallpaper*)
        waypaper & ;;
    *Displays*)
        nwg-displays & ;;
    *Lock*)
        hyprlock ;;
    *Suspend*)
        systemctl suspend ;;
    *Logout*)
        hyprctl dispatch exit ;;
    *Reboot*)
        systemctl reboot ;;
    *Shutdown*)
        systemctl poweroff ;;
esac
