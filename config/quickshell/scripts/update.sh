#!/usr/bin/env bash
# Run by the bar's updates chip in a terminal: one sudo prompt, then official packages
# (pacman) and AUR packages (yay) updated without questions. The bar re-counts when done.
say()  { printf '\n\e[1;35m==>\e[0m \e[1m%s\e[0m\n' "$*"; }
fail() { printf '\n\e[1;31m==>\e[0m \e[1m%s\e[0m\n' "$*"; }

say "System update"
sudo -v || { fail "No sudo, nothing updated."; read -rp 'Press Enter to close'; exit 1; }

# Keep the one password valid for the whole run (long AUR builds included)
while sudo -n -v 2>/dev/null; do sleep 50; done &
keepalive=$!

# Some networks (eduroam) can't reach Arch's servers over IPv6: the TLS handshake dies,
# and yay then fails instead of falling back to IPv4. If the AUR doesn't answer over IPv6,
# pin it to IPv4 in /etc/hosts for this run only.
TAG="# qs-update: temporary IPv4 pin"
unpin() { sudo sed -i "/$TAG/d" /etc/hosts; }
cleanup() { kill "$keepalive" 2>/dev/null; unpin; }
trap cleanup EXIT
trap 'exit 130' INT TERM
unpin   # leftover from an interrupted run

if ! curl -6 -sf -o /dev/null --max-time 6 'https://aur.archlinux.org/rpc?v=5&type=info'; then
    ip=$(getent ahostsv4 aur.archlinux.org | awk 'NR == 1 { print $1 }')
    if [[ -n $ip ]]; then
        echo "$ip aur.archlinux.org $TAG" | sudo tee -a /etc/hosts >/dev/null
        echo "AUR unreachable over IPv6 here, using IPv4 ($ip) for this update."
    fi
fi

# Official packages first, so an AUR problem can't hold them back
say "Official packages"
sudo pacman -Syu --noconfirm
repo=$?

say "AUR packages"
yay -Sua --noconfirm --sudoloop
aur=$?

qs ipc call updates refresh >/dev/null 2>&1
if (( repo == 0 && aur == 0 )); then
    say "Everything is up to date"
else
    (( repo == 0 )) && say "Official packages: up to date" || fail "Official packages: failed (exit $repo), see above"
    (( aur == 0 ))  && say "AUR packages: up to date"      || fail "AUR packages: failed (exit $aur), see above"
fi
read -rp 'Press Enter to close'
