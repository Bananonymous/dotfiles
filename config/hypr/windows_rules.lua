
hl.window_rule({ match = { class = "^(kitty)$" }, opacity = "0.90" })

hl.window_rule({ match = { class = "^(pavucontrol)$" }, opacity = "0.80 0.70" })

hl.window_rule({ match = { class = "^(vesktop)$" }, workspace = "3 silent" })
hl.window_rule({ match = { class = "^(steam)$" },   workspace = "2 silent" })
hl.window_rule({ match = { class = ".*" },           idle_inhibit = "fullscreen" })
