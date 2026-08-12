-- monitors.lua — triple-head layout, values from nwg-displays 2026-03-16.
-- DP-4: 34" ultrawide (main) · DP-5: 1440p portrait (right) · DP-6: 1440p (top)
-- If you re-run nwg-displays it writes hyprlang to monitors.conf — port values
-- here by hand; this file is the source of truth now.

hl.monitor({ output = "DP-4", mode = "3440x1440@165.0",   position = "3953x3820", scale = 1.0 })
hl.monitor({ output = "DP-5", mode = "2560x1440@164.54",  position = "2513x2940", scale = 1.0, transform = 1 })
hl.monitor({ output = "DP-6", mode = "2560x1440@165.0",   position = "4210x2378", scale = 1.0 })

-- Anything hotplugged (TV, capture dummy) lands right of the ultrawide.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
