#!/usr/bin/env bash
# Hyprland 桌面环境模块
# 负责安装 Hyprland 桌面包、按 ArchDevKit 规则安装 hyprdots 配置，并启用桌面服务。

install_desktop_hyprland() {
  if is_done "desktop_hyprland"; then
    log_info "Hyprland 桌面环境已处理，跳过"
    return 0
  fi

  if desktop_needs_fonts; then
    ensure_fonts
  else
    log_info "当前 Hyprland 配置不依赖字体模块，跳过字体安装"
  fi

  log_info "开始安装 Hyprland 桌面环境"
  install_hyprland_packages
  install_browser_package
  install_hyprdots_optional_packages
  install_gpu_packages_if_needed
  install_desktop_runtime_helpers
  enable_desktop_services
  enable_desktop_audio_services
  configure_fcitx5_env
  configure_rime_if_needed
  generate_hyprland_config
  configure_hyprland_gpu_env
  configure_hyprland_virtualization_env
  enable_sddm_if_needed
  verify_hyprland

  mark_done "desktop_hyprland"
  log_info "Hyprland 桌面环境安装完成"
}

hyprdots_mode_enabled() {
  [[ "${HYPRLAND_CONFIG_MODE:-hyprdots}" == "hyprdots" ]]
}

validate_hyprland_config_mode() {
  case "${HYPRLAND_CONFIG_MODE:-hyprdots}" in
    hyprdots|template|skip) return 0 ;;
    *) die "未知 Hyprland 配置模式：${HYPRLAND_CONFIG_MODE}，可选值：hyprdots / template / skip" ;;
  esac
}

desktop_needs_fonts() {
  case "${HYPRLAND_CONFIG_MODE:-hyprdots}" in
    hyprdots|template) return 0 ;;
    *) [[ "${ENABLE_FCITX5:-0}" -eq 1 ]] ;;
  esac
}

desktop_needs_rime_repo() {
  [[ "${ENABLE_FCITX5:-0}" -eq 1 && "${INPUT_METHOD_ENGINE:-rime}" == "rime" && "${INSTALL_RIME_CONFIG:-1}" -eq 1 ]]
}

desktop_needs_archlinuxcn() {
  package_needs_archlinuxcn_repo "${BROWSER_PACKAGE:-google-chrome}" && return 0

  if hyprdots_mode_enabled && [[ "${INSTALL_HYPRDOTS_OBSIDIAN:-0}" -eq 1 ]]; then
    package_needs_archlinuxcn_repo obsidian && return 0
  fi

  return 1
}

detect_gpu_type() {
  local pci_info virt_type
  pci_info="$(lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' || true)"
  virt_type="$(detect_virtualization_type)"

  if grep -qi 'nvidia' <<<"${pci_info}"; then
    printf '%s\n' "nvidia"
  elif grep -qi 'vmware' <<<"${pci_info}"; then
    printf '%s\n' "vmware"
  elif [[ "${virt_type}" == "oracle" || "${virt_type}" == "virtualbox" ]] || grep -qi 'virtualbox' <<<"${pci_info}"; then
    printf '%s\n' "virtualbox"
  elif grep -qi 'virtio' <<<"${pci_info}"; then
    printf '%s\n' "virtio"
  elif grep -qi 'qxl' <<<"${pci_info}"; then
    printf '%s\n' "qxl"
  elif grep -qi 'amd|ati' <<<"${pci_info}"; then
    printf '%s\n' "amd"
  elif grep -qi 'intel' <<<"${pci_info}"; then
    printf '%s\n' "intel"
  else
    printf '%s\n' "none"
  fi
}

detect_virtualization_type() {
  local virt_type="none"

  if command -v systemd-detect-virt >/dev/null 2>&1; then
    virt_type="$(systemd-detect-virt 2>/dev/null || true)"
  fi

  [[ -n "${virt_type}" ]] || virt_type="none"
  printf '%s\n' "${virt_type}"
}

effective_gpu_type() {
  if [[ "${GPU_TYPE:-auto}" == "auto" ]]; then
    detect_gpu_type
  else
    printf '%s\n' "${GPU_TYPE}"
  fi
}

desktop_font_awesome_package() {
  if pacman_package_installed woff2-font-awesome || pacman_package_available woff2-font-awesome; then
    printf '%s\n' "woff2-font-awesome"
    return 0
  fi

  if pacman_package_installed ttf-font-awesome || pacman_package_available ttf-font-awesome; then
    log_warn "检测到旧版 Font Awesome 包名可用，将临时使用 ttf-font-awesome；建议后续迁移到 woff2-font-awesome"
    printf '%s\n' "ttf-font-awesome"
    return 0
  fi

  printf '%s\n' "woff2-font-awesome"
}

