# serp/

Popups ported from ilyamiro's **Serpantinum** shell
(https://github.com/ilyamiro/nixos-configuration), AGPL-3.0:

- `media/MusicPopup.qml`, `media/art_fetch.sh`
- `calendar/CalendarPopup.qml`
- `reusables/` (IconButton, ClickButton, MarqueeText, Visualizer)
- `singletons/audio/` (MprisController, Cava)
- `assets/shaders/`, `assets/languages/en.json`

`shims/` are small stand-ins (written for this shell) for the rest of his framework:
his theme names map onto our matugen `Colors`, his weather/EQ/text services onto ours.
Edits to his files are marked `// [port]`.
