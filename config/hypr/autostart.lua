-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function ()
  -- Signals readiness to uwsm so graphical-session.target activates (no-op outside uwsm)
  hl.exec_cmd("uwsm finalize")
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland HYPRLAND_INSTANCE_SIGNATURE")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
  hl.exec_cmd("kbuildsycoca6")
  hl.exec_cmd("qs -d")
  -- Apps wait for the Quickshell notification daemon, else they use their own popup windows.
  -- Each one starts only if it is installed.
  hl.exec_cmd("~/.config/hypr/scripts/after-shell sh -c '"
    .. "command -v vivaldi >/dev/null && env GTK_USE_PORTAL=0 vivaldi & "
    .. "command -v vesktop >/dev/null && vesktop & "
    .. "command -v steam >/dev/null && steam -silent'")
  hl.exec_cmd("~/.config/hypr/scripts/random-wallpaper")
end)
