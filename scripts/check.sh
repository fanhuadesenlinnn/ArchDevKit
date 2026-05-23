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
assert_file_contains() {
  local file="$1" pattern="$2" message="$3"
  if ! grep -Eq "${pattern}" "${file}"; then
    echo "${message}" >&2
    sed -n '1,120p' "${file}" >&2
    return 1
  fi
}

assert_file_not_contains() {
  local file="$1" pattern="$2" message="$3"
  if grep -Eq "${pattern}" "${file}"; then
    echo "${message}" >&2
    sed -n '1,120p' "${file}" >&2
    return 1
  fi
}

check_vmware_hyprland_contracts() (
  export SCRIPT_DIR="${ROOT_DIR}"

  local tmp_root conf vmware_dry_run intel_dry_run
  tmp_root="$(mktemp -d)"
  trap 'rm -rf "${tmp_root}"' EXIT

  export HOME="${tmp_root}/home"
  mkdir -p "${HOME}/.config/hypr"

  # shellcheck disable=SC1091
  source "${ROOT_DIR}/install_vars"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/common.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/modules/desktop_hyprland.sh"

  conf="${HOME}/.config/hypr/hyprland.conf"

  cp "${ROOT_DIR}/files/hyprdots/hypr/hyprland.conf" "${conf}"
  # shellcheck disable=SC2034
  GPU_TYPE=vmware
  # shellcheck disable=SC2034
  VM_HYPRLAND_DYNAMIC_RESIZE=1
  # shellcheck disable=SC2034
  VM_HYPRLAND_MONITOR_MODE=1920x1080@60
  configure_hyprland_virtualization_env
  assert_file_contains "${conf}" '^monitor=,preferred,auto,1$' \
    "VMware 默认应保持动态 monitor，不能固定 fallback 分辨率。"
  assert_file_contains "${conf}" 'archdevkit-vmware-user' \
    "VMware 配置应启动 ArchDevKit Wayland 会话辅助脚本。"
  assert_file_not_contains "${conf}" 'monitor=,1920x1080@60,auto,1' \
    "VMware 默认动态分辨率不应写入固定 1080p fallback。"
  assert_file_not_contains "${conf}" '^exec-once = vmware-user-suid-wrapper$' \
    "VMware 不应直接写入旧的 vmware-user-suid-wrapper 启动项。"

  cp "${ROOT_DIR}/files/hyprdots/hypr/hyprland.conf" "${conf}"
  # shellcheck disable=SC2034
  VM_HYPRLAND_DYNAMIC_RESIZE=0
  # shellcheck disable=SC2034
  VM_HYPRLAND_MONITOR_MODE=1600x900@60
  configure_hyprland_virtualization_env
  assert_file_contains "${conf}" '^monitor=,1600x900@60,auto,1$' \
    "关闭动态分辨率时，应按配置写入固定 VM fallback 分辨率。"

  cp "${ROOT_DIR}/files/hyprdots/hypr/hyprland.conf" "${conf}"
  # shellcheck disable=SC2034
  GPU_TYPE=intel
  # shellcheck disable=SC2034
  VM_HYPRLAND_DYNAMIC_RESIZE=1
  configure_hyprland_virtualization_env
  assert_file_not_contains "${conf}" 'ArchDevKit VM integration' \
    "物理机 GPU 不应写入 VM integration block。"
  assert_file_not_contains "${conf}" 'archdevkit-vmware-user|spice-vdagent|VBoxClient-all' \
    "物理机 GPU 不应写入 guest agent 自启动项。"

  # shellcheck disable=SC2034
  DRY_RUN=1
  # shellcheck disable=SC2034
  GPU_TYPE=vmware
  vmware_dry_run="$(install_desktop_runtime_helpers)"
  grep -Fq 'archdevkit-terminal' <<<"${vmware_dry_run}"
  grep -Fq 'archdevkit-vmware-user' <<<"${vmware_dry_run}"

  # shellcheck disable=SC2034
  GPU_TYPE=intel
  intel_dry_run="$(install_desktop_runtime_helpers)"
  grep -Fq 'archdevkit-terminal' <<<"${intel_dry_run}"
  if grep -Fq 'archdevkit-vmware-user' <<<"${intel_dry_run}"; then
    echo "物理机 dry-run 不应写入 VMware 用户会话辅助脚本。" >&2
    return 1
  fi
)

check_bash_syntax
check_required_desktop_contracts
check_vmware_hyprland_contracts

echo "ArchDevKit check passed."
