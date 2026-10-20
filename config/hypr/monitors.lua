-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Every screen at its preferred resolution, placed automatically.
-- For a fixed layout, list each output (see `hyprctl monitors`), e.g.:
-- hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = "1" })
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
