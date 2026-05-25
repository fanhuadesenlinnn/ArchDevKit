#!/usr/bin/env bash
set -Eeuo pipefail

# ArchDevKit 主入口
# 负责加载配置、解析参数、显示菜单、展示计划并编排各个模块。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/install_vars"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/files.sh"
source "${SCRIPT_DIR}/lib/packages.sh"
source "${SCRIPT_DIR}/lib/systemd.sh"
source "${SCRIPT_DIR}/lib/json.sh"
source "${SCRIPT_DIR}/modules/base.sh"
source "${SCRIPT_DIR}/modules/dns.sh"
source "${SCRIPT_DIR}/modules/archlinuxcn.sh"
source "${SCRIPT_DIR}/modules/git.sh"
source "${SCRIPT_DIR}/modules/runtime.sh"
source "${SCRIPT_DIR}/modules/nvim.sh"
source "${SCRIPT_DIR}/modules/docker.sh"
source "${SCRIPT_DIR}/modules/fonts.sh"
source "${SCRIPT_DIR}/modules/shell_zsh.sh"
source "${SCRIPT_DIR}/modules/desktop_hyprland.sh"
source "${SCRIPT_DIR}/modules/proxy.sh"
source "${SCRIPT_DIR}/lib/module_registry.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/doctor.sh"
source "${SCRIPT_DIR}/lib/recovery.sh"

ACTION="menu"
TARGET="${ARCHDEVKIT_DEFAULT_PROFILE:-workstation}"
TARGET_SET=0
FORCE_INSTALL=0
NO_STATE=0
RESUME_INSTALL=0
OUTPUT_JSON=0
ARCHDEVKIT_LOG_FILE=""
MODULE_SKIPPED_LIST=""

show_help() {
  cat <<'EOF'
ArchDevKit - Arch Linux 工作站初始化工具

用法：
  bash install.sh
  bash install.sh menu
  bash install.sh plan [base|dns|archlinuxcn|git|runtime|nvim|docker|fonts|shell|desktop|proxy|dev|workstation]
  bash install.sh install [base|dns|archlinuxcn|git|runtime|nvim|docker|fonts|shell|desktop|proxy|dev|workstation]
  bash install.sh status [module]
  bash install.sh doctor
  bash install.sh config
  bash install.sh reset-state [module|all]

兼容用法：
  bash install.sh workstation
  bash install.sh proxy

常用参数：
  -y, --yes                 自动确认
  --dry-run                 只显示计划，不执行
  --force                   忽略模块状态，强制重跑目标模块
  --resume                  从状态记录继续，已成功模块自动跳过
  --no-state                不读取或写入模块状态
  --json                    plan/status/doctor 输出 JSON
  --config-file PATH        加载指定用户配置文件
  --no-config-file          不加载用户配置文件
  --no-china                不配置 npm/pip 国内源
  --no-github-proxy         不使用 GitHub 代理
  --github-proxy URL        指定 GitHub 代理
  --node-mirror URL         指定后续手动 mise use 使用的 Node.js 下载镜像
  --go-mirror URL           指定后续手动 mise use 使用的 Go SDK 下载镜像
  --python-build-mirror URL 指定后续手动 mise use 使用的 python-build 下载镜像
  --pyenv-repo URL          指定 mise Python 使用的 pyenv 仓库
  --dns                     dev/workstation 中配置系统 DNS
  --no-dns                  dev/workstation 中跳过系统 DNS
  --dns-over-tls MODE       systemd-resolved DNSOverTLS：no / opportunistic / yes
  --repo URL                指定 Neovim 配置仓库
  --branch NAME             指定 Neovim 配置分支
  --no-plugin-sync          不同步 Neovim 插件
  --node-version VERSION    指定后续手动 mise use 的 Node.js 目标版本
  --npm-version VERSION     指定后续手动 npm 调整的目标版本
  --python-version VERSION  指定后续手动 mise use 的 Python 目标版本
  --go-version VERSION      指定后续手动 mise use 的 Go 目标版本
  --no-sddm                 不启用 SDDM
  --nvidia                  安装 NVIDIA Wayland 相关包
  --gpu TYPE                指定 GPU 类型：auto / intel / amd / nvidia / vmware / virtio / qxl / virtualbox / none
  --vm-dynamic-resize       虚拟机使用动态分辨率
  --no-vm-dynamic-resize    虚拟机使用固定 fallback 分辨率
  --vm-monitor-mode MODE    指定虚拟机固定 fallback 分辨率
  --monaco                  安装 Monaco 字体
  --browser-package NAME    指定桌面浏览器安装包
  --browser-app COMMAND     指定桌面浏览器启动命令
  --hyprland-config-mode MODE 指定 Hyprland 配置模式：hyprdots / template / skip
  --with-obsidian          安装 hyprdots 可选应用 Obsidian
  --no-obsidian            不安装 hyprdots 可选应用 Obsidian
  --rime-schema NAME        指定 Rime 默认方案
  --rime-repo URL           指定 Rime 配置仓库
  --rime-branch NAME        指定 Rime 配置分支
  --no-rime-config          不安装 Rime 配置仓库
  --with-proxy              dev/workstation 中安装 Proxy 模块
  --no-proxy                dev/workstation 中不安装 Proxy 模块
  --proxy-core NAME         指定代理核心：mihomo / sing-box
  --no-metacubexd           不安装 MetaCubeXD 面板
  --mihomo-config PATH/URL  指定 Mihomo 配置文件或 URL
  --sing-box-config PATH/URL 指定 sing-box 配置文件或 URL
EOF
}

