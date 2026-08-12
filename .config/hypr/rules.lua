-- rules.lua — window + layer rules, 0.53+ match syntax.
-- ML4W app rules (welcome/settings/sidebar/calendar) are gone with the apps.

-- floating utility windows: one shape, many apps
local floaters = {
  { name = "pavucontrol",   class = ".*org.pulseaudio.pavucontrol.*", size = "700 600",  pin = true },
  { name = "waypaper",      class = ".*waypaper.*",                   size = "900 700",  pin = true },
  { name = "blueman",       class = "blueman-manager",                size = "800 600" },
  { name = "nwg-look",      class = "nwg-look",                       size = "700 600" },
  { name = "nwg-displays",  class = "nwg-displays",                   size = "900 600" },
  { name = "calculator",    class = "org.gnome.Calculator",           size = "700 600" },
  { name = "nm-editor",     class = "nm-connection-editor",           size = "800 700" },
  { name = "share-picker",  class = "hyprland-share-picker",          size = "600 400", pin = true },
}

for _, r in ipairs(floaters) do
  hl.window_rule({
    name = r.name,
    match = { class = r.class },
    float = true,
    center = true,
    pin = r.pin,
    size = r.size,
  })
end

hl.window_rule({
  name = "pip",
  match = { title = "^([Pp]icture[-%s]?[Ii]n[-%s]?[Pp]icture)(.*)$" },
  float = true,
  pin = true,
  center = true,
})

-- from the 0.56 reference config — both genuinely useful
hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

hl.window_rule({
  name = "fix-xwayland-drags",
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  no_focus = true,
})

-- swaync overlays keep the glass treatment
for _, ns in ipairs({ "swaync-control-center", "swaync-notification-window" }) do
  hl.layer_rule({
    name = "swaync-glass-" .. ns,
    match = { namespace = ns },
    blur = true,
    ignore_alpha = 0.5,
  })
end
