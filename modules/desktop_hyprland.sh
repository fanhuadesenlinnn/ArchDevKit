#!/usr/bin/env bash
# Hyprland 桌面环境模块
# 负责安装 Wayland 桌面基础组件、中文输入法、状态栏、通知、截图和登录管理器。

install_desktop_hyprland() {
  if is_done "desktop_hyprland"; then
    log_info "Hyprland 桌面环境已处理，跳过"
    return 0
  fi

  ensure_base
  ensure_fonts

  log_info "开始安装 Hyprland 桌面环境"
  install_hyprland_packages
  install_browser_package
  install_gpu_packages_if_needed
  enable_desktop_services
  configure_fcitx5_env
  configure_rime_if_needed
  generate_hyprland_config
  enable_sddm_if_needed
  verify_hyprland

  mark_done "desktop_hyprland"
  log_info "Hyprland 桌面环境安装完成"
}

install_hyprland_packages() {
  pacman_install \
    networkmanager bluez bluez-utils \
    pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack \
    mesa vulkan-icd-loader \
    hyprland xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    qt5-wayland qt6-wayland \
    waybar wofi kitty thunar thunar-archive-plugin file-roller \
    mako hyprlock hypridle hyprpaper \
    grim slurp wl-clipboard brightnessctl playerctl pavucontrol \
    network-manager-applet blueman polkit-kde-agent \
    sddm

  install_input_method_packages
}

install_input_method_packages() {
  [[ "${ENABLE_FCITX5:-0}" -eq 1 ]] || {
    log_warn "当前配置未启用 Fcitx5，跳过输入法包安装"
    return 0
  }

  case "${INPUT_METHOD_ENGINE:-rime}" in
    rime)
      pacman_install fcitx5-im fcitx5-configtool fcitx5-rime rime-luna-pinyin
      ;;
    *)
      die "暂不支持的输入法引擎：${INPUT_METHOD_ENGINE}"
      ;;
  esac
}

install_browser_package() {
  local package="${BROWSER_PACKAGE:-google-chrome}"
  [[ -n "${package}" ]] || die "浏览器安装包为空"

  if pacman_package_installed "${package}"; then
    log_info "浏览器已安装：${package}"
    return 0
  fi

  if [[ "${package}" == "google-chrome" && "${INSTALL_ARCHLINUXCN:-0}" -eq 1 ]] && ! pacman_package_available "${package}"; then
    log_info "Google Chrome 不在当前 pacman 源中，先确保 archlinuxcn 源可用"
    ensure_archlinuxcn
  fi

  if pacman_package_available "${package}"; then
    pacman_install "${package}"
    return 0
  fi

  if [[ "${package}" == "google-chrome" ]]; then
    log_warn "当前 pacman 源未提供 google-chrome，改用 AUR 构建安装"
    install_aur_package "${package}"
    return 0
  fi

  die "当前 pacman 源未找到浏览器安装包：${package}"
}

install_gpu_packages_if_needed() {
  local gpu="${GPU_TYPE}"

  if [[ "${gpu}" == "auto" ]]; then
    if lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' | grep -qi 'nvidia'; then
      gpu="nvidia"
    elif lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' | grep -qi 'amd|ati'; then
      gpu="amd"
    elif lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' | grep -qi 'intel'; then
      gpu="intel"
    else
      gpu="none"
    fi
  fi

  log_info "检测到 GPU 类型：${gpu}"

  case "${gpu}" in
    nvidia)
      log_warn "NVIDIA Wayland 可能需要额外配置 nvidia_drm.modeset=1"
      pacman_install nvidia nvidia-utils nvidia-settings egl-wayland
      ;;
    amd)
      pacman_install vulkan-radeon libva-mesa-driver mesa-vdpau
      ;;
    intel)
      pacman_install vulkan-intel intel-media-driver
      ;;
    none)
      log_warn "未检测到明确 GPU 类型，跳过专用驱动包"
      ;;
    *)
      log_warn "未知 GPU 类型：${gpu}，跳过专用驱动包"
      ;;
  esac
}

enable_desktop_services() {
  log_info "启用桌面基础服务"
  run_sudo systemctl enable --now NetworkManager

  if [[ "${ENABLE_BLUETOOTH:-0}" -eq 1 ]]; then
    run_sudo systemctl enable --now bluetooth || log_warn "蓝牙服务启用失败，可稍后手动处理"
  fi
}

configure_fcitx5_env() {
  [[ "${ENABLE_FCITX5:-0}" -eq 1 ]] || return 0

  log_info "配置 Fcitx5 中文输入法环境变量"
  mkdir -p "${HOME}/.config/environment.d"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write ${HOME}/.config/environment.d/fcitx5.conf"
    return 0
  fi

  cat > "${HOME}/.config/environment.d/fcitx5.conf" <<'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
INPUT_METHOD=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland;xcb
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
GDK_BACKEND=wayland,x11
XCURSOR_SIZE=24
EOF
}

