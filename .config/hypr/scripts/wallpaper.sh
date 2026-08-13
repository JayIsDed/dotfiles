#!/usr/bin/env bash
# wallpaper.sh — waypaper post_command hook. Waypaper sets the wallpaper;
# this regenerates the matugen palette and reloads hyprland so look.lua
# re-reads colors.conf. That is the whole pipeline now.
set -euo pipefail

wallpaper="${1:-}"
[ -z "$wallpaper" ] && exit 0

# --prefer: matugen 4.x panics non-interactively when an image yields multiple
# source-color candidates (waypaper runs this hook without a TTY).
# closest-to-fallback + pond green = warm bias: any green in the wallpaper
# wins the extraction; greenless wallpapers still theme off the nearest hue.
matugen image "$wallpaper" -m dark --prefer=closest-to-fallback --fallback-color "#4ade80"
hyprctl reload >/dev/null
