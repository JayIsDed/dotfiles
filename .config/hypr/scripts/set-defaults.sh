#!/bin/bash
# Set default applications via xdg-mime
# Run once after install, or after adding new apps

# Browser
xdg-settings set default-web-browser firefox.desktop

# File manager
xdg-mime default thunar.desktop inode/directory

# Images
xdg-mime default org.gnome.Loupe.desktop image/png
xdg-mime default org.gnome.Loupe.desktop image/jpeg
xdg-mime default org.gnome.Loupe.desktop image/gif
xdg-mime default org.gnome.Loupe.desktop image/webp

# Text
xdg-mime default kitty-open.desktop text/plain

# PDF
xdg-mime default org.gnome.Evince.desktop application/pdf

echo "Default applications set."
