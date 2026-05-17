#!/usr/bin/env bash
# 基础环境模块
# 负责安装最基础的命令行工具、编译工具和排障工具。

install_base() {
  if is_done "base"; then
    log_info "基础环境已处理，跳过"
    return 0
  fi

  require_arch
  require_normal_user

  log_info "开始安装基础环境"
  pacman_update

  pacman_install \
    base-devel \
    git \
    curl \
    wget \
    unzip \
    tar \
    gzip \
    xz \
    jq \
    ripgrep \
    fd \
    fzf \
    pciutils \
    openssh \
    ca-certificates

  mark_done "base"
  log_info "基础环境安装完成"
}

ensure_base() {
  if ! is_done "base"; then
    install_base
  fi
}
