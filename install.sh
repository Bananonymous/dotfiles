#!/usr/bin/env bash
# Installs this Hyprland + Quickshell desktop on a fresh EndeavourOS "No Desktop" install.
#   git clone <repo> ~/dotfiles && cd ~/dotfiles && ./install.sh
# Safe to run again (after a `git pull`): files it replaces are saved in ~/.dotfiles-backup/<date>/.
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
C=$HOME/.config
BACKUP=$HOME/.dotfiles-backup/$(date +%Y-%m-%d_%H-%M-%S)

say()  { printf '\n\e[1;35m==>\e[0m \e[1m%s\e[0m\n' "$*"; }
warn() { printf '\e[1;33m  ! \e[0m%s\n' "$*"; }
ask()  { local a; read -rp "$(printf '\e[1;36m  ? \e[0m%s [Y/n] ' "$1")" a; [[ ${a,,} != n* ]]; }

[[ $EUID -ne 0 ]] || { echo "Run this as your normal user, not root (it asks for sudo itself)."; exit 1; }
command -v pacman >/dev/null || { echo "This is for Arch / EndeavourOS only."; exit 1; }

# --- questions first, so the rest runs unattended ------------------------------------
say "What do you want on top of the desktop?"
groups=()
ask "Gaming: Steam, gamemode, gamescope, protontricks"            && groups+=(gaming)
ask "Vivaldi (browser) + Vesktop (Discord), started at login"     && groups+=(social)
ask "Files & media: Dolphin, Ark, VLC, mpv, image viewer, yazi"   && groups+=(media)
ask "Dev tools: VS Code, GitHub CLI, Node (npm/pnpm), Docker"     && groups+=(dev)

# --- packages ------------------------------------------------------------------------
pkgs=(
    # Hyprland and its helpers
    hyprland hyprlock hypridle hyprsunset hyprpolkitagent hyprshot uwsm
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xorg-xwayland qt6-wayland qt5-wayland
    # Bar, theming from the wallpaper, launcher, terminal
    quickshell matugen awww cava rofi kitty jq ffmpeg imagemagick python
    # Look
    adwaita-fonts ttf-hack-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk breeze-icons gnome-themes-extra
    # Things the bar talks to
    networkmanager bluez bluez-utils upower playerctl libnotify brightnessctl pacman-contrib
    pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber pavucontrol
    # Everyday tools
    zsh fastfetch git curl rsync wl-clipboard gnome-keyring xdg-user-dirs xdg-utils unzip 7zip
)
aur=(qogir-cursor-theme)

# power-profiles-daemon conflicts with tlp / auto-cpufreq; keep theirs if present
pacman -Qq tlp auto-cpufreq &>/dev/null || pkgs+=(power-profiles-daemon)

# Graphics
gpu=$(lspci -nn | grep -Ei 'vga|3d|display' || true)
nvidia=0 amd=0 intel=0
grep -qi nvidia <<<"$gpu"            && nvidia=1
grep -qE 'AMD|ATI|Radeon' <<<"$gpu"  && amd=1      # case-sensitive: "ati" is in "Corporation"
grep -q Intel <<<"$gpu"              && intel=1
(( nvidia )) && pkgs+=(nvidia-utils libva-nvidia-driver egl-wayland)
(( amd ))    && pkgs+=(mesa vulkan-radeon)
(( intel ))  && pkgs+=(mesa vulkan-intel intel-media-driver)

multilib=0
grep -q '^\[multilib\]' /etc/pacman.conf && multilib=1

for g in "${groups[@]}"; do case $g in
    gaming)
        pkgs+=(gamemode gamescope protontricks)
        if (( multilib )); then
            pkgs+=(steam lib32-gamemode lib32-pipewire)
            (( nvidia )) && pkgs+=(lib32-nvidia-utils)
            (( amd ))    && pkgs+=(lib32-vulkan-radeon)
            (( intel ))  && pkgs+=(lib32-vulkan-intel)
        else
            warn "Steam needs the [multilib] repo: uncomment it in /etc/pacman.conf, then run this again."
        fi ;;
    social) pkgs+=(vivaldi); aur+=(vesktop-bin) ;;
    media)  pkgs+=(dolphin ark kio-admin breeze ffmpegthumbs vlc vlc-plugin-ffmpeg mpv swayimg yazi) ;;
    dev)    pkgs+=(github-cli npm pnpm docker docker-compose); aur+=(visual-studio-code-bin) ;;