desktop_hyprdots_packages() {
  local font_awesome_package
  font_awesome_package="$(desktop_font_awesome_package)"

  local packages=(
    acpi
    bat
    brightnessctl
    btop
    cava
    cliphist
    desktop-file-utils
    dunst
    eza
    fastfetch
    fd
    fzf
    grim
    hypridle
    hyprland
    hyprlock
    hyprpaper
    hyprpicker
    hyprpolkitagent
    jq
    kitty
    foot
    libnotify
    mesa
    networkmanager
    pamixer
    pavucontrol
    pipewire
    pipewire-alsa
    pipewire-jack
    pipewire-pulse
    playerctl
    polkit
    qt5-wayland
    qt6-wayland
    rofi
    rtkit
    slurp
    "${font_awesome_package}"
    ttf-iosevka-nerd
    unzip
    waybar
    wget
    wireplumber
    wl-clipboard
    wtype
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland
    xdg-utils
    xorg-xwayland
    yazi
  )

  if [[ "${ENABLE_BLUETOOTH:-0}" -eq 1 ]]; then
    packages+=(bluez bluez-utils blueman)
  fi

  if [[ "${ENABLE_SDDM:-0}" -eq 1 ]]; then
    packages+=(sddm)
  fi

  printf '%s\n' "${packages[@]}"
}

desktop_template_packages() {
  local packages=(
    networkmanager
    pipewire
    wireplumber
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    mesa
    vulkan-icd-loader
    hyprland
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    qt5-wayland
    qt6-wayland
    waybar
    wofi
    kitty
    foot
    thunar
    thunar-archive-plugin
    file-roller
    mako
    hyprlock
    hypridle
    hyprpaper
    grim
    slurp
    wl-clipboard
    brightnessctl
    playerctl
    pavucontrol
    network-manager-applet
    polkit-kde-agent
  )

  if [[ "${ENABLE_BLUETOOTH:-0}" -eq 1 ]]; then
    packages+=(bluez bluez-utils blueman)
  fi

  if [[ "${ENABLE_SDDM:-0}" -eq 1 ]]; then
    packages+=(sddm)
  fi

  printf '%s\n' "${packages[@]}"
}

install_required_pacman_package() {
  local package="$1"
  install_package_or_aur "${package}"
}

install_hyprland_packages() {
  local package packages=()

  case "${HYPRLAND_CONFIG_MODE:-hyprdots}" in
    hyprdots)
      while IFS= read -r package; do
        [[ -n "${package}" ]] && packages+=("${package}")
      done < <(desktop_hyprdots_packages)
      ;;
    template|skip)
      while IFS= read -r package; do
        [[ -n "${package}" ]] && packages+=("${package}")
      done < <(desktop_template_packages)
      ;;
    *)
      die "未知 Hyprland 配置模式：${HYPRLAND_CONFIG_MODE}"
      ;;
  esac

  log_info "安装 Hyprland 桌面软件包"
  for package in "${packages[@]}"; do
    install_required_pacman_package "${package}"
  done

  install_input_method_packages
}

install_input_method_packages() {
  [[ "${ENABLE_FCITX5:-0}" -eq 1 ]] || {
    log_warn "当前配置未启用 Fcitx5，跳过输入法包安装"
    return 0
  }

  case "${INPUT_METHOD_ENGINE:-rime}" in
    rime)
      for package in fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-rime rime-luna-pinyin; do
        install_required_pacman_package "${package}"
      done
      ;;
    *)
      die "暂不支持的输入法引擎：${INPUT_METHOD_ENGINE}"
      ;;
  esac
}

install_browser_package() {
  local package="${BROWSER_PACKAGE:-google-chrome}"
  [[ -n "${package}" ]] || die "浏览器安装包为空"

  install_package_or_aur "${package}"
}

install_hyprdots_optional_packages() {
  hyprdots_mode_enabled || return 0

  if [[ "${INSTALL_HYPRDOTS_OBSIDIAN:-0}" -eq 1 ]]; then
    log_info "安装 hyprdots 可选应用：obsidian"
    install_package_or_aur obsidian
  else
    log_info "当前配置未启用 hyprdots 可选应用：obsidian"
  fi
}

