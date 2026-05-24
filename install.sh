#!/usr/bin/env bash
set -Eeuo pipefail

# ArchDevKit 主入口
# 负责加载配置、解析参数、显示菜单、展示计划并编排各个模块。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/install_vars"
source "${SCRIPT_DIR}/lib/common.sh"
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

COMMAND="menu"

show_help() {
  cat <<'EOF'
ArchDevKit - Arch Linux 工作站初始化工具

用法：
  bash install.sh
  bash install.sh config
  bash install.sh base|dns|archlinuxcn|git|runtime|nvim|docker|fonts|shell|desktop|proxy|dev|workstation

常用参数：
  -y, --yes                 自动确认
  --dry-run                 只显示计划，不执行
  --no-china                不配置 npm/pip 国内源
  --no-github-proxy         不使用 GitHub 代理
  --github-proxy URL        指定 GitHub 代理
  --node-mirror URL         指定 mise Node.js 下载镜像
  --go-mirror URL           指定 mise Go SDK 下载镜像
  --python-build-mirror URL 指定 python-build 下载镜像
  --pyenv-repo URL          指定 mise Python 使用的 pyenv 仓库
  --dns                     dev/workstation 中配置系统 DNS
  --no-dns                  dev/workstation 中跳过系统 DNS
  --dns-over-tls MODE       systemd-resolved DNSOverTLS：no / opportunistic / yes
  --repo URL                指定 Neovim 配置仓库
  --branch NAME             指定 Neovim 配置分支
  --no-plugin-sync          不同步 Neovim 插件
  --node-version VERSION    指定 Node.js 版本
  --npm-version VERSION     指定 npm 版本
  --python-version VERSION  指定 Python 版本
  --go-version VERSION      指定 Go 版本
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
  while [[ $# -gt 0 ]]; do
    case "$1" in
      base|dns|archlinuxcn|git|runtime|nvim|docker|fonts|shell|zsh|desktop|hyprland|proxy|dev|workstation|config|menu|help)
        COMMAND="$1"; shift ;;
      -y|--yes) ASSUME_YES=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
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
      -h|--help) COMMAND="help"; shift ;;
      *) die "未知参数：$1" ;;
    esac
  done
}

show_config() {
  echo "----------------------------------------------------------"
  echo "[当前安装配置]"
  echo "执行用户:             ${USER}"
  echo "dry-run:              $(bool_text "${DRY_RUN}")"
  echo "自动确认:             $(bool_text "${ASSUME_YES}")"
  echo
  echo "[中国大陆网络]"
  echo "启用国内源:           $(bool_text "${ENABLE_CHINA_MIRROR}")"
  echo "npm 源:               ${NPM_REGISTRY}"
  echo "pip 源:               ${PIP_INDEX_URL}"
  echo "mise Node 镜像:       ${NODE_MIRROR_URL}"
  echo "mise Go 镜像:         ${GO_DOWNLOAD_MIRROR}"
  echo "python-build 镜像:    ${PYTHON_BUILD_MIRROR_URL}"
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
  echo "管理工具:             ${RUNTIME_MANAGER}"
  echo "Node.js 版本:         ${NODE_VERSION}"
  echo "npm 版本:             ${NPM_VERSION}"
  echo "Python 版本:          ${PYTHON_VERSION}"
  echo "Go 版本:              ${GO_VERSION}"
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
  echo "Mihomo 规则源前缀:    $(mihomo_rule_provider_url_prefix)"
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
  echo "----------------------------------------------------------"
}

module_desc() {
  case "$1" in
    base) echo "基础环境" ;;
    dns) echo "系统 DNS" ;;
    archlinuxcn) echo "archlinuxcn 软件源" ;;
    git) echo "Git / GitHub CLI" ;;
    runtime) echo "mise + Node/npm/Python/Go" ;;
    nvim) echo "Neovim + 个人配置" ;;
    docker) echo "Docker / Compose" ;;
    fonts) echo "字体环境" ;;
    shell|shell_zsh) echo "Zsh / Oh My Zsh / Powerlevel10k" ;;
    desktop|desktop_hyprland) echo "Hyprland 桌面环境" ;;
    proxy) echo "Proxy 代理环境" ;;
    *) echo "$1" ;;
  esac
}

