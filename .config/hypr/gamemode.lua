-- gamemode.lua — SUPER+ALT+G. Strips eye candy AND spins the AI shelf down
-- (llama-swap holds the 3090; games want it back). State derives from live
-- config, not a Lua variable, so it survives hyprctl reload mid-session.
-- shelf.sh handles docker; restore re-applies look.lua so the two can never
-- drift apart.

local look = require("look")
local shelf = os.getenv("HOME") .. "/.config/hypr/scripts/shelf.sh"

local function gamemode_active()
  local v = hl.get_config("animations:enabled")
  return v == false or v == 0
end

local function notify(msg)
  hl.exec_cmd(string.format(
    "notify-send -a 'Game Mode' -i input-gaming '%s'", msg))
end

-- GLOBAL on purpose: reachable from outside via
--   hyprctl dispatch "gamemode_toggle()"
-- (0.55+ dispatch args are Lua shorthand) — the lilypad panel uses this.
function gamemode_toggle()
  if gamemode_active() then
    look.apply()
    hl.exec_cmd(shelf .. " up")
    notify("Off — eye candy back, AI shelf restarting")
  else
    hl.config({
      animations = { enabled = false },
      decoration = {
        blur = { enabled = false },
        shadow = { enabled = false },
        rounding = 0,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        fullscreen_opacity = 1.0,
      },
      general = { gaps_in = 0, gaps_out = 0, border_size = 1 },
    })
    hl.exec_cmd(shelf .. " down")
    notify("On — eye candy off, AI shelf spinning down")
  end
end

hl.bind("SUPER + ALT + G", gamemode_toggle, { desc = "Game mode: toggle eye candy + AI shelf" })
