#!/bin/bash
# Wallpaper handler — sets wallpaper + generates Matugen theme
# Called by waypaper post_command or manually

CACHE_DIR="$HOME/.cache/dotfiles"
WALLPAPER_DIR="$HOME/.config/wallpapers"
DEFAULT_WALLPAPER="$WALLPAPER_DIR/default.jpg"

mkdir -p "$CACHE_DIR"

# Get wallpaper path — from arg, cache, or default
if [ -n "$1" ]; then
    WALLPAPER="$1"
elif [ -f "$CACHE_DIR/current_wallpaper" ]; then
    WALLPAPER=$(cat "$CACHE_DIR/current_wallpaper")
else
    WALLPAPER="$DEFAULT_WALLPAPER"
fi

# Bail if wallpaper doesn't exist
if [ ! -f "$WALLPAPER" ]; then
    echo "Wallpaper not found: $WALLPAPER"
    exit 1
fi

# Cache current wallpaper path
echo "$WALLPAPER" > "$CACHE_DIR/current_wallpaper"

# Set wallpaper via swww with transition
swww img "$WALLPAPER" \
    --transition-type grow \
    --transition-duration 1.5 \
    --transition-fps 60 \
    --transition-pos 0.5,0.5

# Detect dark/light mode (default dark)
MODE="dark"
if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
    GTK_THEME=$(grep "gtk-theme-name" "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null)
    if echo "$GTK_THEME" | grep -qi "light"; then
        MODE="light"
    fi
fi

# Generate colors with Matugen
matugen image "$WALLPAPER" -m "$MODE"

# Generate blurred wallpaper for rofi/wlogout/hyprlock
BLURRED="$CACHE_DIR/blurred_wallpaper.png"
magick "$WALLPAPER" -resize 75% -blur 50x30 "$BLURRED"

# Generate square thumbnail (for dock/launcher previews)
SQUARE="$CACHE_DIR/square_wallpaper.png"
SIZE=$(magick identify -format "%[fx:min(w,h)]" "$WALLPAPER")
magick "$WALLPAPER" -gravity center -crop "${SIZE}x${SIZE}+0+0" +repage -resize 200x200 "$SQUARE"

# Write rofi background reference
cat > "$HOME/.config/rofi/wallpaper.rasi" << RASI
* { current-image: url("$BLURRED", height); }
RASI

# Reload apps
~/.config/waybar/launch.sh &
swaync-client -rs &
pkill -SIGUSR1 kitty 2>/dev/null

echo "Theme applied: $WALLPAPER ($MODE mode)"