module_key() {
  case "$1" in
    shell|zsh) echo "shell_zsh" ;;
    desktop|hyprland) echo "desktop_hyprland" ;;
    *) echo "$1" ;;
  esac
}

plan_has_module() {
  local modules_text="$1" wanted
  wanted="$(module_key "$2")"
  local m
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
    echo "${module}"
  else
    echo "${modules_text} ${module}"
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

modules_for_command() {
  case "$1" in
    base) echo "base" ;;
    dns) echo "dns" ;;
    archlinuxcn) echo "archlinuxcn" ;;
    git) echo "git" ;;
    runtime) echo "runtime" ;;
    nvim) echo "nvim" ;;
    docker) echo "docker" ;;
    fonts) echo "fonts" ;;
    shell|zsh) modules_for_shell ;;
    proxy) modules_for_proxy ;;
    desktop|hyprland) modules_for_desktop ;;
    dev) modules_for_dev ;;
    workstation) modules_for_workstation ;;
    *) echo "$1" ;;
  esac
}

show_plan() {
  local title="$1" modules_text="$2"
  echo "----------------------------------------------------------"
  echo "[本次安装计划]"
  echo "安装目标: ${title}"
  echo
  echo "将执行模块:"
  local m
  for m in ${modules_text}; do
    echo "  - ${m} ($(module_desc "${m}"))"
  done
  echo
  echo "关键配置:"
  echo "  软件安装:         按模块批量执行 pacman -S --needed，缺包再兜底 archlinuxcn/AUR"
  if plan_has_module "${modules_text}" "base"; then
    echo "  系统更新:         base 模块会刷新并执行 pacman -Syu"
    echo "  基础工具:         base-devel git curl wget unzip tar gzip xz jq ripgrep fd fzf openssh"
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
    echo "  管理工具:         ${RUNTIME_MANAGER}"
    echo "  Node.js/npm:      ${NODE_VERSION} / ${NPM_VERSION}"
    echo "  Python/Go:        ${PYTHON_VERSION} / ${GO_VERSION}"
    echo "  npm 源:           ${NPM_REGISTRY}"
    echo "  pip 源:           ${PIP_INDEX_URL}"
    echo "  Node 下载镜像:    ${NODE_MIRROR_URL}"
    echo "  Go 下载镜像:      ${GO_DOWNLOAD_MIRROR}"
    echo "  Python 下载镜像:  ${PYTHON_BUILD_MIRROR_URL}"
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
      echo "  规则源前缀:       $(mihomo_rule_provider_url_prefix)"
      echo "  MetaCubeXD:       $(bool_text "${ENABLE_METACUBEXD}")"
    else
      echo "  sing-box 配置:    ${SING_BOX_CONFIG_FILE:-${HOME}/.config/sing-box/config.json}"
      echo "  sing-box 服务:    archdevkit-sing-box.service"
    fi
  fi
  echo "----------------------------------------------------------"
}

install_profile_dev() {
  install_base
  [[ "${INSTALL_ARCHLINUXCN:-0}" -eq 1 ]] && install_archlinuxcn
  ensure_dns_env
  install_git_env
  install_runtime_env
  install_nvim_env
  install_fonts
  install_shell_zsh
  ensure_proxy_env
}

install_profile_workstation() {
  install_profile_dev
  install_desktop_hyprland
}

