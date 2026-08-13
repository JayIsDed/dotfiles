-- monitors.lua — per-host layouts, values from nwg-displays (archbox 2026-03-16).
-- If you re-run nwg-displays it writes hyprlang to monitors.conf — port values
-- here by hand; this file is the source of truth now.

local hosts = require("hosts")

if hosts.is_laptop then
  -- X1C9: 4K 16:10 internal panel
  hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1.25 })
else
  -- archbox triple-head:
  -- DP-4: 34" ultrawide (main) · DP-5: 1440p portrait (right) · DP-6: 1440p (top)
  hl.monitor({ output = "DP-4", mode = "3440x1440@165.0",  position = "3953x3820", scale = 1.0 })
  hl.monitor({ output = "DP-5", mode = "2560x1440@164.54", position = "2513x2940", scale = 1.0, transform = 1 })
  hl.monitor({ output = "DP-6", mode = "2560x1440@165.0",  position = "4210x2378", scale = 1.0 })
end

-- Anything hotplugged (dock, TV, projector) lands adjacent, auto everything.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