install_gpu_packages_if_needed() {
  local gpu virt_type
  gpu="$(effective_gpu_type)"
  virt_type="$(detect_virtualization_type)"

  log_info "检测到 GPU 类型：${gpu}，虚拟化环境：${virt_type}"

  case "${gpu}" in
    nvidia)
      log_warn "NVIDIA Wayland 可能需要额外配置 nvidia_drm.modeset=1"
      pacman_install nvidia nvidia-utils nvidia-settings egl-wayland vulkan-icd-loader
      ;;
    amd)
      pacman_install vulkan-radeon libva-mesa-driver mesa-vdpau vulkan-icd-loader
      ;;
    intel)
      pacman_install vulkan-intel intel-media-driver vulkan-icd-loader
      ;;
    vmware)
      log_warn "检测到 VMware 虚拟显卡；安装 VMware Tools、Mesa 检测工具和软件渲染兜底"
      pacman_install open-vm-tools vulkan-swrast mesa-utils
      ;;
    virtio|qxl)
      log_warn "检测到虚拟显卡 ${gpu}；安装 QEMU/SPICE guest agent、Mesa 检测工具和软件渲染兜底"
      pacman_install qemu-guest-agent spice-vdagent vulkan-swrast mesa-utils
      ;;
    virtualbox)
      log_warn "检测到 VirtualBox 虚拟显卡；安装 VirtualBox guest utils、Mesa 检测工具和软件渲染兜底"
      pacman_install virtualbox-guest-utils vulkan-swrast mesa-utils
      ;;
    none)
      log_warn "未检测到明确 GPU 类型，跳过专用驱动包"
      ;;
    *)
      log_warn "未知 GPU 类型：${gpu}，跳过专用驱动包"
      ;;
  esac
}

install_desktop_runtime_helpers() {
  local helper="${HOME}/.local/bin/archdevkit-terminal"

  log_info "安装桌面运行时辅助脚本：${helper}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write ${helper}"
    return 0
  fi

  mkdir -p "$(dirname "${helper}")"
  cat > "${helper}" <<'EOF'
#!/usr/bin/env bash
set -e

if command -v kitty >/dev/null 2>&1; then
  exec kitty "$@"
fi
if command -v foot >/dev/null 2>&1; then
  exec foot "$@"
fi
if command -v alacritty >/dev/null 2>&1; then
  exec alacritty "$@"
fi
if command -v xterm >/dev/null 2>&1; then
  exec xterm "$@"
fi

notify-send "Terminal unavailable" "Install kitty or foot." 2>/dev/null || true
exit 127
EOF
  chmod +x "${helper}"
}

enable_desktop_services() {
  log_info "启用桌面基础服务"
  run_sudo systemctl enable --now NetworkManager

  if [[ "${ENABLE_BLUETOOTH:-0}" -eq 1 ]]; then
    run_sudo systemctl enable --now bluetooth || log_warn "蓝牙服务启用失败，可稍后手动处理"
  fi

  enable_vmware_services_if_needed
  enable_qemu_services_if_needed
  enable_virtualbox_services_if_needed
}

enable_vmware_services_if_needed() {
  [[ "$(effective_gpu_type)" == "vmware" ]] || return 0

  log_info "启用 VMware Tools 服务"
  if systemd_system_unit_exists vmtoolsd.service; then
    run_sudo systemctl enable --now vmtoolsd.service || \
      log_warn "vmtoolsd.service 启用失败，可稍后手动处理"
  fi

  if systemd_system_unit_exists vmware-vmblock-fuse.service; then
    run_sudo systemctl enable --now vmware-vmblock-fuse.service || \
      log_warn "vmware-vmblock-fuse.service 启用失败，可稍后手动处理"
  fi
}

enable_qemu_services_if_needed() {
  case "$(effective_gpu_type)" in
    virtio|qxl) ;;
    *) return 0 ;;
  esac

  log_info "启用 QEMU/SPICE guest 服务"
  if systemd_system_unit_exists qemu-guest-agent.service; then
    run_sudo systemctl enable --now qemu-guest-agent.service || \
      log_warn "qemu-guest-agent.service 启用失败，可稍后手动处理"
  fi

  if systemd_system_unit_exists spice-vdagentd.service; then
    run_sudo systemctl enable --now spice-vdagentd.service || \
      log_warn "spice-vdagentd.service 启用失败，可稍后手动处理"
  fi
}

enable_virtualbox_services_if_needed() {
  [[ "$(effective_gpu_type)" == "virtualbox" ]] || return 0

  log_info "启用 VirtualBox guest 服务"
  if systemd_system_unit_exists vboxservice.service; then
    run_sudo systemctl enable --now vboxservice.service || \
      log_warn "vboxservice.service 启用失败，可稍后手动处理"
  fi
}