esac; done

say "Installing packages (asks for your password)"
sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"

if ! command -v yay >/dev/null; then
    say "Installing yay (for AUR packages)"
    sudo pacman -S --needed --noconfirm yay || {
        tmp=$(mktemp -d); git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm); rm -rf "$tmp"
    }
fi
say "Installing AUR packages: ${aur[*]}"
yay -S --needed --noconfirm --sudoloop "${aur[@]}" || warn "Some AUR packages failed; the desktop still works without them."

# NVIDIA kernel driver: EndeavourOS usually installs it already when it sees the card
if (( nvidia )) && ! modinfo nvidia &>/dev/null; then
    warn "No NVIDIA kernel driver found. After this script, run:  nvidia-inst   then reboot."
    sudo pacman -S --needed --noconfirm nvidia-inst || true
fi

# --- shell ---------------------------------------------------------------------------
say "zsh + oh-my-zsh + powerlevel10k"
[[ -d $HOME/.oh-my-zsh ]] || git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
ZC=$HOME/.oh-my-zsh/custom
[[ -d $ZC/plugins/zsh-autosuggestions ]] || git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$ZC/plugins/zsh-autosuggestions"
[[ -d $ZC/themes/powerlevel10k ]]       || git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "$ZC/themes/powerlevel10k"
[[ $(getent passwd "$USER" | cut -d: -f7) == */zsh ]] || sudo chsh -s /usr/bin/zsh "$USER"

# --- files ---------------------------------------------------------------------------
say "Copying config files (old ones go to $BACKUP)"
xdg-user-dirs-update
mkdir -p "$C" "$BACKUP/.config" "$HOME/Pictures/wallpapers"
rsync -a --backup --backup-dir="$BACKUP/.config" "$REPO/config/" "$C/"
rsync -a --backup --backup-dir="$BACKUP" "$REPO/home/" "$HOME/"
# Colors matugen generates: only a starting palette, never overwrite the current one
rsync -a --ignore-existing "$REPO/seed/" "$C/"
rsync -a --ignore-existing "$REPO/wallpapers/" "$HOME/Pictures/wallpapers/"
chmod +x "$C/hypr/scripts/"* "$C/quickshell/scripts/"*.sh "$C/quickshell/scripts/"*.py
find "$BACKUP" -type d -empty -delete 2>/dev/null || true
[[ -d $BACKUP ]] || BACKUP="(nothing to back up)"

# Calendar in the clock panel: one secret iCal URL per line (Google Calendar >
# Settings > your calendar > "Secret address in iCal format")
touch "$C/quickshell/calendar.url"; chmod 600 "$C/quickshell/calendar.url"

# --- services ------------------------------------------------------------------------
say "Enabling services"
sudo systemctl enable --now NetworkManager bluetooth
pacman -Qq power-profiles-daemon &>/dev/null && sudo systemctl enable --now power-profiles-daemon
systemctl --user daemon-reload
systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service
systemctl --user enable filter-chain.service                                  # bar's equalizer
systemctl --user enable hypridle.service hyprpolkitagent.service hyprsunset.service
if [[ " ${groups[*]} " == *" dev "* ]]; then
    sudo systemctl enable --now docker
    getent group docker | grep -qw "$USER" || sudo usermod -aG docker "$USER"
fi

# --- done ----------------------------------------------------------------------------
say "Done!"
cat <<EOF

  Reboot, log in on the black screen (tty1) and Hyprland starts by itself.

  Keys (Super = Windows key):
    Super+Enter  terminal          Super+D        app launcher
    Super+C      close window      Super+F        fullscreen
    Super+Space  float window      Super+1..0     workspaces (Shift: move window)
    Super+Shift+S screenshot       Super+X        lock
    Super+A      clock/calendar    Super+Alt+B    hide/show bar

  Wallpapers: put images in ~/Pictures/wallpapers. They change every 10 min and
  the whole desktop recolors itself from them (wallpaper button in the bar skips).

  Calendar: paste your secret iCal URL in ~/.config/quickshell/calendar.url
  Screens: everything is automatic; to arrange them see ~/.config/hypr/monitors.lua
  Old files: $BACKUP
EOF
(( nvidia )) && ! modinfo nvidia &>/dev/null && warn "Remember: run  nvidia-inst  before rebooting."
true
