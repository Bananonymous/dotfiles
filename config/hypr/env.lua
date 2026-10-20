-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Qogir-cursors")
hl.env("HYPRCURSOR_THEME", "Qogir-cursors")

-- Qt apps follow the GTK dark theme; KDE apps (Dolphin) additionally read ~/.config/kdeglobals (Breeze Dark)
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("GTK_THEME", "Adwaita:dark")

-- NVIDIA Wayland requirements, only when the NVIDIA driver is loaded
local nvidia = io.open("/proc/driver/nvidia/version")
if nvidia then
    nvidia:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end
