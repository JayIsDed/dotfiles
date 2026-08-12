#!/usr/bin/env bash
# wallpaper.sh — waypaper post_command hook. Waypaper sets the wallpaper;
# this regenerates the matugen palette and reloads hyprland so look.lua
# re-reads colors.conf. That is the whole pipeline now.
set -euo pipefail

wallpaper="${1:-}"
[ -z "$wallpaper" ] && exit 0

matugen image "$wallpaper" -m dark
hyprctl reload >/dev/null
