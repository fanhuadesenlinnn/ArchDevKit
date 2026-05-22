#!/usr/bin/env bash
# 字体模块
# 安装中文字体、Emoji、Nerd Font，并可选安装 Monaco 字体。

install_fonts() {
  if is_done "fonts"; then
    log_info "字体环境已处理，跳过"
    return 0
  fi

  log_info "开始安装字体环境"

  local packages=()

  if [[ "${INSTALL_CN_FONTS:-0}" -eq 1 ]]; then
    packages+=(noto-fonts noto-fonts-cjk noto-fonts-emoji)
  fi

  if [[ "${INSTALL_NERD_FONTS:-0}" -eq 1 ]]; then
    packages+=(ttf-jetbrains-mono-nerd)
  fi

  if [[ "${#packages[@]}" -gt 0 ]]; then
    pacman_install "${packages[@]}"
  fi

  if [[ "${INSTALL_MONACO_FONT:-0}" -eq 1 ]]; then
    install_monaco_font
  fi

  log_info "刷新字体缓存"
  run_cmd fc-cache -f || true

  mark_done "fonts"
  log_info "字体环境安装完成"
}

install_monaco_font() {
  log_warn "Monaco 字体来源为第三方 HTTP 地址，不建议在未确认来源时安装"
  if ! confirm_yes "是否继续安装 Monaco 字体？"; then
    log_warn "已跳过 Monaco 字体安装"
    return 0
  fi

  ensure_curl_command

  local tmp_file
  tmp_file="$(mktemp)"

  log_info "下载 Monaco 字体：${MONACO_FONT_URL}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ curl -fL ${MONACO_FONT_URL} -o ${tmp_file}"
    rm -f "${tmp_file}"
    return 0
  fi

  curl -fL "${MONACO_FONT_URL}" -o "${tmp_file}"
  run_sudo mkdir -p "${MONACO_FONT_DIR}"
  run_sudo install -m 0644 "${tmp_file}" "${MONACO_FONT_DIR}/Monaco_Linux.ttf"
  rm -f "${tmp_file}"
}

ensure_fonts() {
  if ! is_done "fonts"; then
    install_fonts
  fi
}
