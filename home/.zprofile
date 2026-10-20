# ~/.zprofile
# Logging in on tty1 starts Hyprland through uwsm
if [[ $XDG_VTNR -eq 1 ]] && uwsm check may-start; then
    exec uwsm start -e -D Hyprland hyprland.desktop
fi
