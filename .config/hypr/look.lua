-- look.lua — general/decoration/animations. Exposes M.apply() so gamemode.lua
-- can restore the full look after stripping it; keep every value inside apply().

local M = {}

-- matugen writes hyprlang "$name = rgba(xxxxxxff)" into colors.conf on every
-- wallpaper change; parse it so the pipeline survives the Lua port untouched.
local function matugen_colors()
  local colors = {}
  local f = io.open(os.getenv("HOME") .. "/.config/hypr/colors.conf", "r")
  if not f then return colors end
  for line in f:lines() do
    local name, val = line:match("^%$([%w_]+)%s*=%s*(rgba?%([%x%s]+%))")
    if name then colors[name] = val end
  end
  f:close()
  return colors
end

function M.apply()
  local c = matugen_colors()
  hl.config({
    general = {
      gaps_in = 4,
      gaps_out = 8,
      border_size = 1,
      col = {
        active_border = c.primary and { colors = { c.primary, c.on_primary }, angle = 90 }
                        or "rgba(5cc8e8ee)",
        inactive_border = c.on_primary or "rgba(595959aa)",
      },
      resize_on_border = true,
      layout = "dwindle",
    },
    decoration = {
      rounding = 8,
      active_opacity = 1.0,
      inactive_opacity = 0.9,
      fullscreen_opacity = 1.0,
      blur = {
        enabled = true,
        size = 4,
        passes = 4,
        ignore_opacity = true,
        xray = true,
      },
      shadow = {
        enabled = true,
        range = 32,
        render_power = 2,
        color = "rgba(00000050)",
      },
    },
    animations = { enabled = true },
    dwindle = {
      preserve_split = true,
      smart_split = true,
    },
  })
end

-- md3 curve set carried over from the old rice; the ones nothing referenced
-- (crazyshot, easeInOutCirc, ...) did not make the cut.
hl.curve("linear",     { type = "bezier", points = { {0, 0},      {1, 1}     } })
hl.curve("md3_decel",  { type = "bezier", points = { {0.05, 0.7}, {0.1, 1}   } })
hl.curve("md3_accel",  { type = "bezier", points = { {0.3, 0},    {0.8, 0.15} } })
hl.curve("menu_decel", { type = "bezier", points = { {0.1, 1},    {0, 1}     } })
hl.curve("menu_accel", { type = "bezier", points = { {0.38, 0.04}, {1, 0.07} } })

hl.animation({ leaf = "windows",       enabled = true, speed = 3,   bezier = "md3_decel",  style = "popin 60%" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 3,   bezier = "md3_decel",  style = "popin 60%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3,   bezier = "md3_accel",  style = "popin 60%" })
hl.animation({ leaf = "border",        enabled = true, speed = 10,  bezier = "linear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3,   bezier = "md3_decel" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 3,   bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.6, bezier = "menu_accel" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2,   bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 4.5, bezier = "menu_accel" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 7,   bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "md3_decel", style = "slidevert" })

hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    initial_workspace_tracking = 1,
    on_focus_under_fullscreen = 1,
    allow_session_lock_restore = true,
  },
})

M.apply()

return M