enable_desktop_audio_services() {
  hyprdots_mode_enabled || return 0

  log_info "启用 PipeWire 用户音频服务"
  run_sudo systemctl --global enable pipewire.service pipewire-pulse.service wireplumber.service || \
    log_warn "PipeWire 用户服务启用失败，可稍后手动处理"
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

  install_rime_config_repo
  configure_fcitx5_rime_profile
}

virtual_gpu_3d_acceleration_available() {
  case "$(effective_gpu_type)" in
    vmware|virtio|qxl|virtualbox) ;;
    *) return 1 ;;
  esac
  [[ "${VMWARE_FORCE_SOFTWARE_RENDERER:-0}" -eq 1 ]] && return 1

  local render_nodes=()
  shopt -s nullglob
  render_nodes=(/dev/dri/renderD*)
  shopt -u nullglob
  [[ "${#render_nodes[@]}" -gt 0 ]] || return 1

  if command -v eglinfo >/dev/null 2>&1; then
    local egl_output renderer_line
    egl_output="$(
      env \
        -u LIBGL_ALWAYS_SOFTWARE \
        -u MESA_LOADER_DRIVER_OVERRIDE \
        -u GALLIUM_DRIVER \
        eglinfo -B 2>/dev/null || true
    )"

    while IFS= read -r renderer_line; do
      [[ -n "${renderer_line}" ]] || continue
      grep -Eqi 'llvmpipe|softpipe|software rasterizer' <<<"${renderer_line}" && continue
      return 0
    done < <(grep -Ei 'OpenGL.*renderer|renderer:' <<<"${egl_output}" || true)
  fi

  return 1
}

hyprland_needs_software_renderer() {
  case "$(effective_gpu_type)" in
    vmware)
      virtual_gpu_3d_acceleration_available && return 1
      return 0
      ;;
    virtio|qxl|virtualbox)
      virtual_gpu_3d_acceleration_available && return 1
      return 0
      ;;
    *) return 1 ;;
  esac
}

configure_hyprland_gpu_env() {
  local hypr_conf="${HOME}/.config/hypr/hyprland.conf"
  local tmp_file gpu

  [[ -f "${hypr_conf}" ]] || return 0
  gpu="$(effective_gpu_type)"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if hyprland_needs_software_renderer; then
      echo "+ enable Hyprland software renderer env for ${gpu} in ${hypr_conf}"
    else
      echo "+ remove Hyprland software renderer env for ${gpu} from ${hypr_conf}"
    fi
    return 0
  fi

  tmp_file="$(mktemp)"
  sed \
    -e '/^### ArchDevKit VM EGL fix ###$/,/^### End ArchDevKit VM EGL fix ###$/d' \
    -e '/^env = LIBGL_ALWAYS_SOFTWARE,/d' \
    -e '/^env = MESA_LOADER_DRIVER_OVERRIDE,/d' \
    -e '/^env = GALLIUM_DRIVER,/d' \
    -e '/^env = WLR_RENDERER_ALLOW_SOFTWARE,/d' \
    "${hypr_conf}" > "${tmp_file}"

  if hyprland_needs_software_renderer; then
    local with_env
    log_warn "未检测到可用的硬件 EGL 渲染器；为 ${gpu} 写入 Hyprland llvmpipe 兜底"
    with_env="$(mktemp)"
    {
      cat <<EOF
### ArchDevKit VM EGL fix ###
# ${gpu} virtual GPU can fail EGL initialization without a usable 3D renderer.
# Remove this block automatically when VMware SVGA3D is detected.
env = LIBGL_ALWAYS_SOFTWARE,1
env = MESA_LOADER_DRIVER_OVERRIDE,llvmpipe
env = GALLIUM_DRIVER,llvmpipe
env = WLR_RENDERER_ALLOW_SOFTWARE,1
### End ArchDevKit VM EGL fix ###

EOF
      cat "${tmp_file}"
    } > "${with_env}"
    mv "${with_env}" "${tmp_file}"
  elif [[ "${gpu}" == "vmware" || "${gpu}" == "virtio" || "${gpu}" == "qxl" || "${gpu}" == "virtualbox" ]]; then
    log_info "检测到虚拟机可用硬件/3D 渲染；清理 Hyprland llvmpipe 兜底环境"
  fi

  install -m 0644 "${tmp_file}" "${hypr_conf}"
  rm -f "${tmp_file}"
}

