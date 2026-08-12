-- hyprland.lua — entry point. Each module owns one concern; order matters only
-- where noted. The old ML4W variation forest is gone: one file per concern,
-- the file IS the choice.

require("env")        -- must precede autostart (children inherit env)
require("monitors")
require("workspaces")
require("input")
require("look")       -- exposes apply(); gamemode restores through it
require("rules")
require("binds")
require("gamemode")
require("autostart")
