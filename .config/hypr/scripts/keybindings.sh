#!/bin/bash
# Keybind viewer — parses keybinds.conf comments and shows in rofi
# Adapted from ML4W dotfiles (GPL-3.0, Stephan Raabe)

CONFIG="$HOME/.config/hypr/conf/keybinds.conf"

if [ ! -f "$CONFIG" ]; then
    notify-send "Keybinds" "Config not found: $CONFIG"
    exit 1
fi

# Parse keybinds — extracts key combo + comment description
keybinds=$(awk -F'#' '
    /^bind/ && NF >= 2 {
        # Get the bind line (before comment) and description (after comment)
        line = $1
        desc = $2
        gsub(/^[ \t]+|[ \t]+$/, "", desc)

        # Skip if no description
        if (desc == "") next

        # Extract modifier + key from bind line
        # Format: bind[flags] = MOD, KEY, dispatcher, args
        sub(/^bind[a-z]*[ \t]*=[ \t]*/, "", line)
        n = split(line, parts, /[ \t]*,[ \t]*/)
        mod = parts[1]
        key = parts[2]

        # Clean up modifier names
        gsub(/\$mainMod/, "SUPER", mod)
        gsub(/[ \t]+/, " + ", mod)

        # Build combo string
        if (key != "")
            combo = toupper(mod) " + " toupper(key)
        else
            combo = toupper(mod)

        # Pad combo for alignment
        printf "%-30s %s\n", combo, desc
    }
' "$CONFIG")

# Show in rofi
echo "$keybinds" | rofi -dmenu -i -p "Keybinds" \
    -theme-str 'window { width: 700px; }' \
    -theme-str 'listview { lines: 20; }' \
    -theme-str '* { font: "JetBrainsMono Nerd Font 11"; }'
