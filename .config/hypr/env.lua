-- env.lua — session environment. Loaded first: autostarted children inherit.

local env = {
  -- desktop identity
  { "XDG_CURRENT_DESKTOP", "Hyprland" },
  { "XDG_SESSION_TYPE", "wayland" },
  { "XDG_SESSION_DESKTOP", "Hyprland" },
  -- toolkits → wayland
  { "QT_QPA_PLATFORM", "wayland;xcb" },
  { "QT_QPA_PLATFORMTHEME", "qt6ct" },
  { "QT_WAYLAND_DISABLE_WINDOWDECORATION", "1" },
  { "QT_AUTO_SCREEN_SCALE_FACTOR", "1" },
  { "GDK_SCALE", "1" },
  { "GDK_BACKEND", "wayland,x11,*" },
  { "CLUTTER_BACKEND", "wayland" },
  { "MOZ_ENABLE_WAYLAND", "1" },
  { "OZONE_PLATFORM", "wayland" },
  { "ELECTRON_OZONE_PLATFORM_HINT", "wayland" },
  { "SDL_VIDEODRIVER", "wayland" },
  -- cursor
  { "XCURSOR_SIZE", "24" },
  { "HYPRCURSOR_SIZE", "24" },
}

-- nvidia (610.57 open modules) — archbox only; poison on Intel hosts
if require("hosts").is_archbox then
  table.insert(env, { "LIBVA_DRIVER_NAME", "nvidia" })
  table.insert(env, { "__GLX_VENDOR_LIBRARY_NAME", "nvidia" })
end

for _, e in ipairs(env) do
  hl.env(e[1], e[2])
end

hl.config({
  xwayland = { force_zero_scaling = true },
})
