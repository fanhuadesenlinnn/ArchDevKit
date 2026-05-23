#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check_bash_syntax() {
  local file
  while IFS= read -r file; do
    bash -n "${file}"
  done < <(
    find "${ROOT_DIR}" \
      -path "${ROOT_DIR}/.git" -prune -o \
      -type f \( -name "*.sh" -o -name "install_vars" -o -name "switch_waybar" -o -name "weekly_commits" \) \
      -print | sort
  )
}

check_required_desktop_contracts() {
  grep -R --line-number --fixed-strings 'kitty' "${ROOT_DIR}/files/hyprland" "${ROOT_DIR}/files/hyprdots" && {
    echo "检测到桌面配置仍引用 kitty，请保持 Alacritty/foot 终端策略一致。" >&2
    return 1
  }

  grep -R --line-number --fixed-strings 'ttf-font-awesome' "${ROOT_DIR}/install_vars" "${ROOT_DIR}/modules" "${ROOT_DIR}/files/hyprland" "${ROOT_DIR}/files/hyprdots" && {
    echo "检测到安装路径仍引用 ttf-font-awesome，请使用 woff2-font-awesome 兼容 Font Awesome 7。" >&2
    return 1
  }
}

check_bash_syntax
check_required_desktop_contracts

echo "ArchDevKit check passed."
