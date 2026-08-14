-- dank-greeter compositor config (Lua) — install: /etc/greetd/greeter-hypr.lua
-- Wired via -C in /etc/greetd/config.toml. The wrapper detects .lua, copies
-- it, and appends the greeter spawn hook ITSELF — do not add an hl.on spawn
-- here. The -C path does NOT inject DMS_RUN_GREETER, so set it ourselves.
-- Static 1.25: greeter runs as the `greeter` user and can't read jay's
-- ~/.config/hypr/scale-eDP-1 override; login-screen scale changes are rare.
hl.env("DMS_RUN_GREETER", "1")
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1.25 })