configure_hyprland_virtualization_env() {
  local hypr_conf="${HOME}/.config/hypr/hyprland.conf"
  local mode="${VM_HYPRLAND_MONITOR_MODE:-${VMWARE_HYPRLAND_MONITOR_MODE:-1920x1080@60}}"
  local tmp_file gpu

  [[ -f "${hypr_conf}" ]] || return 0
  gpu="$(effective_gpu_type)"
  case "${gpu}" in
    vmware|virtio|qxl|virtualbox) ;;
    *) return 0 ;;
  esac

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ set VM Hyprland monitor fallback ${mode} in ${hypr_conf}"
    echo "+ enable VM guest agent autostart for ${gpu} in ${hypr_conf}"
    echo "+ apply low-latency Hyprland overrides for ${gpu} in ${hypr_conf}"
    return 0
  fi

  tmp_file="$(mktemp)"
  sed \
    -e '/^### ArchDevKit VM integration ###$/,/^### End ArchDevKit VM integration ###$/d' \
    -e '/^exec-once = vmware-user-suid-wrapper$/d' \
    -e '/^exec-once = spice-vdagent$/d' \
    -e '/^exec-once = VBoxClient-all$/d' \
    -e 's/^monitor[[:space:]]*=[[:space:]]*,preferred,auto,\(auto\|1\)[[:space:]]*$/monitor=,'"${mode}"',auto,1/' \
    -e 's/^monitor[[:space:]]*=[[:space:]]*Virtual-1,.*/monitor=,'"${mode}"',auto,1/' \
    "${hypr_conf}" > "${tmp_file}"

  if ! grep -Eq '^monitor[[:space:]]*=[[:space:]]*,'"${mode//./\\.}"',' "${tmp_file}"; then
    local with_monitor
    with_monitor="$(mktemp)"
    {
      printf 'monitor=,%s,auto,1\n' "${mode}"
      cat "${tmp_file}"
    } > "${with_monitor}"
    mv "${with_monitor}" "${tmp_file}"
  fi

  {
    printf '\n### ArchDevKit VM integration ###\n'
    case "${gpu}" in
      vmware)
        printf 'exec-once = vmware-user-suid-wrapper\n'
        ;;
      virtio|qxl)
        printf 'exec-once = spice-vdagent\n'
        ;;
      virtualbox)
        printf 'exec-once = VBoxClient-all\n'
        ;;
    esac
    if [[ "${VM_HYPRLAND_LOW_LATENCY:-1}" -eq 1 ]]; then
      cat <<'EOF'
animations {
    enabled = false
}

decoration {
    shadow {
        enabled = false
    }
    blur {
        enabled = false
    }
}

input {
    sensitivity = 0
    force_no_accel = false
}
EOF
    fi
    printf '### End ArchDevKit VM integration ###\n'
  } >> "${tmp_file}"

  install -m 0644 "${tmp_file}" "${hypr_conf}"
  rm -f "${tmp_file}"
}

install_rime_config_repo() {
  [[ "${INSTALL_RIME_CONFIG:-1}" -eq 1 ]] || {
    log_warn "当前配置不安装 Rime 配置仓库"
    return 0
  }

  local repo="${RIME_CONFIG_REPO:-}"
  local branch="${RIME_CONFIG_BRANCH:-}"
  local rime_dir="${RIME_CONFIG_DIR:-${HOME}/.local/share/fcitx5/rime}"
  local actual_url tmp_dir

  [[ -n "${repo}" ]] || die "Rime 配置仓库地址为空"
  ensure_git_command

  actual_url="$(github_proxy_url "${repo}")"
  tmp_dir="$(mktemp -d)"

  log_info "安装 Rime 配置仓库：${repo}"
  [[ "${repo}" != "${actual_url}" ]] && log_info "实际下载地址：${actual_url}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    if [[ -n "${branch}" ]]; then
      echo "+ git clone --depth=1 -b ${branch} ${actual_url} ${tmp_dir}/repo"
    else
      echo "+ git clone --depth=1 ${actual_url} ${tmp_dir}/repo"
    fi
    echo "+ backup ${rime_dir}"
    echo "+ install Rime config files -> ${rime_dir}"
    rmdir "${tmp_dir}"
    return 0
  fi

  local args=(clone --depth=1)
  [[ -n "${branch}" ]] && args+=(-b "${branch}")
  args+=("${actual_url}" "${tmp_dir}/repo")

  git "${args[@]}" || {
    rm -rf "${tmp_dir}"
    die "克隆 Rime 配置仓库失败：${repo}"
  }

  backup_path "${rime_dir}"
  mkdir -p "${rime_dir}"
  find "${tmp_dir}/repo" -mindepth 1 -maxdepth 1 \
    ! -name ".git" \
    ! -name ".gitignore" \
    ! -name "README.md" \
    ! -name "install.sh" \
    -exec cp -a {} "${rime_dir}/" \;
  rm -rf "${tmp_dir}"
  log_info "Rime 配置已安装到：${rime_dir}"
}