run_command() {
  case "$1" in
    base) install_base ;;
    dns) install_dns_env ;;
    archlinuxcn) install_archlinuxcn ;;
    git) install_git_env ;;
    runtime) install_runtime_env ;;
    nvim) install_nvim_env ;;
    docker) install_docker_env ;;
    fonts) install_fonts ;;
    shell|zsh) install_shell_zsh ;;
    desktop|hyprland) install_desktop_hyprland ;;
    proxy) install_proxy_env ;;
    dev) install_profile_dev ;;
    workstation) install_profile_workstation ;;
    *) die "未知命令：$1" ;;
  esac
}

show_summary() {
  echo
  echo "----------------------------------------------------------"
  echo "[执行完成]"
  echo "已处理模块:"
  local key display_key
  for key in base dns archlinuxcn git runtime nvim docker fonts shell_zsh desktop_hyprland proxy; do
    display_key="${key}"
    [[ "${key}" == "shell_zsh" ]] && display_key="shell"
    [[ "${key}" == "desktop_hyprland" ]] && display_key="desktop"
    is_done "${key}" && echo "  - ${display_key} ($(module_desc "${key}"))"
  done
  echo
  echo "后续建议:"
  local tip_no=0 done_count=0
  for key in base dns archlinuxcn git runtime nvim docker fonts shell_zsh desktop_hyprland proxy; do
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
    if [[ "${DNS_RESTART_NETWORKMANAGER:-0}" -ne 1 ]]; then
      add_summary_tip "NetworkManager DNS 后端配置会在 NetworkManager 重启后完全生效。"
    fi
  fi
  if is_done "git"; then
    add_summary_tip "如需使用 GitHub CLI 登录，执行：gh auth login && gh auth setup-git。"
  fi
  if is_done "runtime"; then
    add_summary_tip "重新打开终端，或执行 exec \"\$SHELL\"，让 mise 的 Node.js/npm/Python/Go 配置生效。"
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
    if [[ "${ENABLE_FCITX5:-0}" -eq 1 ]]; then
      add_summary_tip "输入法环境变量已写入；如果 Rime/Fcitx5 未出现，注销重登后再打开 fcitx5-configtool 检查。"
    fi
    add_summary_tip "Neovide 需要图形会话；TTY/SSH 中请使用 nvim，Hyprland 会话中可直接运行 neovide。"
  fi
  if is_done "proxy"; then
    case "${PROXY_CORE:-mihomo}" in
      mihomo)
        add_summary_tip "Mihomo 配置文件：${MIHOMO_CONFIG_FILE:-/etc/mihomo/config.yaml}。"
        add_summary_tip "Mihomo 服务状态可用 sudo systemctl status ${MIHOMO_SERVICE_NAME:-mihomo.service} 查看。"
        if [[ "${ENABLE_METACUBEXD:-0}" -eq 1 ]]; then
          add_summary_tip "MetaCubeXD 面板地址：http://${MIHOMO_CONTROLLER_HOST:-127.0.0.1}:${MIHOMO_CONTROLLER_PORT:-9090}/ui/。"
        fi
        if [[ "${MIHOMO_CONFIG_SOURCE:-}" == "${SCRIPT_DIR}/files/mihomo/config.yaml.tpl" || -z "${MIHOMO_CONFIG_SOURCE:-}" ]]; then
          add_summary_tip "默认 Mihomo 模板含示例订阅地址；正式使用前请替换 proxy-providers.airport.url。"
        fi
        ;;
      sing-box)
        add_summary_tip "sing-box 配置文件：${SING_BOX_CONFIG_FILE:-${HOME}/.config/sing-box/config.json}。"
        add_summary_tip "sing-box 服务状态可用 systemctl --user status archdevkit-sing-box 查看。"
        ;;
    esac
  fi
  if [[ "${tip_no}" -eq 0 ]]; then
    add_summary_tip "没有额外动作需要处理。"
  fi
  echo "----------------------------------------------------------"
}

confirm_and_run_command() {
  local cmd="$1" title="$2" modules_text
  modules_text="$(modules_for_command "${cmd}")"
  show_plan "${title}" "${modules_text}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log_warn "当前为 dry-run 模式，只显示计划，不执行安装"
    return 0
  fi
  if confirm_yes "是否按以上计划继续安装？"; then
    run_command "${cmd}"
    show_summary
  else
    log_warn "已取消安装：${title}"
  fi
}

