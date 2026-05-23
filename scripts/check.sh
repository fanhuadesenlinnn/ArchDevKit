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
      -type f \( -name "*.sh" -o -name "install_vars" \) \
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

  return 0
}

check_rime_defaults() {
  grep -Eq '^INSTALL_RIME_CONFIG=1$' "${ROOT_DIR}/install_vars" || {
    echo "Rime 默认应启用个人配置仓库：INSTALL_RIME_CONFIG=1。" >&2
    return 1
  }

  grep -Eq '^RIME_CONFIG_REPO="https://github.com/fanhuadesenlinnn/rime-config\.git"$' "${ROOT_DIR}/install_vars" || {
    echo "Rime 默认配置仓库应指向 fanhuadesenlinnn/rime-config.git。" >&2
    return 1
  }
}

check_bash_syntax
check_required_desktop_contracts
check_rime_defaults

echo "ArchDevKit check passed."