configure_fcitx5_rime_profile() {
  local fcitx5_dir="${HOME}/.config/fcitx5"
  local schema="${RIME_SCHEMA:-luna_pinyin_simp}"

  log_info "配置 Fcitx5 默认输入法为 Rime：${schema}"
  mkdir -p "${fcitx5_dir}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write ${fcitx5_dir}/profile"
    return 0
  fi

  backup_path "${fcitx5_dir}/profile"

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
  file_manager="$(sed_escape_replacement "${FILE_MANAGER:-yazi}")"
  app_launcher="$(sed_escape_replacement "${APP_LAUNCHER:-rofi}")"

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
  case "${HYPRLAND_CONFIG_MODE:-hyprdots}" in
    hyprdots)
      install_hyprdots_config
      ;;
    template)
      log_info "生成 Hyprland 默认配置"
      install_hyprland_templates
      ;;
    skip)
      log_warn "当前 Hyprland 配置模式为 skip，跳过配置安装"
      ;;
    *)
      die "未知 Hyprland 配置模式：${HYPRLAND_CONFIG_MODE}"
      ;;
  esac
}

hyprdots_module_target() {
  printf '%s/.config/%s' "${HOME}" "$1"
}

install_hyprdots_config() {
  local source_root="${HYPRDOTS_SOURCE_DIR:-${SCRIPT_DIR}/files/hyprdots}"
  local module

  [[ -d "${source_root}" ]] || die "hyprdots 配置源不存在：${source_root}"

  log_info "安装 hyprdots 配置模块，来源提交：${HYPRDOTS_SOURCE_COMMIT:-unknown}"
  for module in "${HYPRDOTS_CONFIG_MODULES[@]}"; do
    install_hyprdots_config_module "${source_root}" "${module}"
  done

  disable_hyprland_lua_entrypoint
  install_hyprdots_local_bin "${source_root}"
  ensure_hyprdots_wallpaper_dir
  ensure_hyprpaper_config
  apply_hyprdots_runtime_overrides
  ensure_waybar_runtime_files
  install_hyprdots_web_apps "${source_root}"
}

install_hyprdots_config_module() {
  local source_root="$1" module="$2"
  local source="${source_root}/${module}"
  local target
  target="$(hyprdots_module_target "${module}")"

  if [[ ! -d "${source}" ]]; then
    log_warn "hyprdots 模块不存在，跳过：${module}"
    return 0
  fi

  log_info "安装 hyprdots 配置模块：${module}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ backup ${target}"
    echo "+ cp -a ${source} ${target}"
    return 0
  fi

  mkdir -p "${HOME}/.config"
  backup_path "${target}"
  cp -a "${source}" "${target}"
  make_hyprdots_scripts_executable "${target}"
}

disable_hyprland_lua_entrypoint() {
  local lua_entry="${HOME}/.config/hypr/hyprland.lua"
  local disabled_entry="${lua_entry}.disabled"

  [[ -e "${lua_entry}" || -L "${lua_entry}" ]] || return 0

  log_warn "检测到 Hyprland Lua 入口配置，禁用它以使用 hyprland.conf 启动：${lua_entry}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ mv ${lua_entry} ${disabled_entry}"
    return 0
  fi

  backup_path "${disabled_entry}"
  mv "${lua_entry}" "${disabled_entry}"
}

make_hyprdots_scripts_executable() {
  local target="$1"
  [[ -d "${target}" ]] || return 0
  find "${target}" -type f \( -name "*.sh" -o -name "switch_waybar" -o -name "weekly_commits" \) -exec chmod +x {} +
}

install_hyprdots_local_bin() {
  local source_root="$1"
  local source="${source_root}/bin"
  local target="${HYPRDOTS_LOCAL_BIN_DIR:-${HOME}/.local/bin}"

  [[ -d "${source}" ]] || {
    log_warn "hyprdots bin 目录不存在，跳过：${source}"
    return 0
  }

  log_info "安装 hyprdots 本地脚本：${target}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ mkdir -p ${target}"
    echo "+ cp -a ${source}/. ${target}/"
    echo "+ chmod +x ${target}/*"
    return 0
  fi

  mkdir -p "${target}"
  cp -a "${source}/." "${target}/"
  find "${target}" -maxdepth 1 -type f -exec chmod +x {} +
}

