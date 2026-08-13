-- hosts.lua — one dotfiles branch, several machines. Everything host-specific
-- keys off /etc/hostname through M.name; add a machine by adding its table.

local M = {}

local f = io.open("/etc/hostname", "r")
M.name = (f and f:read("*l")) or "unknown"
if f then f:close() end

M.is_archbox = (M.name == "taichi")
M.is_laptop  = (M.name == "ThinkPadX1C")

return M