show_menu() {
  while true; do
    clear
    echo "----------------------------------------------------------"
    echo "[ArchDevKit 工作站初始化工具]"
    echo "1) 安装基础环境"
    echo "2) 配置系统 DNS"
    echo "3) 配置 archlinuxcn 源"
    echo "4) 安装 Git / GitHub 环境"
    echo "5) 安装 Runtime 环境：mise + Node/npm/Python/Go"
    echo "6) 安装 Neovim 环境"
    echo "7) 安装 Docker 环境"
    echo "8) 安装字体环境"
    echo "9) 安装 Zsh / Oh My Zsh / Powerlevel10k"
    echo "10) 安装 Hyprland 桌面环境"
    echo "11) 安装 Proxy 代理环境（可选：mihomo / MetaCubeXD / sing-box）"
    echo "12) 安装开发环境组合"
    echo "13) 安装完整工作站"
    echo "14) 查看当前配置"
    echo "0) 退出"
    echo "----------------------------------------------------------"
    read -r -p "请选择 [13]: " select_num
    select_num="${select_num:-13}"
    case "${select_num}" in
      1) confirm_and_run_command "base" "基础环境"; pause ;;
      2) confirm_and_run_command "dns" "系统 DNS"; pause ;;
      3) confirm_and_run_command "archlinuxcn" "archlinuxcn 源"; pause ;;
      4) confirm_and_run_command "git" "Git / GitHub 环境"; pause ;;
      5) confirm_and_run_command "runtime" "Runtime 环境"; pause ;;
      6) confirm_and_run_command "nvim" "Neovim 环境"; pause ;;
      7) confirm_and_run_command "docker" "Docker 环境"; pause ;;
      8) confirm_and_run_command "fonts" "字体环境"; pause ;;
      9) confirm_and_run_command "shell" "Zsh / Oh My Zsh / Powerlevel10k"; pause ;;
      10) confirm_and_run_command "desktop" "Hyprland 桌面环境"; pause ;;
      11) confirm_and_run_command "proxy" "Proxy 代理环境"; pause ;;
      12) confirm_and_run_command "dev" "开发环境组合"; pause ;;
      13) confirm_and_run_command "workstation" "完整工作站"; pause ;;
      14) show_config; pause ;;
      0) exit 0 ;;
      *) log_warn "未知选择：${select_num}"; pause ;;
    esac
  done
}

main() {
  parse_args "$@"
  require_normal_user
  require_cmd sudo
  validate_hyprland_config_mode
  case "${COMMAND}" in
    menu) show_menu ;;
    config) show_config ;;
    help) show_help ;;
    base) confirm_and_run_command "base" "基础环境" ;;
    dns) confirm_and_run_command "dns" "系统 DNS" ;;
    archlinuxcn) confirm_and_run_command "archlinuxcn" "archlinuxcn 源" ;;
    git) confirm_and_run_command "git" "Git / GitHub 环境" ;;
    runtime) confirm_and_run_command "runtime" "Runtime 环境" ;;
    nvim) confirm_and_run_command "nvim" "Neovim 环境" ;;
    docker) confirm_and_run_command "docker" "Docker 环境" ;;
    fonts) confirm_and_run_command "fonts" "字体环境" ;;
    shell|zsh) confirm_and_run_command "shell" "Zsh / Oh My Zsh / Powerlevel10k" ;;
    desktop|hyprland) confirm_and_run_command "desktop" "Hyprland 桌面环境" ;;
    proxy) confirm_and_run_command "proxy" "Proxy 代理环境" ;;
    dev) confirm_and_run_command "dev" "开发环境组合" ;;
    workstation) confirm_and_run_command "workstation" "完整工作站" ;;
    *) die "未知命令：${COMMAND}" ;;
  esac
}

main "$@"