parse_args() {
  local token
  while [[ $# -gt 0 ]]; do
    token="$1"
    case "${token}" in
      menu|config|help|plan|install|status|doctor|reset-state)
        ACTION="${token}"; shift ;;
      all)
        if [[ "${ACTION}" == "status" || "${ACTION}" == "reset-state" ]]; then
          TARGET="all"
          TARGET_SET=1
          shift
        else
          die "all 只能用于 status 或 reset-state"
        fi
        ;;
      base|dns|archlinuxcn|git|runtime|nvim|docker|fonts|shell|zsh|desktop|hyprland|proxy|dev|workstation)
        TARGET="${token}"
        TARGET_SET=1
        [[ "${ACTION}" == "menu" ]] && ACTION="install"
        shift ;;
      -y|--yes) ASSUME_YES=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --force|--reinstall) FORCE_INSTALL=1; shift ;;
      --resume) RESUME_INSTALL=1; shift ;;
      --no-state) NO_STATE=1; shift ;;
      --json) OUTPUT_JSON=1; shift ;;
      --config-file)
        [[ $# -ge 2 && -n "${2:-}" ]] || die "--config-file 需要路径"
        ARCHDEVKIT_CONFIG_FILE="${2}"
        ARCHDEVKIT_LOAD_CONFIG_FILE=1
        shift 2
        ;;
      --config-file=*)
        ARCHDEVKIT_CONFIG_FILE="${1#*=}"
        [[ -n "${ARCHDEVKIT_CONFIG_FILE}" ]] || die "--config-file 需要路径"
        ARCHDEVKIT_LOAD_CONFIG_FILE=1
        shift
        ;;
      --no-config-file) ARCHDEVKIT_LOAD_CONFIG_FILE=0; shift ;;
      --no-china) ENABLE_CHINA_MIRROR=0; shift ;;
      --no-github-proxy) ENABLE_GITHUB_PROXY=0; shift ;;
      --github-proxy) GITHUB_PROXY="${2:-}"; ENABLE_GITHUB_PROXY=1; shift 2 ;;
      --github-proxy=*) GITHUB_PROXY="${1#*=}"; ENABLE_GITHUB_PROXY=1; shift ;;
      --node-mirror) NODE_MIRROR_URL="${2:-}"; shift 2 ;;
      --node-mirror=*) NODE_MIRROR_URL="${1#*=}"; shift ;;
      --go-mirror) GO_DOWNLOAD_MIRROR="${2:-}"; shift 2 ;;
      --go-mirror=*) GO_DOWNLOAD_MIRROR="${1#*=}"; shift ;;
      --python-build-mirror) PYTHON_BUILD_MIRROR_URL="${2:-}"; shift 2 ;;
      --python-build-mirror=*) PYTHON_BUILD_MIRROR_URL="${1#*=}"; shift ;;
      --pyenv-repo) PYENV_REPO_URL="${2:-}"; shift 2 ;;
      --pyenv-repo=*) PYENV_REPO_URL="${1#*=}"; shift ;;
      --dns) ENABLE_DNS=1; shift ;;
      --no-dns) ENABLE_DNS=0; shift ;;
      --dns-over-tls) DNS_OVER_TLS="${2:-no}"; shift 2 ;;
      --dns-over-tls=*) DNS_OVER_TLS="${1#*=}"; shift ;;
      --repo) NVIM_REPO="${2:-}"; shift 2 ;;
      --repo=*) NVIM_REPO="${1#*=}"; shift ;;
      --branch) NVIM_BRANCH="${2:-}"; shift 2 ;;
      --branch=*) NVIM_BRANCH="${1#*=}"; shift ;;
      --no-plugin-sync) SYNC_NVIM_PLUGINS=0; shift ;;
      --node-version) NODE_VERSION="${2:-}"; shift 2 ;;
      --node-version=*) NODE_VERSION="${1#*=}"; shift ;;
      --npm-version) NPM_VERSION="${2:-}"; shift 2 ;;
      --npm-version=*) NPM_VERSION="${1#*=}"; shift ;;
      --python-version) PYTHON_VERSION="${2:-}"; shift 2 ;;
      --python-version=*) PYTHON_VERSION="${1#*=}"; shift ;;
      --go-version) GO_VERSION="${2:-}"; shift 2 ;;
      --go-version=*) GO_VERSION="${1#*=}"; shift ;;
      --no-sddm) ENABLE_SDDM=0; shift ;;
      --sddm) ENABLE_SDDM=1; shift ;;
      --nvidia) GPU_TYPE="nvidia"; shift ;;
      --gpu) GPU_TYPE="${2:-auto}"; shift 2 ;;
      --gpu=*) GPU_TYPE="${1#*=}"; shift ;;
      --vm-dynamic-resize) VM_HYPRLAND_DYNAMIC_RESIZE=1; shift ;;
      --no-vm-dynamic-resize) VM_HYPRLAND_DYNAMIC_RESIZE=0; shift ;;
      --vm-monitor-mode) VM_HYPRLAND_MONITOR_MODE="${2:-1920x1080@60}"; VMWARE_HYPRLAND_MONITOR_MODE="${VM_HYPRLAND_MONITOR_MODE}"; shift 2 ;;
      --vm-monitor-mode=*) VM_HYPRLAND_MONITOR_MODE="${1#*=}"; VMWARE_HYPRLAND_MONITOR_MODE="${VM_HYPRLAND_MONITOR_MODE}"; shift ;;
      --monaco) INSTALL_MONACO_FONT=1; shift ;;
      --no-monaco) INSTALL_MONACO_FONT=0; shift ;;
      --browser-package) BROWSER_PACKAGE="${2:-}"; shift 2 ;;
      --browser-package=*) BROWSER_PACKAGE="${1#*=}"; shift ;;
      --browser-app) BROWSER_APP="${2:-}"; shift 2 ;;
      --browser-app=*) BROWSER_APP="${1#*=}"; shift ;;
      --hyprland-config-mode) HYPRLAND_CONFIG_MODE="${2:-hyprdots}"; shift 2 ;;
      --hyprland-config-mode=*) HYPRLAND_CONFIG_MODE="${1#*=}"; shift ;;
      --with-obsidian) INSTALL_HYPRDOTS_OBSIDIAN=1; shift ;;
      --no-obsidian) INSTALL_HYPRDOTS_OBSIDIAN=0; shift ;;
      --rime-schema) RIME_SCHEMA="${2:-}"; INPUT_METHOD_ENGINE="rime"; shift 2 ;;
      --rime-schema=*) RIME_SCHEMA="${1#*=}"; INPUT_METHOD_ENGINE="rime"; shift ;;
      --rime-repo) RIME_CONFIG_REPO="${2:-}"; INSTALL_RIME_CONFIG=1; INPUT_METHOD_ENGINE="rime"; shift 2 ;;
      --rime-repo=*) RIME_CONFIG_REPO="${1#*=}"; INSTALL_RIME_CONFIG=1; INPUT_METHOD_ENGINE="rime"; shift ;;
      --rime-branch) RIME_CONFIG_BRANCH="${2:-}"; INSTALL_RIME_CONFIG=1; INPUT_METHOD_ENGINE="rime"; shift 2 ;;
      --rime-branch=*) RIME_CONFIG_BRANCH="${1#*=}"; INSTALL_RIME_CONFIG=1; INPUT_METHOD_ENGINE="rime"; shift ;;
      --no-rime-config) INSTALL_RIME_CONFIG=0; shift ;;
      --with-proxy) ENABLE_PROXY=1; shift ;;
      --no-proxy) ENABLE_PROXY=0; shift ;;
      --proxy-core) PROXY_CORE="${2:-mihomo}"; ENABLE_PROXY=1; shift 2 ;;
      --proxy-core=*) PROXY_CORE="${1#*=}"; ENABLE_PROXY=1; shift ;;
      --metacubexd) ENABLE_METACUBEXD=1; shift ;;
      --no-metacubexd) ENABLE_METACUBEXD=0; shift ;;
      --mihomo-config) MIHOMO_CONFIG_SOURCE="${2:-}"; PROXY_CORE="mihomo"; ENABLE_PROXY=1; shift 2 ;;
      --mihomo-config=*) MIHOMO_CONFIG_SOURCE="${1#*=}"; PROXY_CORE="mihomo"; ENABLE_PROXY=1; shift ;;
      --sing-box-config) SING_BOX_CONFIG_SOURCE="${2:-}"; PROXY_CORE="sing-box"; ENABLE_PROXY=1; shift 2 ;;
      --sing-box-config=*) SING_BOX_CONFIG_SOURCE="${1#*=}"; PROXY_CORE="sing-box"; ENABLE_PROXY=1; shift ;;
      --no-p10k) INSTALL_POWERLEVEL10K=0; INSTALL_P10K_CONFIG=0; shift ;;
      --p10k) INSTALL_POWERLEVEL10K=1; INSTALL_P10K_CONFIG=1; shift ;;
      --set-zsh-default) SET_ZSH_AS_DEFAULT=1; shift ;;
      --no-set-zsh-default) SET_ZSH_AS_DEFAULT=0; shift ;;
      -h|--help) ACTION="help"; shift ;;
      *) die "未知参数：$1" ;;
    esac
  done

  if [[ "${ACTION}" == "status" && "${TARGET_SET}" -eq 0 ]]; then
    TARGET="all"
  fi
  if [[ "${ACTION}" == "reset-state" && "${TARGET_SET}" -eq 0 ]]; then
    TARGET="all"
  fi
}

