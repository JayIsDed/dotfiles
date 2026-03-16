# Arch Linux Install Guide (archinstall)

Step-by-step guide for archinstall selections tailored to this dotfiles setup.
Hardware: AMD Ryzen 9 7950X, 96GB DDR5, NVIDIA RTX 3090

## Pre-Install

1. Download Arch ISO from archlinux.org
2. Flash to USB (Ventoy, Rufus, or `dd`)
3. Boot from USB, select Arch Linux
4. You'll land at a root shell — verify internet: `ping archlinux.org`
5. Run: `archinstall`

## archinstall Selections

### Archinstall language
`English`

### Locales
- Keyboard layout: `us`
- Locale language: `en_US`
- Locale encoding: `UTF-8`

### Mirrors
- Mirror region: pick your country (or leave auto)

### Disk configuration
- Select `Use a best-effort default partition layout`
- Select your target drive (the NVMe/SSD you want Arch on)
- Filesystem: **`ext4`** (simple, reliable) or **`btrfs`** (if you want snapshots)
- Use default subvolume structure if btrfs
- Say **Yes** to separate `/home` partition if asked — keeps your data safe on reinstalls

### Disk encryption
- **Skip** unless you specifically want full disk encryption
- You can always encrypt later if needed

### Bootloader
- **`systemd-boot`** (default, recommended)
- Works great with NVIDIA, simpler than GRUB

### Swap
- **`True`** — let it create a swap partition
- With 96GB RAM you rarely hit swap, but it's needed for hibernate

### Hostname
- Whatever you want your machine called (e.g., `pancake-desktop`, `archbox`)

### Root password
- Set one, or skip if you prefer sudo-only (next step)

### User account
- Add a user account for yourself
- Set as **superuser (sudo)** — Yes
- Set password

### Profile
- Select: **`Minimal`**
- Do NOT select Desktop or Hyprland here — our install.sh handles everything
- Selecting a desktop profile would install conflicting packages and configs

### Audio
- Select: **`pipewire`**

### Kernel
- Select: **`linux`** (standard kernel)
- `linux-lts` is fine too but nvidia-open-dkms tracks the standard kernel better

### Additional packages
- Type these separated by spaces:
  ```
  git base-devel
  ```
- That's all you need — our install.sh handles the rest

### Network configuration
- Select: **`NetworkManager`**
- This is what our waybar network module and nm-applet expect

### Timezone
- Select your timezone (e.g., `America/New_York`)

### Automatic time sync (NTP)
- **`True`**

### Optional repositories
- Enable **`multilib`** — needed for `lib32-nvidia-utils` (32-bit game support)

## Post-Install (after reboot)

archinstall will finish and ask to chroot or reboot. **Reboot.**

Remove the USB drive, boot into your new Arch install. You'll land at a TTY login.

```bash
# Login with your user account

# Clone dotfiles
git clone https://github.com/JayIsDed/dotfiles.git ~/dotfiles

# Run the install script
cd ~/dotfiles
chmod +x install.sh
./install.sh

# Reboot to load NVIDIA drivers and start SDDM
sudo reboot
```

After reboot, SDDM login screen appears. Select **Hyprland** from the session dropdown, login, and you're in.

## First Boot Checklist

1. **SUPER+D** — open nwg-displays, drag your 3 monitors into position, apply
2. **SUPER+W** — open waypaper, pick a wallpaper (this generates your color theme)
3. **SUPER+Enter** — open kitty terminal, run `fastfetch` to verify
4. **SUPER+Space** — test rofi app launcher
5. Check audio: click the volume icon in waybar or `SUPER+Enter` then `pavucontrol`

## Troubleshooting

### Black screen after login
NVIDIA issue. Switch to TTY2 (`Ctrl+Alt+F2`), login, and check:
```bash
# Verify NVIDIA module is loaded
lsmod | grep nvidia

# If not loaded, regenerate initramfs
sudo mkinitcpio -P

# Reboot
sudo reboot
```

### No display output / wrong resolution
```bash
# From TTY, check connected displays
cat /sys/class/drm/*/status

# Force Hyprland to log
Hyprland > /tmp/hypr.log 2>&1

# Check the log for errors
cat /tmp/hypr.log | grep -i error
```

### SDDM doesn't appear
```bash
# Check if service is enabled
systemctl status sddm

# Enable if not
sudo systemctl enable sddm
sudo reboot
```
