# lilypad — seat handoff (2026-08-12, session 1)

Quickshell bar + control panel for the two-host Hyprland stack (taichi = archbox
triple-head / ThinkPadX1C = laptop iteration rig). Pond-token theme. This doc is
the contract between seats: read it fully before touching QML.

## Step 0 for a fresh seat — ingest before deriving

1. **Full type reference** at quickshell.org/docs/v0.3.0 for every type we use:
   PanelWindow, Variants, PopupWindow, LazyLoader, HyprlandFocusGrab, Process,
   StdioCollector, FileView, Singleton, SystemTray, UPower, **Pipewire (PwNode /
   PwNodeAudio — volume property names UNVERIFIED, we shipped wpctl polling
   instead)**, **Quickshell.Networking (property names UNVERIFIED, we shipped
   nmcli polling instead)**.
2. **GitHub issues** (quickshell repo) — mine solved issues for: singleton
   hot-reload behavior, PopupWindow focus/dismiss patterns on Hyprland,
   per-monitor Variants pitfalls, SystemTray menu handling.
3. caelestia-dots/shell source — real 0.3.0-era consumer, steal popover patterns.

## Hard-won session facts (do not re-derive these)

- **Launch**: `qs -p ~/dotfiles/.config/quickshell/lilypad` — `-c lilypad`
  discovery FAILED through the ~/.config/quickshell symlink; -p is reliable.
- **Headless/SSH launch env** (for driving iteration remotely): construct
  explicitly — HOME, USER, PATH, LANG=en_US.UTF-8, XDG_RUNTIME_DIR,
  WAYLAND_DISPLAY (check socket name), DBUS_SESSION_BUS_ADDRESS,
  HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1),
  QT_QPA_PLATFORM=wayland. Scraping a donor process env picked an env-poor
  process once and Qt fell back to xcb and died. Never scrape.
- **Singleton files (Theme.qml) do NOT hot-reload reliably** — bounce the shell
  (`pkill -x qs`, relaunch) after editing them. Component files hot-reload on
  save/scp within ~2s.
- **`pkill -f` self-matches** the SSH shell carrying your script text. Use
  `pkill -x qs`. This killed our own session twice.
- A stale-cache hot-reload once reported "Clock is not a type" when the real
  error was a missing `import Quickshell` in ScriptModule. When hot-reload
  errors look insane, run a fresh one-shot `timeout 5 qs -p <dir>` — it prints
  the true error.
- **Verification loop**: `grim -s 0.6 /tmp/shot.png` over SSH works (no
  permission gate configured). Crop the top strip, look at it. Jay's "it didn't
  change" was a singleton-reload miss — screenshot before concluding.
- Hyprland side: `hyprctl dispatch exec "cmd"` is **Lua shorthand** in 0.55+ —
  args are Lua code, not hyprlang. External trigger for game mode:
  `hyprctl dispatch "gamemode_toggle()"` (global fn in hypr/gamemode.lua).
- waybar-JSON convention carried over: ScriptModule hides when script output is
  empty; `class` maps critical/urgent→red, warning/disconnected→amber.

## Architecture

- `shell.qml` → Variants over screens → `Bar.qml` (full-width transparent
  window, floating island drawn inset — PanelWindow margin API was unverified
  so the island is a Rectangle; geometry from the 2025 custom waybar: 40 high,
  6 top / 10 sides).
- `Theme.qml` — pragma Singleton, pond tokens (mirror of the-pond
  shared/tokens.css). Matugen JSON hookup is a planned upgrade (FileView +
  JsonAdapter watching a matugen template output).
- `ScriptModule.qml` — generic runner for the 2025 waybar scripts in
  `scripts/` (unchanged shell, waybar-JSON out). leftCmd/rightCmd arrays run
  via Process, auto-refresh 200ms after action.
- `ControlPanel.qml` — PopupWindow off the bar's lilypad button. Host-gated
  lab buttons (ssh claude-dev lab-*). Barely styled; needs its pass.
- Blur: hypr/rules.lua has a layer rule for namespace ^lilypad$ (blur +
  ignore_alpha 0.29); bar paints bg at 0.62 alpha.

## Jay's design brief (2026-08-12 21:09, verbatim intent)

1. Right-side modules become **buttons**: pill/chip containers like the
   workspace pills, real hover states (background shift, not just text
   brightening).
2. **Dropdowns, not app launches**: click battery → power panel; network →
   wifi list; volume → slider + device picker; updates → package list with an
   in-shell action; clock → calendar (old waybar had a calendar tooltip he
   used). Apps stay reachable via right-click or a button inside the dropdown.
3. "The update cycle is weird" — the updates module currently spawns
   `kitty -e sudo pacman -Syu` on click. Rework as dropdown first; the actual
   upgrade action still needs a terminal (sudo/fingerprint) but should feel
   deliberate, not a surprise terminal.
4. Build a shared popover component ONCE (anchor to module, HyprlandFocusGrab,
   dismiss on outside click) and hang every dropdown off it.

## Queue after the popover phase

- ControlPanel visual pass (pond glass, same popover framework).
- Laptop: brightness slider (brightnessctl), maybe three-island bar split.
- **Archbox port**: NVML/iCX3 temp widgets (archtop reads NVML ~8µs via ctypes;
  iCX3 file at /var/lib/archbox-sensors/icx.influx — tail it, do NOT open
  /dev/i2c), Claude usage meter (claude-dashboard plugin / bench-bridge usage),
  game-mode button wired to gamemode_toggle(), llama-swap shelf status
  (scripts/shelf.sh status), per-monitor bar check on the 610 nvidia driver.
- Autostart swap when stable: hypr/autostart.lua waybar line → qs (per-host).
- Retire waybar + ~/.mydotfiles after both hosts are on lilypad.

## State right now

- Laptop: lilypad running (manual launch, log at /tmp/lilypad.log), waybar
  killed for the session (relogin restores it — autostart still says waybar).
- Laptop system: update script staged at /tmp/overhaul.sh (Jay runs with local
  sudo/fingerprint; ~126 pkgs + kernel 7.1.8 + orphans + cache). Reboot pending
  after. Btrfs safety snapshot /.pre-overhaul-20260812 gets made by the script.
- Archbox: full Lua hypr config live and stable, waybar (ML4W themed) still its
  bar. Everything committed on dotfiles feat/lua-rebuild.