show_config() {
  echo "----------------------------------------------------------"
  echo "[当前安装配置]"
  echo "执行用户:             ${USER}"
  echo "默认目标:             ${ARCHDEVKIT_DEFAULT_PROFILE:-workstation}"
  echo "dry-run:              $(bool_text "${DRY_RUN}")"
  echo "自动确认:             $(bool_text "${ASSUME_YES}")"
  echo "用户配置文件:         ${ARCHDEVKIT_CONFIG_FILE:-${HOME}/.config/archdevkit/config.env}"
  echo "已加载用户配置:       $(bool_text "${CONFIG_FILE_LOADED}")"
  echo "模块状态目录:         $(state_root)"
  echo "JSON schema:          ${ARCHDEVKIT_JSON_SCHEMA_VERSION:-1}"
  echo
  echo "[中国大陆网络]"
  echo "启用国内源:           $(bool_text "${ENABLE_CHINA_MIRROR}")"
  echo "npm 源:               ${NPM_REGISTRY}"
  echo "pip 源:               ${PIP_INDEX_URL}"
  echo "mise Node 镜像:       ${NODE_MIRROR_URL}（仅后续手动 mise use）"
  echo "mise Go 镜像:         ${GO_DOWNLOAD_MIRROR}（仅后续手动 mise use）"
  echo "python-build 镜像:    ${PYTHON_BUILD_MIRROR_URL}（仅后续手动 mise use）"
  echo "pyenv 实际仓库:       $(mise_pyenv_repo_url)"
  echo "启用 GitHub 代理:     $(bool_text "${ENABLE_GITHUB_PROXY}")"
  echo "GitHub 代理地址:      ${GITHUB_PROXY}"
  echo "系统 DNS:             $(bool_text "${ENABLE_DNS}")"
  echo "DNS 服务器:           ${DNS_SERVERS[*]}"
  echo "DNS fallback:         ${DNS_FALLBACK_SERVERS[*]}"
  echo "DNS 国外 fallback:    ${DNS_FOREIGN_FALLBACK_SERVERS[*]}"
  echo "DNSOverTLS:           ${DNS_OVER_TLS}"
  echo "HTTPS_PROXY:          ${HTTPS_PROXY:-未设置}"
  echo "HTTP_PROXY:           ${HTTP_PROXY:-未设置}"
  echo "ALL_PROXY:            ${ALL_PROXY:-未设置}"
  echo
  echo "[Runtime]"
  echo "系统运行时:           pacman 安装 nodejs/npm/python/python-pip/go"
  echo "管理工具:             ${RUNTIME_MANAGER}（只配置，不默认执行 mise use）"
  echo "mise Node.js 目标:    ${NODE_VERSION}"
  echo "npm 目标:             ${NPM_VERSION}"
  echo "mise Python 目标:     ${PYTHON_VERSION}"
  echo "mise Go 目标:         ${GO_VERSION}"
  echo "Corepack:             $(bool_text "${ENABLE_COREPACK}")"
  echo
  echo "[Neovim]"
  echo "配置仓库:             ${NVIM_REPO}"
  echo "实际下载地址:         $(github_proxy_url "${NVIM_REPO}")"
  echo "配置分支:             ${NVIM_BRANCH:-默认分支}"
  echo "同步插件:             $(bool_text "${SYNC_NVIM_PLUGINS}")"
  echo
  echo "[Zsh / 字体 / Docker / Hyprland]"
  echo "Powerlevel10k:        $(bool_text "${INSTALL_POWERLEVEL10K}")"
  echo "p10k 配置:            $(bool_text "${INSTALL_P10K_CONFIG}")"
  echo "切换默认 shell:       $(bool_text "${SET_ZSH_AS_DEFAULT}")"
  echo "Monaco 字体:          $(bool_text "${INSTALL_MONACO_FONT}")"
  echo "Docker 镜像源:        $(bool_text "${CONFIGURE_DOCKER_MIRRORS}")"
  echo "Hyprland SDDM:        $(bool_text "${ENABLE_SDDM}")"
  echo "GPU 类型:             ${GPU_TYPE}"
  echo "VMware 软件渲染:      $(bool_text "${VMWARE_FORCE_SOFTWARE_RENDERER:-1}")"
  echo "VM 动态分辨率:        $(bool_text "${VM_HYPRLAND_DYNAMIC_RESIZE:-1}")"
  echo "VM 低延迟配置:        $(bool_text "${VM_HYPRLAND_LOW_LATENCY:-1}")"
  echo "VM 显示 fallback:     ${VM_HYPRLAND_MONITOR_MODE:-${VMWARE_HYPRLAND_MONITOR_MODE:-1920x1080@60}}"
  echo "Hyprland 配置模式:    ${HYPRLAND_CONFIG_MODE}"
  if hyprdots_mode_enabled; then
    echo "hyprdots 来源提交:    ${HYPRDOTS_SOURCE_COMMIT:-unknown}"
    echo "hyprdots 配置目录:    ${HYPRDOTS_SOURCE_DIR}"
    echo "hyprdots 本地脚本:    ${HYPRDOTS_LOCAL_BIN_DIR}"
    echo "hyprdots 壁纸目录:    ${HYPRDOTS_WALLPAPER_DIR}"
    echo "hyprdots Obsidian:    $(bool_text "${INSTALL_HYPRDOTS_OBSIDIAN}")"
  fi
  echo "浏览器安装包:         ${BROWSER_PACKAGE}"
  echo "浏览器启动命令:       ${BROWSER_APP}"
  echo "终端启动命令:         ${TERMINAL_APP}"
  echo "Neovide 包装命令:     ${HOME}/.local/bin/neovide"
  echo "输入法框架:           Fcitx5 $(bool_text "${ENABLE_FCITX5}")"
  echo "输入法引擎:           ${INPUT_METHOD_ENGINE}"
  echo "Rime 默认方案:        ${RIME_SCHEMA}"
  echo "Rime 配置仓库:        ${RIME_CONFIG_REPO:-不安装}"
  echo "Rime 配置分支:        ${RIME_CONFIG_BRANCH:-默认分支}"
  echo "Rime 配置目录:        ${RIME_CONFIG_DIR}"
  echo "安装 Rime 配置:       $(bool_text "${INSTALL_RIME_CONFIG}")"
  echo
  echo "[Proxy]"
  echo "随 dev/workstation 安装: $(bool_text "${ENABLE_PROXY}")"
  echo "代理核心:             ${PROXY_CORE}"
  echo "自动启用服务:         $(bool_text "${PROXY_AUTO_ENABLE_SERVICE}")"
  echo "Mihomo 包:            ${MIHOMO_PACKAGE}"
  echo "Mihomo 系统服务:      ${MIHOMO_SERVICE_NAME:-mihomo.service}"
  echo "Mihomo 配置目录:      ${MIHOMO_CONFIG_DIR:-/etc/mihomo}"
  echo "Mihomo 配置文件:      ${MIHOMO_CONFIG_FILE:-/etc/mihomo/config.yaml}"
  echo "Mihomo 配置来源:      ${MIHOMO_CONFIG_SOURCE:-生成基础模板}"
  echo "Mihomo 规则源:        原始 URL（不配置代理前缀）"
  echo "Mihomo mixed-port:    ${MIHOMO_MIXED_PORT}"
  echo "Mihomo allow-lan:     $(bool_text "${MIHOMO_ALLOW_LAN}")"
  echo "Mihomo bind-address:  ${MIHOMO_BIND_ADDRESS}"
  echo "Mihomo 控制接口:      http://${MIHOMO_CONTROLLER_HOST}:${MIHOMO_CONTROLLER_PORT}"
  echo "Mihomo DNS 监听:      ${MIHOMO_DNS_LISTEN}"
  if [[ "${PROXY_CORE:-mihomo}" == "mihomo" ]]; then
    echo "MetaCubeXD:           $(bool_text "${ENABLE_METACUBEXD}")"
    echo "MetaCubeXD UI 目录:   ${MIHOMO_EXTERNAL_UI_DIR:-${MIHOMO_STATE_DIR:-/var/lib/mihomo}/ui}"
    echo "MetaCubeXD 地址:      http://${MIHOMO_CONTROLLER_HOST}:${MIHOMO_CONTROLLER_PORT}/ui/"
  fi
  echo "sing-box 包:          ${SING_BOX_PACKAGE}"
  echo "sing-box 配置来源:    ${SING_BOX_CONFIG_SOURCE:-生成基础模板}"
  echo "sing-box mixed-port:  ${SING_BOX_MIXED_PORT}"
  show_config_warnings_text
  echo "----------------------------------------------------------"
}

