-- binds.lua — every bind carries desc; the cheatsheet (SUPER+CTRL+K) renders
-- them from `hyprctl -j binds`, so descriptions ARE the documentation.

local mod = "SUPER"
local terminal = "kitty"
local browser = "google-chrome-stable"
local files = "nautilus --new-window"
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts"

local function bind(keys, action, opts)
  opts = opts or {}
  return hl.bind(keys, action, opts)
end

-- apps
bind(mod .. " + RETURN", hl.dsp.exec_cmd(terminal), { desc = "Terminal" })
bind(mod .. " + B",      hl.dsp.exec_cmd(browser), { desc = "Browser" })
bind(mod .. " + E",      hl.dsp.exec_cmd(files), { desc = "File manager" })
bind(mod .. " + C",      hl.dsp.exec_cmd("code"), { desc = "VS Code" })
bind(mod .. " + D",      hl.dsp.exec_cmd("discord"), { desc = "Discord" })
bind(mod .. " + CTRL + RETURN", hl.dsp.exec_cmd("rofi -show drun"), { desc = "App launcher" })
bind(mod .. " + V", hl.dsp.exec_cmd("sh -c 'cliphist list | rofi -dmenu -p clip | cliphist decode | wl-copy'"), { desc = "Clipboard history" })

-- window management
bind(mod .. " + Q", hl.dsp.window.close(), { desc = "Close window" })
bind(mod .. " + F", hl.dsp.window.fullscreen(), { desc = "Fullscreen" })
-- fullscreen arg shapes are opaque in the stubs; hyprctl fallback until verified
bind(mod .. " + M", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 1"), { desc = "Maximize" })
bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }), { desc = "Toggle floating" })
bind(mod .. " + SHIFT + T", function()
  local ws = hl.get_active_workspace()
  if not ws then return end
  for _, w in ipairs(hl.get_workspace_windows(ws)) do
    hl.dispatch(hl.dsp.window.float({ window = w, action = "toggle" }))
  end
end, { desc = "Toggle floating: all on workspace" })
bind(mod .. " + J", hl.dsp.layout("togglesplit"), { desc = "Toggle split" })
bind(mod .. " + K", hl.dsp.layout("swapsplit"), { desc = "Swap split" })
bind(mod .. " + G", hl.dsp.group.toggle(), { desc = "Toggle group" })

-- focus / move / resize
for dir, key in pairs({ left = "left", right = "right", up = "up", down = "down" }) do
  bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }), { desc = "Focus " .. dir })
  bind(mod .. " + ALT + " .. key, hl.dsp.window.swap({ direction = dir }), { desc = "Swap " .. dir })
end
bind(mod .. " + SHIFT + right", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 100 0"), { desc = "Grow width" })
bind(mod .. " + SHIFT + left",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive -100 0"), { desc = "Shrink width" })
bind(mod .. " + SHIFT + down",  hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 100"), { desc = "Grow height" })
bind(mod .. " + SHIFT + up",    hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -100"), { desc = "Shrink height" })
bind("ALT + Tab", hl.dsp.window.cycle_next(), { repeating = true, desc = "Cycle windows" })
bind("ALT + Tab", hl.dsp.window.bring_to_top(), { repeating = true })
bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- workspaces (pinned per monitor in workspaces.lua)
for i = 1, 9 do
  bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }), { desc = "Workspace " .. i })
  bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), { desc = "Move to workspace " .. i })
end
bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
bind(mod .. " + S",       hl.dsp.workspace.toggle_special("magic"), { desc = "Scratchpad" })
bind(mod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }), { desc = "To scratchpad" })

-- zoom — the old awk-pipeline dance, now three lines of actual language
local function zoom(delta)
  return function()
    local z = tonumber(hl.get_config("cursor:zoom_factor")) or 1
    hl.config({ cursor = { zoom_factor = math.max(1, z + delta) } })
  end
end
bind(mod .. " + SHIFT + mouse_down", zoom(0.5), { desc = "Zoom in" })
bind(mod .. " + SHIFT + mouse_up", zoom(-0.5), { desc = "Zoom out" })
bind(mod .. " + SHIFT + Z", function() hl.config({ cursor = { zoom_factor = 1 } }) end, { desc = "Zoom reset" })

-- screenshots / OCR (grim+slurp, grimblast retired)
bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | tee ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png | wl-copy'"), { desc = "Screenshot: area" })
bind(mod .. " + PRINT", hl.dsp.exec_cmd(scripts .. "/screenshot.sh"), { desc = "Screenshot menu" })
bind(mod .. " + ALT + A", hl.dsp.exec_cmd(scripts .. "/text-extractor.sh"), { desc = "OCR area to clipboard" })

-- media (wireplumber)
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

-- system
bind(mod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"), { desc = "Lock" })
bind(mod .. " + CTRL + Q", hl.dsp.exec_cmd("wlogout"), { desc = "Logout menu" })
bind(mod .. " + CTRL + R", hl.dsp.exec_cmd("hyprctl reload"), { desc = "Reload config" })
bind(mod .. " + CTRL + K", hl.dsp.exec_cmd(scripts .. "/cheatsheet.sh"), { desc = "Keybind cheatsheet" })
bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("waypaper --random"), { desc = "Random wallpaper" })
bind(mod .. " + CTRL + W", hl.dsp.exec_cmd("waypaper"), { desc = "Wallpaper picker" })
-- SUPER+ALT+G gamemode lives in gamemode.lua
-- waybar binds live until Quickshell replaces the bar layer
bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/waybar/launch.sh"), { desc = "Reload waybar" })
bind(mod .. " + CTRL + B", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/waybar/toggle.sh"), { desc = "Toggle waybar" })
