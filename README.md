# dotfiles

Hyprland desktop with a Quickshell bar that recolors itself from the wallpaper (matugen).
Made for a fresh **EndeavourOS** install.

## Install

1. Install EndeavourOS and pick **No Desktop** at the desktop step. Keep the other defaults.
2. Reboot and log in on the black screen with your user name and password.
3. Connect to the internet. A cable just works; for Wi-Fi run `nmtui`.
4. Run:

   ```bash
   git clone https://github.com/Bananonymous/dotfiles ~/dotfiles
   cd ~/dotfiles && ./install.sh
   ```

   It asks four yes/no questions (gaming, browser + Discord, files & media, dev tools),
   then installs everything without asking again. Type your password when sudo asks.
5. Reboot. Log in on the black screen and Hyprland starts.

NVIDIA, AMD and Intel graphics are found on their own.

## Keys

`Super` is the Windows key.

| Key | What it does |
|---|---|
| Super + Enter | Terminal (kitty) |
| Super + D | App launcher (rofi) |
| Super + C | Close window |
| Super + F | Fullscreen |
| Super + Space | Float / tile window |
| Super + J | Change split direction |
| Super + arrows | Move focus |
| Super + 1…0 | Go to workspace |
| Super + Shift + 1…0 | Move window to workspace |
| Super + mouse drag | Left: move window, right: resize |
| Super + Shift + S | Screenshot of an area (copied) |
| Super + Shift + D | File manager (Dolphin) |
| Super + X | Lock screen |
| Super + A | Clock & calendar panel |
| Super + Alt + B | Hide / show bar |

## Make it yours

- **Wallpapers**: put images in `~/Pictures/wallpapers`. A new one every 10 minutes, and the bar,
  borders, terminal, launcher and lock screen take its colors. The wallpaper button in the bar skips.
- **Calendar**: in Google Calendar, Settings, your calendar, copy the *Secret address in iCal format*
  and paste it in `~/.config/quickshell/calendar.url` (one per line). Keep that file private.
- **Screens**: automatic. To place them by hand, edit `~/.config/hypr/monitors.lua`
  (names from `hyprctl monitors`).
- **Keyboard**: Swiss French. Change `kb_layout` / `kb_variant` in `~/.config/hypr/input.lua`
  (for example `fr` and `""`, or `us` and `""`).
- **Prompt**: run `p10k configure` to restyle the terminal prompt.
- **Updates**: the bar's updates button updates everything (pacman + AUR).

## Get updates of this setup

```bash
cd ~/dotfiles && git pull && ./install.sh
```

Files it replaces are saved in `~/.dotfiles-backup/<date>/` first.

## What's inside

| Folder | Goes to |
|---|---|
| `config/` | `~/.config/` (hypr, quickshell, matugen, kitty, rofi, fastfetch, yazi, gtk, pipewire EQ…) |
| `home/` | `~/` (zsh, powerlevel10k) |
| `seed/` | starting colors, only copied if missing (matugen rewrites them) |
| `wallpapers/` | `~/Pictures/wallpapers/` |

The media and calendar popups in `config/quickshell/serp/` are ported from ilyamiro's
[Serpantinum](https://github.com/ilyamiro/nixos-configuration) shell (AGPL-3.0).
