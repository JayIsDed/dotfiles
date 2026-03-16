#!/bin/bash
# Feature browser — searchable list of all desktop features
# SUPER+F1 to open

FEATURES=$(cat << 'FEATURES_LIST'
 APPLICATIONS
SUPER + Enter                    Open terminal (Kitty)
SUPER + B                        Open browser (Firefox)
SUPER + E                        Open file manager (Thunar)
SUPER + CTRL + Return            Application launcher (Rofi)
CTRL + Tab                       Window switcher

 WINDOW MANAGEMENT
SUPER + Q                        Close active window
SUPER + F                        Toggle fullscreen
SUPER + M                        Toggle maximize (keep gaps)
SUPER + T                        Toggle floating/tiling
SUPER + J                        Toggle split direction
SUPER + K                        Swap split panes
SUPER + G                        Toggle window group (tabs)
SUPER + P                        Pseudo-tile window
ALT + Tab                        Cycle next window
ALT + SHIFT + Tab                Cycle previous window

 FOCUS & NAVIGATION
SUPER + Arrows/HJKL              Move focus
SUPER + SHIFT + Arrows/HJKL      Move window
SUPER + ALT + Arrows             Swap windows
SUPER + CTRL + Arrows             Resize (quick)
SUPER + R                        Enter resize mode (modal)

 WORKSPACES
SUPER + 1-0                      Switch workspace 1-10
SUPER + SHIFT + 1-0              Move window to workspace
SUPER + Tab                      Next workspace
SUPER + SHIFT + Tab              Previous workspace
SUPER + Scroll                   Scroll through workspaces

 SCRATCHPADS
SUPER + Backtick                 Toggle terminal scratchpad
SUPER + SHIFT + Backtick         Send window to scratchpad
SUPER + F12                      Toggle system monitor (btop)
SUPER + F11                      Toggle music player

 SCREENSHOTS & RECORDING
SUPER + Print                    Screenshot area to clipboard
SUPER + ALT + S                  Screenshot area (alt keybind)
SUPER + ALT + F                  Screenshot full screen
SUPER + SHIFT + S                Screenshot + annotate (Satty)
SUPER + SHIFT + R                Toggle screen recording

 THEMING & DISPLAY
SUPER + CTRL + W                 Wallpaper picker (auto-themes)
SUPER + D                        Display manager (arrange monitors)
SUPER + ALT + G                  Toggle game mode (max perf)
SUPER + SHIFT + B                Reload waybar
SUPER + CTRL + B                 Toggle waybar visibility

 SYSTEM
SUPER + CTRL + Q                 Power menu (wlogout)
SUPER + CTRL + L                 Lock screen
SUPER + CTRL + R                 Reload Hyprland config
SUPER + N                        Toggle notification center

 CLIPBOARD & TEXT
SUPER + V                        Clipboard history (Rofi)
SUPER + ALT + D                  Type today's date
SUPER + ALT + T                  Type current time

 FUZZY FINDERS
SUPER + O                        Open project (~/git picker)
SUPER + SHIFT + F                Focus any window by title

 SPECIAL MODES
SUPER + R                        Resize mode (arrows to resize, Esc to exit)
SUPER + SHIFT + P                SSH passthrough (all keys go to remote)
SUPER + SHIFT + P again          Exit passthrough mode

 ZOOM
SUPER + SHIFT + Scroll           Zoom in/out
SUPER + SHIFT + Z                Reset zoom to 1x

 MOUSE
SUPER + Left Click Drag          Move window
SUPER + Right Click Drag         Resize window

 AUDIO & MEDIA
Volume Keys                      Volume up/down/mute
Media Keys                       Play/pause/next/previous

 HELP
SUPER + CTRL + K                 Search all keybindings
SUPER + F1                       This feature browser

 WAYBAR MODULES
Click GPU module                 NVIDIA GPU usage + temp
Click Docker module              SSH to docker-services (LXC 112)
Click Updates module             Run system update

 AUTOMATION
USB drives auto-mount            udiskie (tray icon)
Wallpaper change                 Auto-themes entire desktop via Matugen
Game mode                        Strips all effects for max FPS
FEATURES_LIST
)

echo "$FEATURES" | rofi -dmenu -i -p " Features" -markup-rows \
    -theme-str 'window { width: 800px; }' \
    -theme-str 'listview { lines: 25; scrollbar: true; }' \
    -theme-str '* { font: "JetBrainsMono Nerd Font 11"; }'