configure_rime_if_needed() {
  [[ "${ENABLE_FCITX5:-0}" -eq 1 ]] || return 0
  [[ "${INPUT_METHOD_ENGINE:-rime}" == "rime" ]] || return 0

  local rime_dir="${HOME}/.local/share/fcitx5/rime"
  local fcitx5_dir="${HOME}/.config/fcitx5"
  local schema="${RIME_SCHEMA:-luna_pinyin_simp}"

  log_info "配置 Fcitx5 默认输入法为 Rime：${schema}"
  mkdir -p "${rime_dir}" "${fcitx5_dir}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write ${rime_dir}/default.custom.yaml"
    echo "+ write ${fcitx5_dir}/profile"
    return 0
  fi

  backup_path "${rime_dir}/default.custom.yaml"
  backup_path "${fcitx5_dir}/profile"

  cat > "${rime_dir}/default.custom.yaml" <<EOF
patch:
  schema_list:
    - schema: ${schema}
  menu/page_size: 9
  ascii_composer/switch_key:
    Shift_L: commit_code
    Shift_R: inline_ascii
EOF

  cat > "${fcitx5_dir}/profile" <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=rime

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=rime
Layout=

[GroupOrder]
0=Default
EOF
}

render_hyprland_template() {
  local template="$1" target="$2" tmp_file
  local browser_app terminal_app file_manager app_launcher

  [[ -f "${template}" ]] || die "Hyprland 模板不存在：${template}"
  [[ -n "${target}" ]] || die "Hyprland 模板目标为空"

  browser_app="$(sed_escape_replacement "${BROWSER_APP:-google-chrome-stable}")"
  terminal_app="$(sed_escape_replacement "${TERMINAL_APP:-kitty}")"
  file_manager="$(sed_escape_replacement "${FILE_MANAGER:-thunar}")"
  app_launcher="$(sed_escape_replacement "${APP_LAUNCHER:-wofi}")"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ render ${template} -> ${target}"
    return 0
  fi

  mkdir -p "$(dirname "${target}")"
  tmp_file="$(mktemp)"
  sed \
    -e "s/__TERMINAL_APP__/${terminal_app}/g" \
    -e "s/__FILE_MANAGER__/${file_manager}/g" \
    -e "s/__APP_LAUNCHER__/${app_launcher}/g" \
    -e "s/__BROWSER_APP__/${browser_app}/g" \
    "${template}" > "${tmp_file}"

  backup_path "${target}"
  install -m 0644 "${tmp_file}" "${target}"
  rm -f "${tmp_file}"
}

install_hyprland_templates() {
  local template_dir="${SCRIPT_DIR}/files/hyprland"

  render_hyprland_template "${template_dir}/hyprland.conf.tpl" "${HOME}/.config/hypr/hyprland.conf"
  render_hyprland_template "${template_dir}/waybar.config.tpl" "${HOME}/.config/waybar/config"
  render_hyprland_template "${template_dir}/waybar.style.css.tpl" "${HOME}/.config/waybar/style.css"
  render_hyprland_template "${template_dir}/mako.config.tpl" "${HOME}/.config/mako/config"
  render_hyprland_template "${template_dir}/wofi.config.tpl" "${HOME}/.config/wofi/config"
  render_hyprland_template "${template_dir}/kitty.conf.tpl" "${HOME}/.config/kitty/kitty.conf"
}

generate_hyprland_config() {
  [[ "${HYPRLAND_CONFIG_MODE}" == "template" ]] || {
    log_warn "当前 Hyprland 配置模式为 ${HYPRLAND_CONFIG_MODE}，跳过模板生成"
    return 0
  }

  log_info "生成 Hyprland 默认配置"
  install_hyprland_templates
}

enable_sddm_if_needed() {
  [[ "${ENABLE_SDDM:-0}" -eq 1 ]] || {
    log_warn "当前配置未启用 SDDM"
    return 0
  }

  log_info "启用 SDDM 登录管理器"
  run_sudo systemctl enable sddm
  log_warn "SDDM 已设置为开机自启，重启后在登录界面选择 Hyprland"
}

verify_hyprland() {
  log_info "验证 Hyprland 关键命令"
  run_cmd Hyprland --version || true
  run_cmd waybar --version || true
  run_cmd "${BROWSER_APP:-google-chrome-stable}" --version || true
  run_cmd fcitx5 --version || true
}

ensure_desktop_hyprland() {
  if ! is_done "desktop_hyprland"; then
    install_desktop_hyprland
  fi
}
