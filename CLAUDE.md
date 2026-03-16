# CLAUDE.md — dotfiles

Custom Arch Linux + Hyprland dotfiles with glass theming.

## Architecture

- **Hyprland configs** split into `conf/` for modularity
- **Matugen pipeline**: wallpaper -> color extraction -> templates -> per-app color files
- **Glass effect**: Hyprland GPU blur + CSS radial gradients + inset white shadow
- **Placeholder colors**: Tokyo Night palette, overwritten by Matugen on first wallpaper set

## Key Files

- `install.sh` — bootstrap script for fresh Arch install
- `.config/hypr/scripts/wallpaper.sh` — wallpaper + theming orchestrator
- `.config/matugen/config.toml` — template -> output mappings
- `.config/matugen/templates/` — Jinja2 color templates per app

## Hardware Target

AMD Ryzen 9 7950X, 96GB DDR5, NVIDIA RTX 3090 (nvidia-open-dkms)