ensure_hyprdots_wallpaper_dir() {
  local dir="${HYPRDOTS_WALLPAPER_DIR:-${HOME}/Pictures/Wallpaper}"
  log_info "确保壁纸目录存在：${dir}"
  run_cmd mkdir -p "${dir}"
}

ensure_hyprpaper_config() {
  local config_path="${HOME}/.config/hypr/hyprpaper.conf"

  [[ -f "${config_path}" ]] && return 0

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write ${config_path}"
    return 0
  fi

  mkdir -p "$(dirname "${config_path}")"
  cat > "${config_path}" <<'EOF'
splash = false
EOF
}

hyprdots_menu_command() {
  case "${APP_LAUNCHER:-rofi}" in
    rofi) printf 'rofi -show run' ;;
    wofi) printf 'wofi --show drun' ;;
    *) printf '%s' "${APP_LAUNCHER}" ;;
  esac
}

apply_hyprdots_runtime_overrides() {
  local hypr_conf="${HOME}/.config/hypr/hyprland.conf"
  local variables_lua="${HOME}/.config/hypr/modules/variables.lua"
  local terminal file_manager menu browser note_app

  [[ "${DRY_RUN:-0}" -eq 1 ]] && {
    echo "+ render ArchDevKit overrides into ${hypr_conf}"
    echo "+ render ArchDevKit overrides into ${variables_lua}"
    return 0
  }

  terminal="$(sed_escape_replacement "${TERMINAL_APP:-kitty}")"
  file_manager="$(sed_escape_replacement "${FILE_MANAGER:-yazi}")"
  menu="$(sed_escape_replacement "$(hyprdots_menu_command)")"
  browser="$(sed_escape_replacement "${BROWSER_APP:-google-chrome-stable}")"
  if [[ "${INSTALL_HYPRDOTS_OBSIDIAN:-0}" -eq 1 ]]; then
    note_app="$(sed_escape_replacement "obsidian")"
  else
    note_app="$(sed_escape_replacement ":")"
  fi

  if [[ -f "${hypr_conf}" ]]; then
    local tmp_file
    tmp_file="$(mktemp)"
    sed \
      -e "s/^[$]terminal = .*/\$terminal = ${terminal}/" \
      -e "s/^[$]fileManager = .*/\$fileManager = ${file_manager}/" \
      -e "s/^[$]menu = .*/\$menu = ${menu}/" \
      -e "s/^[$]browser = .*/\$browser = ${browser}/" \
      -e "s/^[$]note = .*/\$note = ${note_app}/" \
      "${hypr_conf}" > "${tmp_file}"

    if [[ "${INSTALL_HYPRDOTS_OBSIDIAN:-0}" -ne 1 ]]; then
      sed \
        -e '/^windowrule = match:class obsidian/s/^/# /' \
        "${tmp_file}" > "${tmp_file}.obsidian"
      mv "${tmp_file}.obsidian" "${tmp_file}"
    fi

    if [[ "${ENABLE_FCITX5:-0}" -ne 1 ]]; then
      sed \
        -e '/^exec-once = fcitx5 -d/s/^/# /' \
        -e '/^env = .*fcitx/s/^/# /' \
        "${tmp_file}" > "${tmp_file}.fcitx"
      mv "${tmp_file}.fcitx" "${tmp_file}"
    fi

    install -m 0644 "${tmp_file}" "${hypr_conf}"
    rm -f "${tmp_file}"
  fi

  if [[ -f "${variables_lua}" ]]; then
    local tmp_lua
    tmp_lua="$(mktemp)"
    sed \
      -e "s/terminal = \".*\"/terminal = \"${terminal}\"/" \
      -e "s/fileManager = \".*\"/fileManager = \"${file_manager}\"/" \
      -e "s/menu = \".*\"/menu = \"${menu}\"/" \
      -e "s/browser = \".*\"/browser = \"${browser}\"/" \
      -e "s/note = \".*\"/note = \"${note_app}\"/" \
      "${variables_lua}" > "${tmp_lua}"
    install -m 0644 "${tmp_lua}" "${variables_lua}"
    rm -f "${tmp_lua}"
  fi
}

