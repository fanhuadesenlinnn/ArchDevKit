# Hyprdots Vendor Notes

- Source: https://github.com/fanhuadesenlinnn/hyprdots.git
- Commit: 0158219
- Imported for the ArchDevKit Hyprland desktop module.

This directory keeps only the desktop-related config modules used by
`modules/desktop_hyprland.sh`. Shell, Neovim, Git, screenshots, and other
unrelated dotfile areas stay out of the desktop module boundary.

Local adjustments:

- The upstream Hyprland config used an optional `scrolling` layout. ArchDevKit
  defaults it to `dwindle` so a stock Hyprland install can start without extra
  layout plugins.
- `waybar/scripts/toggle-brightness.sh` stores state under
  `${XDG_STATE_HOME:-$HOME/.local/state}` instead of `/etc/xdg`.
