-- workspaces.lua — archbox pins 1-3 ultrawide / 4-6 top / 7-9 portrait with a
-- default landing per head. Single-monitor hosts need no pinning at all.

local hosts = require("hosts")

if hosts.is_laptop then
  -- five pre-allocated workspace dots (Jay 08-13): the dms switcher shows
  -- what the compositor reports, so persistence lives HERE, not in the bar
  -- (their padding hardcodes to 3).
  for ws = 1, 5 do
    hl.workspace_rule({ workspace = tostring(ws), persistent = true })
  end
end

if not hosts.is_laptop then
  local pin = {
    { ws = 1, mon = "DP-4", default = true },
    { ws = 2, mon = "DP-4" },
    { ws = 3, mon = "DP-4" },
    { ws = 4, mon = "DP-6", default = true },
    { ws = 5, mon = "DP-6" },
    { ws = 6, mon = "DP-6" },
    { ws = 7, mon = "DP-5", default = true },
    { ws = 8, mon = "DP-5" },
    { ws = 9, mon = "DP-5" },
  }
  for _, p in ipairs(pin) do
    hl.workspace_rule({ workspace = tostring(p.ws), monitor = p.mon, default = p.default })
  end
end