plan_has_module() {
  local modules_text="$1" wanted m
  wanted="$(module_key "$2")"
  for m in ${modules_text}; do
    [[ "$(module_key "${m}")" == "${wanted}" ]] && return 0
  done
  return 1
}

append_plan_module() {
  local modules_text="$1" module="$2" wanted existing
  wanted="$(module_key "${module}")"
  for existing in ${modules_text}; do
    [[ "$(module_key "${existing}")" == "${wanted}" ]] && {
      echo "${modules_text}"
      return 0
    }
  done

  if [[ -z "${modules_text}" ]]; then
    echo "${wanted}"
  else
    echo "${modules_text} ${wanted}"
  fi
}

modules_for_shell() {
  local modules=""
  if shell_needs_fonts; then
    modules="$(append_plan_module "${modules}" "fonts")"
  fi
  modules="$(append_plan_module "${modules}" "shell")"
  echo "${modules}"
}

modules_for_desktop() {
  local modules=""
  if desktop_needs_archlinuxcn; then
    modules="$(append_plan_module "${modules}" "archlinuxcn")"
  fi
  if desktop_needs_fonts; then
    modules="$(append_plan_module "${modules}" "fonts")"
  fi
  modules="$(append_plan_module "${modules}" "desktop")"
  echo "${modules}"
}

modules_for_proxy() {
  local modules=""
  if proxy_needs_archlinuxcn; then
    modules="$(append_plan_module "${modules}" "archlinuxcn")"
  fi
  modules="$(append_plan_module "${modules}" "proxy")"
  echo "${modules}"
}

modules_for_dev() {
  local module modules=""

  modules="$(append_plan_module "${modules}" "base")"
  if [[ "${INSTALL_ARCHLINUXCN:-0}" -eq 1 ]]; then
    modules="$(append_plan_module "${modules}" "archlinuxcn")"
  fi
  if [[ "${ENABLE_DNS:-0}" -eq 1 ]]; then
    modules="$(append_plan_module "${modules}" "dns")"
  fi
  modules="$(append_plan_module "${modules}" "git")"
  modules="$(append_plan_module "${modules}" "runtime")"
  modules="$(append_plan_module "${modules}" "nvim")"
  modules="$(append_plan_module "${modules}" "fonts")"
  modules="$(append_plan_module "${modules}" "shell")"

  if [[ "${ENABLE_PROXY:-0}" -eq 1 ]]; then
    for module in $(modules_for_proxy); do
      modules="$(append_plan_module "${modules}" "${module}")"
    done
  fi

  echo "${modules}"
}

modules_for_workstation() {
  local module modules

  modules="$(modules_for_dev)"
  for module in $(modules_for_desktop); do
    modules="$(append_plan_module "${modules}" "${module}")"
  done

  echo "${modules}"
}

modules_for_target() {
  case "$1" in
    base|dns|archlinuxcn|git|runtime|nvim|docker|fonts) module_key "$1" ;;
    shell|zsh) modules_for_shell ;;
    proxy) modules_for_proxy ;;
    desktop|hyprland) modules_for_desktop ;;
    dev) modules_for_dev ;;
    workstation) modules_for_workstation ;;
    *) die "未知安装目标：$1" ;;
  esac
}

plan_uses_github_proxy() {
  local modules_text="$1"

  plan_has_module "${modules_text}" "nvim" && return 0
  if plan_has_module "${modules_text}" "shell" && shell_needs_repo_clone; then
    return 0
  fi
  if plan_has_module "${modules_text}" "desktop" && desktop_needs_rime_repo; then
    return 0
  fi

  return 1
}

plan_needs_git_command() {
  local modules_text="$1"

  plan_has_module "${modules_text}" "nvim" && return 0
  if plan_has_module "${modules_text}" "shell" && shell_needs_repo_clone; then
    return 0
  fi
  if plan_has_module "${modules_text}" "desktop" && desktop_needs_rime_repo; then
    return 0
  fi

  return 1
}

