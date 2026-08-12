-- autostart.lua — session daemons. ML4W listeners/welcome/settings gone.
-- waybar stays until the Quickshell shell is live, then swap the line.

hl.on("hyprland.start", function()
  hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,ssh")
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
  hl.exec_cmd("swaync")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("wl-paste --watch cliphist store")
  hl.exec_cmd("waybar")  -- → replace with quickshell when the bar lands
  hl.exec_cmd("awww-daemon")           -- wallpaper daemon (waypaper backend)
  hl.exec_cmd("waypaper --restore")
  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
end)
