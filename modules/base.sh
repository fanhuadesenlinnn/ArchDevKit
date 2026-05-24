#!/usr/bin/env bash
# 基础环境模块
# 负责安装最基础的命令行工具、编译工具和排障工具。

base_packages() {
  echo "base-devel git curl wget less unzip tar gzip xz jq rsync rclone net-tools iotop iftop nethogs ripgrep fd fzf bat eza tmux pciutils openssh ca-certificates"
}

install_base() {
  if is_done "base"; then
    log_info "基础环境已处理，跳过"
    return 0
  fi

  local packages
  read -r -a packages <<<"$(base_packages)"

  require_arch
  require_normal_user

  log_info "开始安装基础环境"
  pacman_update

  pacman_install "${packages[@]}"

  if ! ensure_aur_helper; then
    log_warn "未能自动准备 AUR 助手（paru/yay），后续将回退到 makepkg 安装 AUR 软件包"
  fi

  mark_done "base"
  log_info "基础环境安装完成"
}

ensure_base() {
  if ! is_done "base"; then
    install_base
  fi
}