show_plan_json() {
  local title="$1" modules_text="$2" module first=1
  printf '{'
  json_metadata_fields "plan"; printf ','
  printf '"target":'; json_string "${title}"; printf ','
  printf '"stateEnabled":'; json_bool "$(state_enabled && echo 1 || echo 0)"; printf ','
  printf '"force":'; json_bool "${FORCE_INSTALL}"; printf ','
  printf '"stateDir":'; json_string "$(state_root)"; printf ','
  printf '"warnings":'; json_warnings_array; printf ','
  printf '"modules":['
  for module in ${modules_text}; do
    [[ "${first}" -eq 1 ]] || printf ','
    first=0
    printf '{"name":'; json_string "$(module_display_key "${module}")"
    printf ',"key":'; json_string "$(module_key "${module}")"
    printf ',"description":'; json_string "$(module_desc "${module}")"
    printf '}'
  done
  printf ']}'
  printf '\n'
}

show_plan() {
  local title="$1" modules_text="$2"
  if [[ "${OUTPUT_JSON:-0}" -eq 1 ]]; then
    show_plan_json "${title}" "${modules_text}"
    return 0
  fi

  echo "----------------------------------------------------------"
  echo "[本次安装计划]"
  echo "安装目标: ${title}"
  echo "状态目录: $(state_root)"
  echo "模块状态: $(state_enabled && echo "启用" || echo "关闭")"
  echo "强制重跑: $(bool_text "${FORCE_INSTALL}")"
  echo "恢复模式: $(bool_text "${RESUME_INSTALL}")"
  show_config_warnings_text
  echo
  echo "将执行模块:"
  local m
  for m in ${modules_text}; do
    echo "  - $(module_display_key "${m}") ($(module_desc "${m}"))"
  done
  echo
  echo "主要影响:"
  local impact
  for m in ${modules_text}; do
    while IFS= read -r impact; do
      [[ -n "${impact}" ]] || continue
      echo "  - $(module_display_key "${m}"): ${impact}"
    done < <(module_impacts "${m}")
  done
  echo
  echo "关键配置:"
  echo "  软件安装:         按模块批量执行 pacman -S --needed，缺包再兜底 archlinuxcn/AUR"
  if plan_has_module "${modules_text}" "base"; then
    echo "  系统更新:         base 模块会刷新并执行 pacman -Syu"
    echo "  基础工具:         $(base_packages)"
    echo "  AUR 助手:         优先使用 paru，同时安装 yay 供手动使用"
  fi
  if plan_has_module "${modules_text}" "archlinuxcn"; then
    echo "  archlinuxcn 源:   ${ARCHLINUXCN_SERVER}"
    echo "  mirrorlist 包:    $(bool_text "${INSTALL_ARCHLINUXCN_MIRRORLIST}")"
  fi
  if plan_has_module "${modules_text}" "dns"; then
    echo "  系统 DNS:         systemd-resolved"
    echo "  DNS 服务器:       ${DNS_SERVERS[*]}"
    echo "  DNS fallback:     ${DNS_FALLBACK_SERVERS[*]}"
    echo "  DNS 国外 fallback: ${DNS_FOREIGN_FALLBACK_SERVERS[*]}"
    echo "  DNSOverTLS:       ${DNS_OVER_TLS}"
  fi
  if plan_has_module "${modules_text}" "git"; then
    echo "  Git 默认分支:     main"
    echo "  GitHub CLI:       安装 gh，登录需稍后手动执行 gh auth login"
  fi
  if plan_has_module "${modules_text}" "runtime"; then
    echo "  系统运行时:       pacman 安装 nodejs/npm/python/python-pip/go"
    echo "  系统包:           mise nodejs npm python python-pip go$( [[ "${ENABLE_COREPACK:-0}" -eq 1 ]] && printf ' corepack' )"
    echo "  管理工具:         ${RUNTIME_MANAGER}（只配置，不默认执行 mise use）"
    echo "  mise 目标版本:    node ${NODE_VERSION} / python ${PYTHON_VERSION} / go ${GO_VERSION}"
    echo "  npm 目标版本:     ${NPM_VERSION}（仅保留配置兼容）"
    echo "  npm 源:           ${NPM_REGISTRY}"
    echo "  pip 源:           ${PIP_INDEX_URL}"
    echo "  Node 下载镜像:    ${NODE_MIRROR_URL}（手动 mise use）"
    echo "  Go 下载镜像:      ${GO_DOWNLOAD_MIRROR}（手动 mise use）"
    echo "  Python 下载镜像:  ${PYTHON_BUILD_MIRROR_URL}（手动 mise use）"
    echo "  pyenv 实际仓库:   $(mise_pyenv_repo_url)"
    echo "  Corepack:         $(bool_text "${ENABLE_COREPACK}")"
  fi
  if plan_uses_github_proxy "${modules_text}"; then
    echo "  GitHub 代理:      $(bool_text "${ENABLE_GITHUB_PROXY}")"
    echo "  GitHub 代理地址:  ${GITHUB_PROXY}"
  fi
  if plan_needs_git_command "${modules_text}" && \
    ! plan_has_module "${modules_text}" "git" && \
    ! plan_has_module "${modules_text}" "base"; then
    echo "  Git 命令依赖:     如缺失会按需安装 git 包"
  fi
  if plan_has_module "${modules_text}" "nvim"; then
    echo "  Neovim 仓库:      ${NVIM_REPO}"
    echo "  Neovim 实际下载:  $(github_proxy_url "${NVIM_REPO}")"
    echo "  插件同步:         $(bool_text "${SYNC_NVIM_PLUGINS}")"
  fi
  if plan_has_module "${modules_text}" "docker"; then
    echo "  Docker 服务:      $(bool_text "${ENABLE_DOCKER_SERVICE}")"
    echo "  加入 docker 组:   $(bool_text "${ADD_USER_TO_DOCKER_GROUP}")"
    echo "  Docker 镜像源:    $(bool_text "${CONFIGURE_DOCKER_MIRRORS}")"
  fi
  if plan_has_module "${modules_text}" "fonts"; then
    echo "  中文/Emoji 字体:  $(bool_text "${INSTALL_CN_FONTS}")"
    echo "  Nerd Font:        $(bool_text "${INSTALL_NERD_FONTS}")"
    echo "  Monaco 字体:      $(bool_text "${INSTALL_MONACO_FONT}")"
  fi
  if plan_has_module "${modules_text}" "shell"; then
    echo "  Oh My Zsh:        $(bool_text "${INSTALL_OH_MY_ZSH}")"
    echo "  Powerlevel10k:    $(bool_text "${INSTALL_POWERLEVEL10K}")"
    echo "  p10k 配置:        $(bool_text "${INSTALL_P10K_CONFIG}")"
    echo "  切换默认 shell:   $(bool_text "${SET_ZSH_AS_DEFAULT}")"
  fi
  if plan_has_module "${modules_text}" "desktop"; then
    echo "  Hyprland SDDM:    $(bool_text "${ENABLE_SDDM}")"
    echo "  GPU 类型:         ${GPU_TYPE}"
    echo "  VMware 软件渲染:  $(bool_text "${VMWARE_FORCE_SOFTWARE_RENDERER:-1}")"
    echo "  VM 动态分辨率:    $(bool_text "${VM_HYPRLAND_DYNAMIC_RESIZE:-1}")"
    echo "  VM 低延迟配置:    $(bool_text "${VM_HYPRLAND_LOW_LATENCY:-1}")"
    echo "  Hyprland 配置:    ${HYPRLAND_CONFIG_MODE}"
    if hyprdots_mode_enabled; then
      echo "  hyprdots 提交:    ${HYPRDOTS_SOURCE_COMMIT:-unknown}"
      echo "  Obsidian:         $(bool_text "${INSTALL_HYPRDOTS_OBSIDIAN}")"
    fi
    echo "  Neovide:          安装并写入 ~/.local/bin/neovide 包装命令"
    echo "  浏览器包/命令:    ${BROWSER_PACKAGE} / ${BROWSER_APP}"
    echo "  输入法:           Fcitx5 $(bool_text "${ENABLE_FCITX5}") / ${INPUT_METHOD_ENGINE}"
    if [[ "${INPUT_METHOD_ENGINE:-rime}" == "rime" ]]; then
      echo "  Rime 方案:        ${RIME_SCHEMA}"
      echo "  Rime 配置:        $(bool_text "${INSTALL_RIME_CONFIG}") / ${RIME_CONFIG_REPO:-未设置}"
    fi
  fi
  if plan_has_module "${modules_text}" "proxy"; then
    echo "  Proxy 核心:       ${PROXY_CORE}"
    echo "  自动启用服务:     $(bool_text "${PROXY_AUTO_ENABLE_SERVICE}")"
    if [[ "${PROXY_CORE:-mihomo}" == "mihomo" ]]; then
      echo "  Mihomo 配置:      ${MIHOMO_CONFIG_FILE:-/etc/mihomo/config.yaml}"
      echo "  Mihomo 服务:      ${MIHOMO_SERVICE_NAME:-mihomo.service}"
      echo "  规则源:           原始 URL（不配置代理前缀）"
      echo "  MetaCubeXD:       $(bool_text "${ENABLE_METACUBEXD}")"
    else
      echo "  sing-box 配置:    ${SING_BOX_CONFIG_FILE:-${HOME}/.config/sing-box/config.json}"
      echo "  sing-box 服务:    archdevkit-sing-box.service"
    fi
  fi
  echo "----------------------------------------------------------"
}

