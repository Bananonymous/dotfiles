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
order=(gaming social media dev)
declare -A title=([gaming]="Gaming" [social]="Browser & chat" [media]="Files & media" [dev]="Dev tools")
declare -A members=(
    [gaming]="steam gamemode gamescope protontricks"
    [social]="vivaldi vesktop"
    [media]="dolphin ark vlc mpv swayimg yazi"
    [dev]="vscode github-cli node docker"
)
declare -A label=(
    [steam]="Steam"
    [gamemode]="gamemode: performance boost while a game runs"
    [gamescope]="gamescope: game window with upscaling and FPS limit"
    [protontricks]="protontricks: fixes for Windows games in Steam"
    [vivaldi]="Vivaldi: web browser, opens at login"
    [vesktop]="Vesktop: Discord app (screen share works), opens at login"
    [dolphin]="Dolphin: file manager"
    [ark]="Ark: open/make zip, rar, 7z archives"
    [vlc]="VLC: video and music player"
    [mpv]="mpv: lightweight video player"
    [swayimg]="swayimg: image viewer"
    [yazi]="yazi: file manager inside the terminal"
    [vscode]="VS Code: code editor"
    [github-cli]="GitHub CLI (gh)"
    [node]="Node.js tools: npm + pnpm"
    [docker]="Docker + docker-compose"
)

while true; do
    chosen=()
    say "Pick the apps you want on top of the desktop"
    for g in "${order[@]}"; do
        read -ra list <<<"${members[$g]}"
        names=""
        for app in "${list[@]}"; do names+="${label[$app]%%:*}, "; done
        printf '\n\e[1m%s\e[0m: %s\n' "${title[$g]}" "${names%, }"
        read -rp "$(printf '\e[1;36m  ? \e[0m[Y]es to all / [n]o / [c]hoose each: ')" a
        case ${a,,} in
            n*) ;;
            c*) for app in "${list[@]}"; do ask "  ${label[$app]}" && chosen+=("$app"); done ;;
            *)  chosen+=("${list[@]}") ;;
        esac
    done
    say "You picked:"
    if (( ${#chosen[@]} )); then
        for app in "${chosen[@]}"; do echo "    - ${label[$app]%%:*}"; done
    else
        echo "    nothing extra, just the desktop"
    fi
    ask "Install this? (n = choose again)" && break
done
has() { [[ " ${chosen[*]} " == *" $1 "* ]]; }

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

for app in "${chosen[@]}"; do case $app in
    steam)
        if (( multilib )); then
            pkgs+=(steam lib32-pipewire)
            (( nvidia )) && pkgs+=(lib32-nvidia-utils)
            (( amd ))    && pkgs+=(lib32-vulkan-radeon)
            (( intel ))  && pkgs+=(lib32-vulkan-intel)
        else
            warn "Steam needs the [multilib] repo: uncomment it in /etc/pacman.conf, then run this again."
        fi ;;
    gamemode)  pkgs+=(gamemode); (( multilib )) && pkgs+=(lib32-gamemode) ;;
    vesktop)   aur+=(vesktop-bin) ;;
    dolphin)   pkgs+=(dolphin kio-admin breeze ffmpegthumbs) ;;
    ark)       pkgs+=(ark breeze) ;;
    vlc)       pkgs+=(vlc vlc-plugin-ffmpeg) ;;
    vscode)    aur+=(visual-studio-code-bin) ;;
    node)      pkgs+=(npm pnpm) ;;
    docker)    pkgs+=(docker docker-compose) ;;
    *)         pkgs+=("$app") ;;   # gamescope protontricks vivaldi mpv swayimg yazi github-cli
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
if has docker; then
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
