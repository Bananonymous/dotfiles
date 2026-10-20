#!/usr/bin/env bash
# Roll the wallpaper now: wake random-wallpaper's sleep so it picks a new image
# (and runs matugen). Starts the loop if it isn't running.
loop=$(pgrep -f '^/bin/bash .*/hypr/scripts/random-wallpaper$' | head -1)
if [[ -n $loop ]]; then
    pkill -x sleep -P "$loop"
else
    setsid "$HOME/.config/hypr/scripts/random-wallpaper" >/dev/null 2>&1 &
fi
