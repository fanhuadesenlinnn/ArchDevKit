#!/usr/bin/env bash

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
STATE_FILE="${STATE_DIR}/old-brightness.txt"

mkdir -p "$STATE_DIR"

CURRENT_BRIGHTNESS="$(brightnessctl -m | awk -F, '{print $4}' | tr -d %)"
OLD_BRIGHTNESS="50"
[[ -f "$STATE_FILE" ]] && OLD_BRIGHTNESS="$(cat "$STATE_FILE")"

if [ "$CURRENT_BRIGHTNESS" -ne 1 ] ; then
	echo "$CURRENT_BRIGHTNESS" > "$STATE_FILE"
	brightnessctl set 1%;
else
	brightnessctl set "$OLD_BRIGHTNESS"%;
fi