state_root() {
  printf "%s" "${ARCHDEVKIT_STATE_DIR:-${HOME}/.local/state/archdevkit}"
}

state_enabled() {
  [[ "${ARCHDEVKIT_USE_STATE:-1}" -eq 1 && "${NO_STATE:-0}" -ne 1 ]]
}

state_prepare_dirs() {
  state_enabled || return 0
  [[ "${DRY_RUN:-0}" -eq 1 ]] && return 0
  mkdir -p "$(state_root)/modules" "$(state_root)/logs"
}

module_state_file() {
  printf "%s/modules/%s.state" "$(state_root)" "$(module_key "$1")"
}

read_state_value() {
  local file="$1" key="$2"
  [[ -f "${file}" ]] || return 1
  awk -F= -v key="${key}" '$1 == key {print substr($0, length(key) + 2); exit}' "${file}"
}

module_state_valid() {
  local module file expected_hash actual_status actual_hash
  module="$(module_key "$1")"
  state_enabled || return 1
  file="$(module_state_file "${module}")"
  [[ -f "${file}" ]] || return 1

  actual_status="$(read_state_value "${file}" "status" || true)"
  actual_hash="$(read_state_value "${file}" "config_hash" || true)"
  expected_hash="$(module_config_fingerprint "${module}")"
  [[ "${actual_status}" == "success" && "${actual_hash}" == "${expected_hash}" ]] || return 1
  module_quick_verify "${module}"
}

mark_module_installed() {
  local module file commit
  module="$(module_key "$1")"
  state_enabled || return 0
  [[ "${DRY_RUN:-0}" -eq 1 ]] && return 0
  state_prepare_dirs
  file="$(module_state_file "${module}")"
  commit="$(git -C "${SCRIPT_DIR}" rev-parse --short HEAD 2>/dev/null || printf unknown)"
  {
    printf 'module=%s\n' "${module}"
    printf 'status=success\n'
    printf 'installed_at=%s\n' "$(date -Iseconds)"
    printf 'script_commit=%s\n' "${commit}"
    printf 'config_hash=%s\n' "$(module_config_fingerprint "${module}")"
  } > "${file}"
}

mark_skipped() {
  local module existing
  module="$(module_key "$1")"
  for existing in ${MODULE_SKIPPED_LIST}; do
    [[ "${existing}" == "${module}" ]] && return 0
  done
  MODULE_SKIPPED_LIST="${MODULE_SKIPPED_LIST} ${module}"
}

is_skipped() {
  local module existing
  module="$(module_key "$1")"
  for existing in ${MODULE_SKIPPED_LIST}; do
    [[ "${existing}" == "${module}" ]] && return 0
  done
  return 1
}

