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

  if [[ "${MONACO_AS_SYSTEM_FONT:-0}" -eq 1 ]]; then
    configure_monaco_system_font
  fi

  log_info "刷新字体缓存"
  run_cmd fc-cache -f || true

  mark_done "fonts"
  log_info "字体环境安装完成"
}

monaco_font_installed() {
  fc-match Monaco >/dev/null 2>&1 || return 1
  fc-match Monaco 2>/dev/null | grep -qi 'monaco'
}

install_monaco_font() {
  local local_path="${MONACO_FONT_LOCAL_PATH:-${SCRIPT_DIR}/files/fonts/Monaco_Linux.ttf}"
  local required="${MONACO_FONT_REQUIRED:-0}"
  local tmp_file=""

  if monaco_font_installed; then
    log_info "检测到系统已安装 Monaco 字体，跳过安装"
    return 0
  fi

  if [[ -n "${local_path}" && -f "${local_path}" ]]; then
    log_info "使用本地 Monaco 字体：${local_path}"
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      echo "+ install ${local_path} -> ${MONACO_FONT_DIR}/Monaco_Linux.ttf"
      return 0
    fi

    run_sudo mkdir -p "${MONACO_FONT_DIR}"
    run_sudo install -m 0644 "${local_path}" "${MONACO_FONT_DIR}/Monaco_Linux.ttf"
    return 0
  fi

  if [[ -z "${MONACO_FONT_URL:-}" ]]; then
    log_warn "未找到本地 Monaco 字体：${local_path}"
    log_warn "已跳过 Monaco 字体安装；如需安装，请把字体放到该路径，或设置 MONACO_FONT_URL 为可信来源"
    [[ "${required}" -eq 1 ]] && die "MONACO_FONT_REQUIRED=1，但 Monaco 字体不可用"
    return 0
  fi

  log_warn "Monaco 字体将从外部 URL 下载，请确认来源可信：${MONACO_FONT_URL}"
  if ! confirm_yes "是否继续下载 Monaco 字体？"; then
    log_warn "已跳过 Monaco 字体安装"
    [[ "${required}" -eq 1 ]] && die "MONACO_FONT_REQUIRED=1，但用户取消安装 Monaco 字体"
    return 0
  fi

  ensure_curl_command

  tmp_file="$(mktemp)"

  log_info "下载 Monaco 字体：${MONACO_FONT_URL}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ curl -fL ${MONACO_FONT_URL} -o ${tmp_file}"
    echo "+ install ${tmp_file} -> ${MONACO_FONT_DIR}/Monaco_Linux.ttf"
    rm -f "${tmp_file}"
    return 0
  fi

  if ! curl -fL "${MONACO_FONT_URL}" -o "${tmp_file}"; then
    rm -f "${tmp_file}"
    log_warn "Monaco 字体下载失败，已跳过；当前安装继续执行"
    [[ "${required}" -eq 1 ]] && die "MONACO_FONT_REQUIRED=1，但 Monaco 字体下载失败"
    return 0
  fi

  run_sudo mkdir -p "${MONACO_FONT_DIR}"
  run_sudo install -m 0644 "${tmp_file}" "${MONACO_FONT_DIR}/Monaco_Linux.ttf"
  rm -f "${tmp_file}"
}

configure_monaco_system_font() {
  log_info "配置 Monaco 为系统和桌面首选字体"

  configure_monaco_fontconfig
  configure_monaco_gtk_settings
  configure_monaco_xsettingsd
}

configure_monaco_fontconfig() {
  local fontconfig_dir="${HOME}/.config/fontconfig"
  local fontconfig_file="${fontconfig_dir}/fonts.conf"
  local system_font="${SYSTEM_FONT_FAMILY:-Monaco}"
  local monospace_font="${SYSTEM_MONOSPACE_FONT_FAMILY:-${system_font}}"
  local cjk_font="${SYSTEM_CJK_FONT_FAMILY:-Noto Sans CJK SC}"
  local emoji_font="${SYSTEM_EMOJI_FONT_FAMILY:-Noto Color Emoji}"

  log_info "写入 fontconfig 字体优先级：${fontconfig_file}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ mkdir -p ${fontconfig_dir}"
    echo "+ write ${fontconfig_file}"
    return 0
  fi

  mkdir -p "${fontconfig_dir}"
  cat > "${fontconfig_file}" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>${system_font}</family>
      <family>${cjk_font}</family>
      <family>${emoji_font}</family>
    </prefer>
  </alias>

  <alias>
    <family>serif</family>
    <prefer>
      <family>${system_font}</family>
      <family>${cjk_font}</family>
      <family>${emoji_font}</family>
    </prefer>
  </alias>

  <alias>
    <family>monospace</family>
    <prefer>
      <family>${monospace_font}</family>
      <family>${cjk_font}</family>
      <family>${emoji_font}</family>
    </prefer>
  </alias>
</fontconfig>
EOF
}

configure_monaco_gtk_settings() {
  local system_font="${SYSTEM_FONT_FAMILY:-Monaco}"
  local font_size="${SYSTEM_FONT_SIZE:-11}"
  local gtk_dir settings_file

  for gtk_dir in "${HOME}/.config/gtk-3.0" "${HOME}/.config/gtk-4.0"; do
    settings_file="${gtk_dir}/settings.ini"
    log_info "写入 GTK 字体配置：${settings_file}"

    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      echo "+ mkdir -p ${gtk_dir}"
      echo "+ set gtk-font-name=${system_font} ${font_size} in ${settings_file}"
      continue
    fi

    mkdir -p "${gtk_dir}"
    if [[ ! -f "${settings_file}" ]]; then
      cat > "${settings_file}" <<EOF
[Settings]
gtk-font-name=${system_font} ${font_size}
EOF
      continue
    fi

    if grep -q '^gtk-font-name=' "${settings_file}"; then
      sed -i "s/^gtk-font-name=.*/gtk-font-name=${system_font} ${font_size}/" "${settings_file}"
    else
      if ! grep -q '^\[Settings\]' "${settings_file}"; then
        sed -i '1i[Settings]' "${settings_file}"
      fi
      sed -i "/^\[Settings\]/a gtk-font-name=${system_font} ${font_size}" "${settings_file}"
    fi
  done
}

configure_monaco_xsettingsd() {
  local system_font="${SYSTEM_FONT_FAMILY:-Monaco}"
  local font_size="${SYSTEM_FONT_SIZE:-11}"
  local xsettings_dir="${HOME}/.config/xsettingsd"
  local xsettings_file="${xsettings_dir}/xsettingsd.conf"

  log_info "写入 xsettingsd 字体配置：${xsettings_file}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ mkdir -p ${xsettings_dir}"
    echo "+ write ${xsettings_file}"
    return 0
  fi

  mkdir -p "${xsettings_dir}"
  cat > "${xsettings_file}" <<EOF
Net/ThemeName "catppuccin-mocha-lavender-standard+default"
Gtk/FontName "${system_font} ${font_size}"
Gtk/CursorThemeName "Banana"
Gtk/CursorThemeSize 40
EOF
}

ensure_fonts() {
  if ! is_done "fonts"; then
    install_fonts
  fi
}
