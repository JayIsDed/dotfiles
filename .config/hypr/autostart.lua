-- autostart.lua — session daemons. ML4W listeners/welcome/settings gone.
-- waybar stays until the Quickshell shell is live, then swap the line.
--
-- RELOAD GUARD: hyprctl reload re-executes this file, which re-fired every
-- exec (found as 3x hypridle / 3x keyring / 6x swaync on 2026-08-12). The
-- marker is keyed to the instance signature: same instance skips, a fresh
-- login starts clean.

local marker = os.getenv("XDG_RUNTIME_DIR") .. "/hypr-autostart-"
  .. (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "unknown")

local function already_ran()
  local f = io.open(marker, "r")
  if f then f:close(); return true end
  local m = io.open(marker, "w")
  if m then m:write("1"); m:close() end
  return false
end

hl.on("hyprland.start", function()
  if already_ran() then return end
  hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,ssh")
  -- polkit agent + idle: dms ships both (PolkitService default-on +
  -- IdleService timers in settings.json), so the laptop — fully on dms
  -- lock/idle since 08-14 — skips them. Archbox keeps hypridle +
  -- polkit-gnome until its idle keys land (desk seat).
  if not require("hosts").is_laptop then
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("hypridle")
  end
  hl.exec_cmd("wl-paste --watch cliphist store")
  -- dms (DankMaterialShell) — ADOPTED 2026-08-13. `dms run` = qs -c dms
  -- (~/.config/quickshell is a REAL dir since 08-13: dms + lilypad
  -- entries) and hosts the CLI server the CC network panel needs.
  -- Laptop runs it unconditionally; other hosts opt in via the flag file
  -- (staged by scripts/port-dms-archbox) — rollback = rm the flag, relog.
  local dms_flag = io.open(os.getenv("HOME") .. "/.config/dms-adopted", "r")
  if dms_flag then dms_flag:close() end
  if require("hosts").is_laptop or dms_flag then
    -- no swaync here: dms IS the notification daemon (DBus name fight)
    -- PATH prefix so spawns find dms/dgop/matugen-shim in ~/.local/bin.
    -- dms owns the wallpaper layer, so no waypaper restore here.
    -- Launching from the SEAT session also keeps polkit quiet (wifi
    -- scans from SSH-launched shells prompt for auth — 08-13 lesson).
    hl.exec_cmd("sh -c 'PATH=$HOME/.local/bin:$PATH exec dms run'")
  else
    -- pre-port hosts: waybar + swaync until their dms seat lands.
    -- waybar via ML4W launch.sh (assembles themed config from themes/) —
    -- bare `waybar` renders stock.
    hl.exec_cmd("swaync")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/waybar/launch.sh")
    hl.exec_cmd("awww-daemon")         -- wallpaper daemon (waypaper backend)
    hl.exec_cmd("waypaper --restore")
  end
  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
end)
