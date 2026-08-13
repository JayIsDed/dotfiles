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

## Session 2 (2026-08-12 late) — token board + verified API additions

- **VERIFIED on 0.3.0**: `FileView` (Quickshell.Io) — path / watchChanges /
  onFileChanged / onLoaded / text(), and `Quickshell.env()`. Used by Theme.qml.
- **QML rule**: property names may NOT start with `on`+Capital (collides with
  signal-handler syntax) — this is WHY end-4 prefixes every palette color `m3`.
  We adopted the same convention.
- **Theme.qml is now the token board**: m3 raw palette (matugen-fed, mutable) →
  layers l0–l3 (each with Text/Hover/Active/Border, derived via mix()) → fixed
  status hues (green/amber/red/blue/purple — deliberately wallpaper-proof) →
  graph tokens (meter/gauge/spark/track/thresholds) → legacy v1 aliases (all 18
  consumer tokens preserved). Palette feed: matugen `[templates.lilypad]` →
  `~/.local/state/quickshell/lilypad/colors.json` → FileView live-patch, no
  shell bounce (PROVEN via hand-written test JSON — pink ring test).
- **Jay's design brief v2 (tonight)**: FULL matugen (pond = fallback statics
  only); stacked thin MeterBars > circle gauges on the bar (gauges live in
  popups); metrics island ON the bar (sys stats + condensed sys card + Claude
  usage), click → full-depth system view; render-scale chip 100/125/150/175/200
  (4K 14" panel); overview grid (end-4 port) queued as Phase 4.
- **Claude usage feed (verified via plugin src + web)**: claude.ai/api/oauth/usage,
  token from ~/.claude/.credentials.json → five_hour / seven_day (+seven_day_sonnet)
  each utilization 0-100 + resets_at. NO fable bucket — Fable draws the shared
  weekly, capped at 50% of it → draw a marker at 50% on the 7d bar.
- **Reference clone**: end-4/dots-hyprland at `~/git/reference/dots-hyprland`
  (on 111). Steal from dots/.config/quickshell/ii/ — Appearance.qml (tokens),
  StyledPopup.qml (PanelWindow+mask popover, no PopupWindow), sidebarRight/
  (wifi/bt/volume/calendar/todo dropdown content), overview/. Their qs.modules.*
  imports are a NEWER quickshell feature — port patterns, never copy imports.
- **Laptop drift fixed**: ~/.config/matugen symlink pointed at the dead ML4W
  tree — repointed to ~/dotfiles/.config/matugen. matugen itself NOT installed
  yet (extra/matugen 4.1.0, needs Jay's local sudo; fprintd blocks SSH sudo).
  Until then colors.json holds the pink test palette.
- Laptop roams: .101 → **.247** (ssh alias `x1c` stale). Monitor scale
  currently 1.25 (3072 logical width); Jay's daily driver is 125%.
- **matugen 4.x gotchas**: panics WITHOUT --prefer when an image has multiple
  source candidates and no TTY (waypaper hook = no TTY). Empirical dial table
  on the wallnest foliage wallpaper: darkness/less-saturation/value → slate →
  ice blue; lightness → mint; saturation → sky → periwinkle;
  **closest-to-fallback + --fallback-color #4ade80 → foliage → leaf green
  #a0d39a (CHOSEN — pond green as extraction bias, wallpaper.sh sets it)**.
  Test dials safely with `--dry-run --json hex` (nested {dark:{color}} shape).
- **Graph kit shipped (Phase 1)**: MeterBar (marker ticks, threshold auto-color,
  pinnable), Gauge (Canvas ring, popup furniture), Spark (autoscale or pinned
  range). Same-dir flat files; consumed like any type. Visually verified.
- **Workspace clicks fixed**: `Hyprland.dispatch("workspace(N)")` — Lua
  shorthand, the old "workspace N" hyprlang string errors on 0.55+.

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

## State at session-2 close (2026-08-12 23:48) — DISPLAY LAYER DONE

- **The bar v2 is COMPLETE and live on the laptop** (30 commits, ef67736 →
  95e3d5e): matugen palette (pond-green fallback anchor), graph kit
  (MeterBar/Gauge/Spark), tile-row geometry (3 fixed anchors ws/clock/power +
  2 self-centering span bundles), metrics everywhere — cpu/ram/dsk ·
  tmp/fan dual-spark · claude 5h/7d (111 relay, 50% fable tick) · rx/tx ·
  TS badge + homelab RTT · SysCard west · DockerTile (VM 202 vitals 45/47) ·
  TaskSwitcher chips · brightness wheel · PowerDraw ±W + 0-65W rate bar ·
  Battery ring. All pills share one grammar: label | visual | number.
- **New gotchas in the ledger above** + errors-and-fixes: on+Capital property
  names, new component FILES need a shell bounce, visibility-deadlock (bind
  data props, never child .visible), matugen --prefer non-interactive panic.
- **Jay finger-tests still pending**: task-chip click (wayland activate +
  dispatch fallback), workspace click (Lua shorthand fix), brightness wheel.
- **Next seat = Phase 3 popovers**: shared click-popover (StyledPopup pattern,
  PanelWindow+mask) → deep system view → volume/wifi/battery/calendar/updates
  dropdowns → render-scale chip (100-200%) → responsive priority-collapse for
  the bundles (spotify guards are interim: 18ch chips + x-clamps). Then
  Phase 4 overview grid; then archbox port (NVML/iCX3/llama-swap widgets) →
  autostart swap → retire waybar + ~/.mydotfiles.
- Launch on laptop is still MANUAL (autostart says waybar until the swap).
- Archbox: untouched tonight; waybar (ML4W themed) still its bar.

## Session 3 (2026-08-13 ~00:15) — real-estate pass, live-steered

- Two overlaps Jay caught post-close, both from bundles having only LEFT
  clamps: TS badge ran into powerTile, dvm tile into the clock.
- **TS badge folded into Network.qml** (powerTile): SSID tinted by tunnel
  state (ok home / info away / warn off-or-lost), house 󰋜 at home vs tunnel
  󰖂 away, homelab RTT beside it. tsProbe moved wholesale, semantics intact.
- **TaskSwitcher takes a `budget` (px) from Bar**: chips even-split the
  ws↔clock span (minus dvm tile) and pixel-elide; below 96px/chip they show
  wayland appId instead of titles (appId VERIFIED against end-4 source),
  floor 38px. Squeeze-tested with 3 spawned kitties: 7 chips compressed
  evenly, dvm stayed clear of the clock, chips relax when load drops.
- **Sys card off the bar → ControlPanel** (component reused; its probe only
  runs while the panel is open). **Net seg = plain rx/tx rates** — sparks
  dropped, Jay doesn't watch flow; detail belongs to the phase-3 system view.
- Bundles still have no GENERAL shrink — priority-collapse stays Phase 3's
  job; tonight removed the actual overflow sources, not the class of bug.
- **Laptop repo drift**: laptop ~/dotfiles never tracked .config/quickshell/
  (whole dir untracked) + local hypr/matugen mods. The running bar is
  scp-fed; canon is 111's clone. Reconcile when convenient.
- **pgrep -f self-matches too** (read-only cousin of the pkill trap): kill
  spawned test windows by saved PID, verify via `ps | grep "[s]queeze"`.
- x1c ssh alias still .101; laptop answers on .247 — reservation didn't
  hold. Fix alias or DHCP before the next remote seat trips on it.
