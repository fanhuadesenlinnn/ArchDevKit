#!/usr/bin/env bash

set -euo pipefail

TARGET="${WALLPAPER_DIR:-$HOME/Pictures/Wallpaper/Catppuccin}"
CONFIG_PATH="$HOME/.config/hypr/hyprpaper.conf"

if [[ ! -d "$TARGET" ]]; then
  notify-send -t 4000 "Wallpaper" "Directory not found: $TARGET" || true
  exit 1
fi

WALLPAPER="$(
  find "$TARGET" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) |
    shuf -n 1
)"

if [[ -z "$WALLPAPER" ]]; then
  notify-send -t 4000 "Wallpaper" "No images found in $TARGET" || true
  exit 1
fi

WALLPAPER_NAME="$(basename "$WALLPAPER")"
gowall convert "$WALLPAPER" -t mocha
CAT_WALLPAPER="$HOME/Pictures/gowall/$WALLPAPER_NAME"

mkdir -p "$(dirname "$CONFIG_PATH")"
{
  echo "splash = false"
  echo "preload = $CAT_WALLPAPER"
  echo "wallpaper = , $CAT_WALLPAPER"
} >"$CONFIG_PATH"

pkill hyprpaper 2>/dev/null || true
hyprctl dispatch exec hyprpaper
notify-send -a "hyprpaper" "Wallpaper changed" -i "$CAT_WALLPAPER" || true
