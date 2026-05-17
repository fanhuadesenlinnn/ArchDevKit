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
  install_gpu_packages_if_needed
  enable_desktop_services
  configure_fcitx5_env
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
    fcitx5-im fcitx5-chinese-addons fcitx5-configtool \
    firefox sddm
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

generate_hyprland_config() {
  [[ "${HYPRLAND_CONFIG_MODE}" == "template" ]] || {
    log_warn "当前 Hyprland 配置模式为 ${HYPRLAND_CONFIG_MODE}，跳过模板生成"
    return 0
  }

  log_info "生成 Hyprland 默认配置"

  backup_path "${HOME}/.config/hypr"
  backup_path "${HOME}/.config/waybar"
  backup_path "${HOME}/.config/mako"
  backup_path "${HOME}/.config/wofi"
  backup_path "${HOME}/.config/kitty"

  mkdir -p "${HOME}/.config/hypr" "${HOME}/.config/waybar" "${HOME}/.config/mako" "${HOME}/.config/wofi" "${HOME}/.config/kitty"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write Hyprland/Waybar/Mako/Wofi/Kitty config"
    return 0
  fi

  cat > "${HOME}/.config/hypr/hyprland.conf" <<'EOF'
# ArchDevKit 生成的 Hyprland 主配置
# 没有壁纸时不会启动 hyprpaper。

$mod = SUPER
$terminal = kitty
$fileManager = thunar
$menu = wofi --show drun

monitor = ,preferred,auto,1

env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = GDK_BACKEND,wayland,x11
env = MOZ_ENABLE_WAYLAND,1
env = GTK_IM_MODULE,fcitx
env = QT_IM_MODULE,fcitx
env = XMODIFIERS,@im=fcitx
env = INPUT_METHOD,fcitx
env = SDL_IM_MODULE,fcitx
env = GLFW_IM_MODULE,ibus

exec-once = waybar
exec-once = mako
exec-once = fcitx5
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = /usr/lib/polkit-kde-authentication-agent-1

input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0

    touchpad {
        natural_scroll = true
        tap-to-click = true
        disable_while_typing = true
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    layout = dwindle
    col.active_border = rgba(7aa2f7ff)
    col.inactive_border = rgba(414868ff)
}

decoration {
    rounding = 10
    shadow {
        enabled = true
        range = 12
        render_power = 3
        color = rgba(00000055)
    }
    blur {
        enabled = true
        size = 6
        passes = 2
        new_optimizations = true
    }
}

animations {
    enabled = true
    bezier = easeOut, 0.16, 1, 0.3, 1
    animation = windows, 1, 4, easeOut
    animation = windowsOut, 1, 4, easeOut
    animation = border, 1, 6, easeOut
    animation = fade, 1, 4, easeOut
    animation = workspaces, 1, 4, easeOut
}

dwindle {
    pseudotile = true
    preserve_split = true
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    vfr = true
}

bind = $mod, Return, exec, $terminal
bind = $mod, Space, exec, $menu
bind = $mod, E, exec, $fileManager
bind = $mod, B, exec, firefox
bind = $mod, Q, killactive
bind = $mod SHIFT, Q, exit
bind = $mod, F, fullscreen
bind = $mod, V, togglefloating

bind = $mod, Left, movefocus, l
bind = $mod, Right, movefocus, r
bind = $mod, Up, movefocus, u
bind = $mod, Down, movefocus, d

bind = $mod SHIFT, Left, movewindow, l
bind = $mod SHIFT, Right, movewindow, r
bind = $mod SHIFT, Up, movewindow, u
bind = $mod SHIFT, Down, movewindow, d

bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5
bind = $mod, 6, workspace, 6
bind = $mod, 7, workspace, 7
bind = $mod, 8, workspace, 8
bind = $mod, 9, workspace, 9

bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5
bind = $mod SHIFT, 6, movetoworkspace, 6
bind = $mod SHIFT, 7, movetoworkspace, 7
bind = $mod SHIFT, 8, movetoworkspace, 8
bind = $mod SHIFT, 9, movetoworkspace, 9

bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow

bind = , Print, exec, mkdir -p ~/Pictures && grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%F-%H%M%S).png
bind = SHIFT, Print, exec, grim -g "$(slurp)" - | wl-copy

bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bind = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

windowrulev2 = float,class:^(pavucontrol)$
windowrulev2 = float,class:^(blueman-manager)$
windowrulev2 = float,class:^(nm-connection-editor)$
windowrulev2 = float,class:^(fcitx5-config-qt)$
EOF

  cat > "${HOME}/.config/waybar/config" <<'EOF'
{
  "layer": "top",
  "position": "top",
  "height": 34,
  "modules-left": ["hyprland/workspaces", "hyprland/window"],
  "modules-center": ["clock"],
  "modules-right": ["network", "pulseaudio", "cpu", "memory", "tray"],
  "hyprland/workspaces": { "format": "{id}", "on-click": "activate" },
  "clock": { "format": "{:%Y-%m-%d %H:%M}" },
  "network": { "format-wifi": "  {essid}", "format-ethernet": "󰈀 有线", "format-disconnected": "󰖪 断开" },
  "pulseaudio": { "format": "  {volume}%", "format-muted": "󰖁 静音", "on-click": "pavucontrol" },
  "cpu": { "format": "CPU {usage}%" },
  "memory": { "format": "MEM {}%" },
  "tray": { "spacing": 10 }
}
EOF

  cat > "${HOME}/.config/waybar/style.css" <<'EOF'
* { font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK SC"; font-size: 13px; border: none; min-height: 0; }
window#waybar { background: rgba(26, 27, 38, 0.88); color: #c0caf5; }
#workspaces button { padding: 0 10px; color: #a9b1d6; background: transparent; }
#workspaces button.active { color: #7aa2f7; background: rgba(122, 162, 247, 0.18); }
#clock, #network, #pulseaudio, #cpu, #memory, #tray, #window { padding: 0 10px; }
EOF

  cat > "${HOME}/.config/mako/config" <<'EOF'
font=JetBrainsMono Nerd Font 11
background-color=#1a1b26dd
text-color=#c0caf5
border-color=#7aa2f7
border-size=2
border-radius=8
padding=12
default-timeout=5000
EOF

  cat > "${HOME}/.config/wofi/config" <<'EOF'
show=drun
width=600
height=420
prompt=Search
allow_images=true
insensitive=true
EOF

  cat > "${HOME}/.config/kitty/kitty.conf" <<'EOF'
font_family JetBrainsMono Nerd Font
font_size 12.0
background_opacity 0.94
confirm_os_window_close 0
enable_audio_bell no
EOF
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
}

ensure_desktop_hyprland() {
  if ! is_done "desktop_hyprland"; then
    install_desktop_hyprland
  fi
}
