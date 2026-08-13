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
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
  hl.exec_cmd("swaync")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("wl-paste --watch cliphist store")
  if require("hosts").is_laptop then
    -- dms (DankMaterialShell) — ADOPTED 2026-08-13. Runs from the git
    -- clone (their supported dev mode); PATH prefix so its spawns find
    -- dms/dgop/matugen-shim in ~/.local/bin. dms owns the wallpaper
    -- layer, so no waypaper restore here.
    hl.exec_cmd("sh -c 'PATH=$HOME/.local/bin:$PATH exec qs -p $HOME/git/reference/DankMaterialShell/quickshell'")
  else
    -- archbox stays on waybar until its dms port seat.
    -- waybar via ML4W launch.sh (assembles themed config from themes/) —
    -- bare `waybar` renders stock.
    hl.exec_cmd(os.getenv("HOME") .. "/.config/waybar/launch.sh")
    hl.exec_cmd("awww-daemon")         -- wallpaper daemon (waypaper backend)
    hl.exec_cmd("waypaper --restore")
  end
  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
end)
