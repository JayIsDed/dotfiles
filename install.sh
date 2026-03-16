#!/bin/bash
# ┌──────────────────────────────────────────┐
# │      Arch + Hyprland Bootstrap           │
# │     github.com/JayIsDed/dotfiles         │
# └──────────────────────────────────────────┘
#
# Run on a fresh Arch install with a user account ready.
# Installs packages, deploys configs, sets up NVIDIA.

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config"

echo ""
echo "  ┌──────────────────────────────────────┐"
echo "  │    Arch + Hyprland Install Script     │"
echo "  │    AMD R9 7950X + RTX 3090            │"
echo "  └──────────────────────────────────────┘"
echo ""

# ─── Preflight ──────────────────────────────────────────
if [ ! -f /etc/arch-release ]; then
    echo "ERROR: This script is for Arch Linux only."
    exit 1
fi

echo "[1/7] Installing packages..."

# ─── Core Packages ──────────────────────────────────────
sudo pacman -S --needed --noconfirm \
    hyprland \
    xdg-desktop-portal-hyprland \
    waybar \
    kitty \
    rofi \
    swaync \
    swww \
    hyprlock \
    hypridle \
    matugen \
    ttf-jetbrains-mono-nerd \
    fastfetch \
    btop \
    cliphist \
    wl-clipboard \
    grim \
    slurp \
    imagemagick \
    jq \
    polkit-gnome \
    thunar \
    thunar-archive-plugin \
    gvfs \
    file-roller \
    playerctl \
    brightnessctl \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    wireplumber \
    pavucontrol \
    blueman \
    networkmanager \
    network-manager-applet \
    papirus-icon-theme \
    noto-fonts \
    noto-fonts-emoji \
    nwg-displays \
    qt5-wayland \
    qt6-wayland \
    xdg-desktop-portal-gtk \
    xdg-utils \
    xdg-user-dirs \
    openssh \
    git \
    github-cli \
    udiskie \
    udisks2 \
    socat \
    wtype \
    wf-recorder \
    fzf \
    qpwgraph \
    qt5ct \
    noto-fonts-cjk \
    loupe \
    evince \
    pacman-contrib \
    unzip \
    p7zip \
    man-db

echo "[2/7] Installing AUR packages (yay)..."

# ─── Install yay if not present ─────────────────────────
if ! command -v yay &>/dev/null; then
    echo "  Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    rm -rf /tmp/yay-bin
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
    rm -rf /tmp/yay-bin
fi

# ─── AUR Packages ──────────────────────────────────────
yay -S --needed --noconfirm \
    grimblast-git \
    waypaper \
    wlogout \
    satty-bin \
    bibata-cursor-theme

echo "[3/7] Installing NVIDIA drivers..."

# ─── NVIDIA ─────────────────────────────────────────────
sudo pacman -S --needed --noconfirm \
    nvidia-open-dkms \
    nvidia-utils \
    nvidia-settings \
    egl-wayland \
    lib32-nvidia-utils \
    linux-headers

echo "[4/7] Installing SDDM display manager..."

# ─── Display Manager ──────────────────────────────────
sudo pacman -S --needed --noconfirm \
    sddm \
    qt5-graphicaleffects \
    qt5-quickcontrols2

# Enable SDDM service
sudo systemctl enable sddm.service 2>/dev/null || true

echo "[5/7] Deploying dotfiles..."

# ─── Deploy Configs ─────────────────────────────────────
# Back up existing configs
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
CONFIGS=(
    hypr waybar kitty rofi fastfetch swaync
    hyprlock hypridle wlogout matugen waypaper btop
)

NEEDS_BACKUP=false
for dir in "${CONFIGS[@]}"; do
    if [ -d "$CONFIG_DIR/$dir" ]; then
        NEEDS_BACKUP=true
        break
    fi
done

if [ "$NEEDS_BACKUP" = true ]; then
    echo "  Backing up existing configs to $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    for dir in "${CONFIGS[@]}"; do
        if [ -d "$CONFIG_DIR/$dir" ]; then
            cp -r "$CONFIG_DIR/$dir" "$BACKUP_DIR/"
        fi
    done
fi

# Copy configs
cp -r "$DOTFILES_DIR/.config/"* "$CONFIG_DIR/"

# Create wallpapers directory
mkdir -p "$CONFIG_DIR/wallpapers"

# Ensure GTK dirs exist for Matugen output
mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"

# Ensure btop themes dir exists
mkdir -p "$CONFIG_DIR/btop/themes"

# Ensure cache dir exists
mkdir -p "$HOME/.cache/dotfiles"

echo "[6/7] Setting permissions..."

# ─── Permissions ────────────────────────────────────────
chmod +x "$CONFIG_DIR/hypr/scripts/"*.sh
chmod +x "$CONFIG_DIR/waybar/launch.sh"
chmod +x "$CONFIG_DIR/waybar/scripts/"*.sh

# Build font cache
fc-cache -f

# Set cursor theme
mkdir -p "$HOME/.local/share/icons/default"
cat > "$HOME/.local/share/icons/default/index.theme" << CURSOR
[Icon Theme]
Inherits=Bibata-Modern-Classic
CURSOR

# Set default applications
bash "$CONFIG_DIR/hypr/scripts/set-defaults.sh"

# Create Pictures/Videos dirs for screenshots/recordings
mkdir -p "$HOME/Pictures" "$HOME/Videos"

echo "[7/7] Final setup..."

# ─── User directories ──────────────────────────────────
xdg-user-dirs-update

# ─── Enable services ───────────────────────────────────
systemctl --user enable pipewire.service 2>/dev/null || true
systemctl --user enable pipewire-pulse.service 2>/dev/null || true
systemctl --user enable wireplumber.service 2>/dev/null || true

echo ""
echo "  ┌──────────────────────────────────────┐"
echo "  │           Install Complete            │"
echo "  ├──────────────────────────────────────┤"
echo "  │                                      │"
echo "  │  1. Add a wallpaper to:              │"
echo "  │     ~/.config/wallpapers/            │"
echo "  │                                      │"
echo "  │  2. Reboot to load NVIDIA drivers    │"
echo "  │                                      │"
echo "  │  3. Select Hyprland from SDDM login   │"
echo "  │                                      │"
echo "  │  4. SUPER+CTRL+W to pick wallpaper   │"
echo "  │     (auto-generates theme colors)    │"
echo "  │                                      │"
echo "  │  Keybinds:                           │"
echo "  │    SUPER+Enter      Terminal          │"
echo "  │    SUPER+CTRL+Ret   App Launcher      │"
echo "  │    SUPER+Q          Close Window      │"
echo "  │    SUPER+CTRL+W     Wallpaper         │"
echo "  │    SUPER+CTRL+L     Lock Screen       │"
echo "  │    SUPER+CTRL+Q     Power Menu        │"
echo "  │    SUPER+CTRL+K     Show Keybinds     │"
echo "  │    SUPER+1-0        Workspaces        │"
echo "  │                                      │"
echo "  └──────────────────────────────────────┘"
echo ""