reset_module_state() {
  local target="$1" module file
  state_prepare_dirs
  if [[ "${target}" == "all" ]]; then
    rm -f "$(state_root)"/modules/*.state 2>/dev/null || true
    log_info "已清除所有模块状态"
    return 0
  fi
  for module in $(modules_for_target "${target}"); do
    file="$(module_state_file "${module}")"
    rm -f "${file}"
    log_info "已清除模块状态：$(module_display_key "${module}")"
  done
}

run_plan() {
  local modules_text="$1" total index=0 module display
  state_prepare_dirs
  total="$(wc -w <<<"${modules_text}" | tr -d ' ')"
  for module in ${modules_text}; do
    module="$(module_key "${module}")"
    display="$(module_display_key "${module}")"
    index=$((index + 1))
    if [[ "${FORCE_INSTALL:-0}" -ne 1 ]] && module_state_valid "${module}"; then
      log_info "[${index}/${total}] ${display} 已安装且校验通过，跳过"
      mark_done "${module}"
      mark_skipped "${module}"
      continue
    fi

    log_info "[${index}/${total}] 开始处理 ${display}：$(module_desc "${module}")"
    set_current_module "${module}" "${index}" "${total}"
    module_install_func "${module}"
    mark_module_installed "${module}"
    clear_current_module
    log_info "[${index}/${total}] ${display} 处理完成"
  done
}

start_run_log() {
  [[ "${DRY_RUN:-0}" -eq 1 ]] && return 0
  state_prepare_dirs
  ARCHDEVKIT_LOG_FILE="$(state_root)/logs/$(date +%Y%m%d-%H%M%S)-${TARGET}.log"
  exec > >(tee -a "${ARCHDEVKIT_LOG_FILE}") 2>&1
  log_info "本次安装日志：${ARCHDEVKIT_LOG_FILE}"
}

preflight_install() {
  local modules_text="$1"
  log_info "执行安装前检查"
  require_arch
  require_cmd pacman
  require_cmd sudo
  if plan_needs_git_command "${modules_text}" && ! need_cmd git; then
    log_warn "当前缺少 git，相关模块会在执行时按需安装 git 包"
  fi
  if plan_has_module "${modules_text}" "proxy" && \
     [[ "${MIHOMO_CONTROLLER_HOST:-127.0.0.1}" == "0.0.0.0" && -z "${MIHOMO_SECRET:-}" ]]; then
    log_warn "Mihomo 控制接口监听 0.0.0.0 且 secret 为空；这是当前默认值，但局域网可访问控制 API"
  fi
}

show_summary() {
  echo
  echo "----------------------------------------------------------"
  echo "[执行完成]"
  [[ -n "${ARCHDEVKIT_LOG_FILE:-}" ]] && echo "日志文件: ${ARCHDEVKIT_LOG_FILE}"
  echo "已处理模块:"
  local key display_key
  for key in $(all_modules); do
    display_key="$(module_display_key "${key}")"
    is_done "${key}" && echo "  - ${display_key} ($(module_desc "${key}"))$(is_skipped "${key}" && printf '：已跳过')"
  done
  echo
  echo "后续建议:"
  local tip_no=0 done_count=0
  for key in $(all_modules); do
    is_done "${key}" && done_count=$((done_count + 1))
  done
  add_summary_tip() {
    tip_no=$((tip_no + 1))
    echo "${tip_no}. $*"
  }

  if is_done "base" && [[ "${done_count}" -eq 1 ]]; then
    add_summary_tip "基础工具已经就绪；接下来可按需运行 runtime、nvim、docker、desktop 或 workstation。"
    add_summary_tip "如果刚完成系统大版本更新，建议重启一次后再继续安装桌面或显卡相关模块。"
  fi
  if is_done "archlinuxcn"; then
    add_summary_tip "archlinuxcn 源已配置；若后续软件查不到，先执行 sudo pacman -Syu 再重试。"
  fi
  if is_done "dns"; then
    add_summary_tip "系统 DNS 已交给 systemd-resolved；查看状态可执行：resolvectl status。"
  fi
  if is_done "git"; then
    add_summary_tip "如需使用 GitHub CLI 登录，执行：gh auth login && gh auth setup-git。"
  fi
  if is_done "runtime"; then
    add_summary_tip "系统 Node.js/npm/Python/Go 已可直接使用；重新打开终端，或执行 exec \"\$SHELL\"，让 mise activation 生效。"
  fi
  if is_done "nvim"; then
    add_summary_tip "首次打开 Neovim 会加载插件；如果同步失败，可执行：nvim +Lazy sync。"
  fi
  if is_done "docker"; then
    if [[ "${ADD_USER_TO_DOCKER_GROUP:-0}" -eq 1 ]]; then
      add_summary_tip "当前用户已加入 docker 组；请注销或重启后再直接运行 docker 命令。"
    fi
    add_summary_tip "Docker 服务状态可用 sudo systemctl status docker 查看。"
  fi
  if is_done "fonts"; then
    add_summary_tip "字体缓存已刷新；若终端或浏览器仍未显示新字体，重启对应应用即可。"
  fi
  if is_done "shell_zsh"; then
    add_summary_tip "Zsh 配置已写入 ~/.zshrc；默认 shell 切换需要重新登录后生效。"
  fi
  if is_done "desktop_hyprland"; then
    if [[ "${ENABLE_SDDM:-0}" -eq 1 ]]; then
      add_summary_tip "SDDM 已启用；重启后在登录界面选择 Hyprland 会话。"
    else
      add_summary_tip "Hyprland 已安装但未启用 SDDM；可用 Hyprland 命令从 tty 手动启动会话。"
    fi
  fi
  if is_done "proxy"; then
    case "${PROXY_CORE:-mihomo}" in
      mihomo)
        add_summary_tip "Mihomo 配置文件：${MIHOMO_CONFIG_FILE:-/etc/mihomo/config.yaml}。"
        add_summary_tip "Mihomo 服务状态可用 sudo systemctl status ${MIHOMO_SERVICE_NAME:-mihomo.service} 查看。"
        ;;
      sing-box)
        add_summary_tip "sing-box 配置文件：${SING_BOX_CONFIG_FILE:-${HOME}/.config/sing-box/config.json}。"
        add_summary_tip "sing-box 服务状态可用 systemctl --user status archdevkit-sing-box 查看。"
        ;;
    esac
  fi
  add_summary_tip "查看模块状态可执行：bash install.sh status。"
  if [[ "${tip_no}" -eq 0 ]]; then
    add_summary_tip "没有额外动作需要处理。"
  fi
  echo "----------------------------------------------------------"
}

confirm_and_run_target() {
  local target="$1" modules_text
  modules_text="$(modules_for_target "${target}")"
  show_plan "${target}" "${modules_text}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log_warn "当前为 dry-run 模式，只显示计划，不执行安装"
    return 0
  fi
  if [[ "${ASSUME_YES:-0}" -eq 1 ]] || confirm_yes "是否按以上计划继续安装？"; then
    start_run_log
    enable_install_recovery
    set_install_phase "preflight"
    preflight_install "${modules_text}"
    run_plan "${modules_text}"
    disable_install_recovery
    show_summary
  else
    log_warn "已取消安装：${target}"
  fi
}

state_status_text() {
  local module file status hash expected ok display
  echo "----------------------------------------------------------"
  echo "[ArchDevKit 模块状态]"
  echo "状态目录: $(state_root)"
  echo
  printf "%-18s %-10s %-10s %s\n" "模块" "状态" "校验" "说明"
  for module in "$@"; do
    module="$(module_key "${module}")"
    display="$(module_display_key "${module}")"
    file="$(module_state_file "${module}")"
    status="missing"
    hash="-"
    [[ -f "${file}" ]] && status="$(read_state_value "${file}" "status" || echo unknown)"
    expected="$(module_config_fingerprint "${module}")"
    if [[ -f "${file}" ]]; then
      hash="$(read_state_value "${file}" "config_hash" || echo unknown)"
    fi
    if [[ -f "${file}" && "${hash}" == "${expected}" ]] && module_quick_verify "${module}"; then
      ok="ok"
    elif [[ -f "${file}" && "${hash}" != "${expected}" ]]; then
      ok="changed"
    else
      ok="check-failed"
    fi
    [[ "${status}" == "missing" ]] && ok="-"
    printf "%-18s %-10s %-10s %s\n" "${display}" "${status}" "${ok}" "$(module_desc "${module}")"
  done
  echo "----------------------------------------------------------"
}

state_status_json() {
  local module file status hash expected ok first=1
  printf '{'
  json_metadata_fields "status"; printf ','
  printf '"stateDir":'; json_string "$(state_root)"; printf ','
  printf '"warnings":'; json_warnings_array; printf ','
  printf '"modules":['
  for module in "$@"; do
    module="$(module_key "${module}")"
    file="$(module_state_file "${module}")"
    status="missing"
    hash="-"
    [[ -f "${file}" ]] && status="$(read_state_value "${file}" "status" || echo unknown)"
    expected="$(module_config_fingerprint "${module}")"
    if [[ -f "${file}" ]]; then
      hash="$(read_state_value "${file}" "config_hash" || echo unknown)"
    fi
    if [[ -f "${file}" && "${hash}" == "${expected}" ]] && module_quick_verify "${module}"; then
      ok="ok"
    elif [[ -f "${file}" && "${hash}" != "${expected}" ]]; then
      ok="changed"
    else
      ok="check-failed"
    fi
    [[ "${status}" == "missing" ]] && ok="missing"
    [[ "${first}" -eq 1 ]] || printf ','
    first=0
    printf '{"key":'; json_string "${module}"
    printf ',"name":'; json_string "$(module_display_key "${module}")"
    printf ',"status":'; json_string "${status}"
    printf ',"check":'; json_string "${ok}"
    printf '}'
  done
  printf ']}\n'
}

show_status() {
  local modules=()
  if [[ "${TARGET}" == "all" ]]; then
    read -r -a modules <<<"$(all_modules)"
  else
    read -r -a modules <<<"$(modules_for_target "${TARGET}")"
  fi

  if [[ "${OUTPUT_JSON:-0}" -eq 1 ]]; then
    state_status_json "${modules[@]}"
  else
    state_status_text "${modules[@]}"
  fi
}

ask_value_default() {
  local prompt="$1" current="$2" answer
  read -r -p "${prompt} [${current}]: " answer
  printf "%s" "${answer:-${current}}"
}

ask_bool_default() {
  local prompt="$1" current="$2" answer
  if [[ "${current:-0}" -eq 1 ]]; then
    read -r -p "${prompt} [Y/n]: " answer
    case "${answer}" in
      n|N|no|NO|No) printf "0" ;;
      *) printf "1" ;;
    esac
  else
    read -r -p "${prompt} [y/N]: " answer
    case "${answer}" in
      y|Y|yes|YES|Yes) printf "1" ;;
      *) printf "0" ;;
    esac
  fi
}

ask_choice_default() {
  local prompt="$1" current="$2" choices="$3" answer choice
  while true; do
    read -r -p "${prompt} [${current}] (${choices}): " answer
    answer="${answer:-${current}}"
    for choice in ${choices}; do
      if [[ "${answer}" == "${choice}" ]]; then
        printf "%s" "${answer}"
        return 0
      fi
    done
    printf '\033[33m----> 请输入可选值之一：%s\033[0m\n' "${choices}" >&2
  done
}

show_menu() {
  clear || true
  echo "----------------------------------------------------------"
  echo "[ArchDevKit 交互式安装向导]"
  echo "直接回车会使用 install_vars 中的默认值。"
  echo "----------------------------------------------------------"
  menu_target_overview

  TARGET="$(ask_choice_default "选择安装目标" "${TARGET}" "base dev workstation custom dns archlinuxcn git runtime nvim docker fonts shell desktop proxy")"
  if [[ "${TARGET}" == "custom" ]]; then
    TARGET="$(ask_choice_default "选择自定义起点" "workstation" "base dev workstation dns archlinuxcn git runtime nvim docker fonts shell desktop proxy")"
  fi

  if [[ "${TARGET}" == "dev" || "${TARGET}" == "workstation" ]]; then
    INSTALL_ARCHLINUXCN="$(ask_bool_default "启用 archlinuxcn 源" "${INSTALL_ARCHLINUXCN:-1}")"
    ENABLE_DNS="$(ask_bool_default "配置系统 DNS" "${ENABLE_DNS:-1}")"
    ENABLE_PROXY="$(ask_bool_default "安装 Proxy 模块" "${ENABLE_PROXY:-1}")"
  fi

  if [[ "${TARGET}" == "proxy" || ( "${TARGET}" =~ ^(dev|workstation)$ && "${ENABLE_PROXY:-0}" -eq 1 ) ]]; then
    PROXY_CORE="$(ask_choice_default "代理核心" "${PROXY_CORE:-mihomo}" "mihomo sing-box")"
    PROXY_AUTO_ENABLE_SERVICE="$(ask_bool_default "安装后自动启用代理服务" "${PROXY_AUTO_ENABLE_SERVICE:-1}")"
    if [[ "${PROXY_CORE}" == "mihomo" ]]; then
      ENABLE_METACUBEXD="$(ask_bool_default "安装 MetaCubeXD 面板" "${ENABLE_METACUBEXD:-1}")"
    fi
  fi

  if [[ "${TARGET}" == "desktop" || "${TARGET}" == "workstation" ]]; then
    GPU_TYPE="$(ask_choice_default "GPU 类型" "${GPU_TYPE:-auto}" "auto intel amd nvidia vmware virtio qxl virtualbox none")"
    ENABLE_SDDM="$(ask_bool_default "启用 SDDM 登录管理器" "${ENABLE_SDDM:-1}")"
    HYPRLAND_CONFIG_MODE="$(ask_choice_default "Hyprland 配置模式" "${HYPRLAND_CONFIG_MODE:-hyprdots}" "hyprdots template skip")"
    ENABLE_FCITX5="$(ask_bool_default "启用 Fcitx5 输入法" "${ENABLE_FCITX5:-1}")"
    if [[ "${ENABLE_FCITX5:-0}" -eq 1 ]]; then
      INPUT_METHOD_ENGINE="$(ask_choice_default "输入法引擎" "${INPUT_METHOD_ENGINE:-rime}" "rime pinyin")"
      if [[ "${INPUT_METHOD_ENGINE}" == "rime" ]]; then
        RIME_SCHEMA="$(ask_value_default "Rime 默认方案" "${RIME_SCHEMA:-luna_pinyin_simp}")"
        INSTALL_RIME_CONFIG="$(ask_bool_default "安装 Rime 配置仓库" "${INSTALL_RIME_CONFIG:-1}")"
      fi
    fi
    BROWSER_PACKAGE="$(ask_value_default "浏览器安装包" "${BROWSER_PACKAGE:-google-chrome}")"
    BROWSER_APP="$(ask_value_default "浏览器启动命令" "${BROWSER_APP:-google-chrome-stable}")"
  fi

  validate_config
  confirm_and_run_target "${TARGET}"
}

main() {
  parse_config_file_args "$@"
  load_user_config_file
  TARGET="${ARCHDEVKIT_DEFAULT_PROFILE:-workstation}"
  parse_args "$@"
  validate_config

  case "${ACTION}" in
    help) show_help ;;
    config) show_config ;;
    plan)
      show_plan "${TARGET}" "$(modules_for_target "${TARGET}")"
      ;;
    status)
      show_status
      ;;
    doctor)
      show_doctor
      ;;
    reset-state)
      reset_module_state "${TARGET}"
      ;;
    menu)
      require_normal_user
      require_cmd sudo
      show_menu
      ;;
    install)
      require_normal_user
      require_cmd sudo
      confirm_and_run_target "${TARGET}"
      ;;
    *)
      die "未知动作：${ACTION}"
      ;;
  esac
}

main "$@"