ensure_waybar_runtime_files() {
  local waybar_dir="${HOME}/.config/waybar"
  local env_file="${waybar_dir}/scripts/.env"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ link ${waybar_dir}/config -> config_new.jsonc"
    echo "+ link ${waybar_dir}/config.jsonc -> config_new.jsonc"
    echo "+ link ${waybar_dir}/style.css -> style_new.css"
    echo "+ create ${env_file} if missing"
    return 0
  fi

  if [[ -d "${waybar_dir}" ]]; then
    (
      cd "${waybar_dir}" || return 0
      [[ -f config_new.jsonc ]] && ln -sfn config_new.jsonc config
      [[ -f config_new.jsonc ]] && ln -sfn config_new.jsonc config.jsonc
      [[ -f style_new.css ]] && ln -sfn style_new.css style.css
    )
  fi

  if [[ ! -f "${env_file}" ]]; then
    mkdir -p "$(dirname "${env_file}")"
    cat > "${env_file}" <<'EOF'
GITHUB_USERNAME=
GITHUB_PAT=
EOF
  fi
}

install_hyprdots_web_apps() {
  local source_root="$1"
  local source="${source_root}/web-apps"
  local apps_dir="${HOME}/.local/share/applications"
  local icons_dir="${apps_dir}/icons"
  local desktop_file target_file browser_app

  [[ "${INSTALL_HYPRDOTS_WEB_APPS:-0}" -eq 1 ]] || {
    log_info "当前配置未启用 hyprdots Web App 启动器，跳过"
    return 0
  }

  [[ -d "${source}" ]] || {
    log_warn "hyprdots web-apps 目录不存在，跳过：${source}"
    return 0
  }

  browser_app="$(sed_escape_replacement "${BROWSER_APP:-google-chrome-stable}")"
  log_info "安装 hyprdots Web App 启动器：${apps_dir}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ mkdir -p ${apps_dir} ${icons_dir}"
    echo "+ install web-app desktop files from ${source}"
    return 0
  fi

  mkdir -p "${apps_dir}" "${icons_dir}"

  if [[ -d "${source}/icons" ]]; then
    cp -a "${source}/icons/." "${icons_dir}/"
  fi

  while IFS= read -r desktop_file; do
    if [[ "$(basename "${desktop_file}")" == "steam.desktop" ]] && ! command -v steam >/dev/null 2>&1; then
      log_warn "未安装 steam，跳过 steam.desktop"
      continue
    fi

    target_file="${apps_dir}/$(basename "${desktop_file}")"
    sed \
      -e "s|\\$HOME|${HOME}|g" \
      -e "s|google-chrome-stable|${browser_app}|g" \
      "${desktop_file}" > "${target_file}"
    chmod 0644 "${target_file}"
  done < <(find "${source}" -maxdepth 1 -type f -name "*.desktop" | sort)
}

systemd_system_unit_exists() {
  local unit="$1"
  [[ -n "${unit}" ]] || die "systemd unit 名为空"

  [[ -e "/etc/systemd/system/${unit}" ]] && return 0
  [[ -e "/usr/lib/systemd/system/${unit}" ]] && return 0
  [[ -e "/lib/systemd/system/${unit}" ]] && return 0

  systemctl list-unit-files "${unit}" --no-legend 2>/dev/null | awk '{print $1}' | grep -Fxq "${unit}"
}

enable_sddm_if_needed() {
  [[ "${ENABLE_SDDM:-0}" -eq 1 ]] || {
    log_warn "当前配置未启用 SDDM"
    return 0
  }

  if ! systemd_system_unit_exists sddm.service; then
    log_warn "未检测到 sddm.service，尝试安装 SDDM 软件包"
    install_required_pacman_package sddm
    run_sudo systemctl daemon-reload || log_warn "systemd 重新加载失败，可稍后手动执行：sudo systemctl daemon-reload"
  fi

  systemd_system_unit_exists sddm.service || \
    die "SDDM 软件包安装后仍未找到 sddm.service；请检查 sudo pacman -S sddm 的输出，或使用 --no-sddm 跳过登录管理器启用"

  log_info "启用 SDDM 登录管理器"
  run_sudo systemctl enable sddm.service || \
    die "启用 SDDM 失败；如果已有其他登录管理器占用 display-manager.service，请先禁用它后重试"
  log_warn "SDDM 已设置为开机自启，重启后在登录界面选择 Hyprland"
}

verify_hyprland() {
  log_info "验证 Hyprland 关键命令"
  run_cmd Hyprland --version || true
  run_cmd waybar --version || true
  run_cmd rofi -version || true
  run_cmd dunst --version || true
  run_cmd yazi --version || true
  run_cmd "${BROWSER_APP:-google-chrome-stable}" --version || true
  if [[ "${ENABLE_FCITX5:-0}" -eq 1 ]]; then
    run_cmd fcitx5 --version || true
  fi
}

ensure_desktop_hyprland() {
  if ! is_done "desktop_hyprland"; then
    install_desktop_hyprland
  fi
}
