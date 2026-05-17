#!/usr/bin/env bash
set -Eeuo pipefail

# ArchDevKit 主入口
# 负责加载配置、解析参数、显示菜单、展示计划并编排各个模块。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/install_vars"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/modules/base.sh"
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
  bash install.sh base|archlinuxcn|git|runtime|nvim|docker|fonts|shell|desktop|proxy|dev|workstation

常用参数：
  -y, --yes                 自动确认
  --dry-run                 只显示计划，不执行
  --no-china                不配置 npm/pip 国内源
  --no-github-proxy         不使用 GitHub 代理
  --github-proxy URL        指定 GitHub 代理
  --repo URL                指定 Neovim 配置仓库
  --branch NAME             指定 Neovim 配置分支
  --no-plugin-sync          不同步 Neovim 插件
  --node-version VERSION    指定 Node.js 版本
  --npm-version VERSION     指定 npm 版本
  --python-version VERSION  指定 Python 版本
  --go-version VERSION      指定 Go 版本
  --no-sddm                 不启用 SDDM
  --nvidia                  安装 NVIDIA Wayland 相关包
  --monaco                  安装 Monaco 字体
  --browser-package NAME    指定桌面浏览器安装包
  --browser-app COMMAND     指定桌面浏览器启动命令
  --rime-schema NAME        指定 Rime 默认方案
  --rime-repo URL           指定 Rime 配置仓库
  --rime-branch NAME        指定 Rime 配置分支
  --no-rime-config          不安装 Rime 配置仓库
  --with-proxy              workstation 中安装 Proxy 模块
  --no-proxy                workstation 中不安装 Proxy 模块
  --proxy-core NAME         指定代理核心：mihomo / sing-box
  --no-metacubexd           不安装 MetaCubeXD 面板
  --mihomo-config PATH/URL  指定 Mihomo 配置文件或 URL
  --sing-box-config PATH/URL 指定 sing-box 配置文件或 URL
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      base|archlinuxcn|git|runtime|nvim|docker|fonts|shell|zsh|desktop|hyprland|proxy|dev|workstation|config|menu|help)
        COMMAND="$1"; shift ;;
      -y|--yes) ASSUME_YES=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --no-china) ENABLE_CHINA_MIRROR=0; shift ;;
      --no-github-proxy) ENABLE_GITHUB_PROXY=0; shift ;;
      --github-proxy) GITHUB_PROXY="${2:-}"; ENABLE_GITHUB_PROXY=1; shift 2 ;;
      --github-proxy=*) GITHUB_PROXY="${1#*=}"; ENABLE_GITHUB_PROXY=1; shift ;;
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
      --monaco) INSTALL_MONACO_FONT=1; shift ;;
      --no-monaco) INSTALL_MONACO_FONT=0; shift ;;
      --browser-package) BROWSER_PACKAGE="${2:-}"; shift 2 ;;
      --browser-package=*) BROWSER_PACKAGE="${1#*=}"; shift ;;
      --browser-app) BROWSER_APP="${2:-}"; shift 2 ;;
      --browser-app=*) BROWSER_APP="${1#*=}"; shift ;;
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
  echo "启用 GitHub 代理:     $(bool_text "${ENABLE_GITHUB_PROXY}")"
  echo "GitHub 代理地址:      ${GITHUB_PROXY}"
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
  echo "浏览器安装包:         ${BROWSER_PACKAGE}"
  echo "浏览器启动命令:       ${BROWSER_APP}"
  echo "输入法框架:           Fcitx5 $(bool_text "${ENABLE_FCITX5}")"
  echo "输入法引擎:           ${INPUT_METHOD_ENGINE}"
  echo "Rime 默认方案:        ${RIME_SCHEMA}"
  echo "Rime 配置仓库:        ${RIME_CONFIG_REPO:-不安装}"
  echo "Rime 配置分支:        ${RIME_CONFIG_BRANCH:-默认分支}"
  echo "Rime 配置目录:        ${RIME_CONFIG_DIR}"
  echo "安装 Rime 配置:       $(bool_text "${INSTALL_RIME_CONFIG}")"
  echo
  echo "[Proxy]"
  echo "随 workstation 安装:  $(bool_text "${ENABLE_PROXY}")"
  echo "代理核心:             ${PROXY_CORE}"
  echo "自动启用服务:         $(bool_text "${PROXY_AUTO_ENABLE_SERVICE}")"
  echo "Mihomo 包:            ${MIHOMO_PACKAGE}"
  echo "Mihomo 配置来源:      ${MIHOMO_CONFIG_SOURCE:-生成基础模板}"
  echo "Mihomo mixed-port:    ${MIHOMO_MIXED_PORT}"
  echo "Mihomo allow-lan:     $(bool_text "${MIHOMO_ALLOW_LAN}")"
  echo "Mihomo bind-address:  ${MIHOMO_BIND_ADDRESS}"
  echo "Mihomo 控制接口:      http://${MIHOMO_CONTROLLER_HOST}:${MIHOMO_CONTROLLER_PORT}"
  echo "Mihomo DNS 监听:      ${MIHOMO_DNS_LISTEN}"
  if [[ "${PROXY_CORE:-mihomo}" == "mihomo" ]]; then
    echo "MetaCubeXD:           $(bool_text "${ENABLE_METACUBEXD}")"
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
    archlinuxcn) echo "archlinuxcn 软件源" ;;
    git) echo "Git / GitHub CLI" ;;
    runtime) echo "mise + Node/npm/Python/Go" ;;
    nvim) echo "Neovim + 个人配置" ;;
    docker) echo "Docker / Compose" ;;
    fonts) echo "字体环境" ;;
    shell) echo "Zsh / Oh My Zsh / Powerlevel10k" ;;
    desktop) echo "Hyprland 桌面环境" ;;
    proxy) echo "Proxy 代理环境" ;;
    *) echo "$1" ;;
  esac
}

modules_for_command() {
  case "$1" in
    base) echo "base" ;;
    archlinuxcn) echo "base archlinuxcn" ;;
    git) echo "base git" ;;
    runtime) echo "base runtime" ;;
    nvim) echo "base git runtime nvim" ;;
    docker) echo "base docker" ;;
    fonts) echo "base fonts" ;;
    shell|zsh) echo "base fonts shell" ;;
    proxy) echo "base proxy" ;;
    desktop|hyprland)
      if [[ "${INSTALL_ARCHLINUXCN:-0}" -eq 1 && "${BROWSER_PACKAGE:-}" == "google-chrome" ]]; then
        echo "base archlinuxcn fonts desktop"
      else
        echo "base fonts desktop"
      fi
      ;;
    dev) echo "base git runtime nvim docker" ;;
    workstation)
      local modules="base"
      [[ "${INSTALL_ARCHLINUXCN:-0}" -eq 1 ]] && modules="${modules} archlinuxcn"
      modules="${modules} git runtime nvim docker fonts shell desktop"
      [[ "${ENABLE_PROXY:-0}" -eq 1 ]] && modules="${modules} proxy"
      echo "${modules}"
      ;;
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
  echo "  GitHub 代理:      $(bool_text "${ENABLE_GITHUB_PROXY}")"
  echo "  GitHub 代理地址:  ${GITHUB_PROXY}"
  echo "  npm 源:           ${NPM_REGISTRY}"
  echo "  pip 源:           ${PIP_INDEX_URL}"
  echo "  Node.js/npm:      ${NODE_VERSION} / ${NPM_VERSION}"
  echo "  Python/Go:        ${PYTHON_VERSION} / ${GO_VERSION}"
  echo "  Neovim 仓库:      ${NVIM_REPO}"
  echo "  Neovim 实际下载:  $(github_proxy_url "${NVIM_REPO}")"
  echo "  Powerlevel10k:    $(bool_text "${INSTALL_POWERLEVEL10K}")"
  echo "  Hyprland SDDM:    $(bool_text "${ENABLE_SDDM}")"
  echo "  浏览器:           ${BROWSER_DISPLAY_NAME:-${BROWSER_APP}} (${BROWSER_PACKAGE})"
  echo "  输入法:           Fcitx5 + ${INPUT_METHOD_ENGINE} (${RIME_SCHEMA})"
  if [[ "${INPUT_METHOD_ENGINE:-rime}" == "rime" ]]; then
    echo "  Rime 配置:        $(bool_text "${INSTALL_RIME_CONFIG}") / ${RIME_CONFIG_REPO:-未设置}"
  fi
  if [[ " ${modules_text} " == *" proxy "* ]]; then
    echo "  Proxy:            本次安装 / ${PROXY_CORE}"
  else
    echo "  Proxy:            $(bool_text "${ENABLE_PROXY}") / ${PROXY_CORE}"
  fi
  if [[ "${PROXY_CORE:-mihomo}" == "mihomo" ]]; then
    echo "  MetaCubeXD:       $(bool_text "${ENABLE_METACUBEXD}")"
  fi
  echo "----------------------------------------------------------"
}

install_profile_dev() {
  install_base
  install_git_env
  install_runtime_env
  install_nvim_env
  install_docker_env
}

install_profile_workstation() {
  install_base
  [[ "${INSTALL_ARCHLINUXCN:-0}" -eq 1 ]] && install_archlinuxcn
  install_git_env
  install_runtime_env
  install_nvim_env
  install_docker_env
  install_fonts
  install_shell_zsh
  install_desktop_hyprland
  ensure_proxy_env
}

run_command() {
  case "$1" in
    base) install_base ;;
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
  local key
  for key in "${!MODULE_DONE[@]}"; do echo "  - ${key}"; done
  echo
  echo "后续建议:"
  echo "1. 重新打开终端，让 mise / zsh 配置完全生效"
  echo "2. 如果加入了 docker 用户组，请注销或重启后再使用 docker"
  echo "3. 如果 Neovim 插件同步失败，可执行：nvim +Lazy sync"
  echo "4. 如果启用了 SDDM，请重启后在登录界面选择 Hyprland"
  echo "5. 如果安装了 Proxy，可用 systemctl --user status archdevkit-mihomo 或 archdevkit-sing-box 查看服务"
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
    echo "2) 配置 archlinuxcn 源"
    echo "3) 安装 Git / GitHub 环境"
    echo "4) 安装 Runtime 环境：mise + Node/npm/Python/Go"
    echo "5) 安装 Neovim 环境"
    echo "6) 安装 Docker 环境"
    echo "7) 安装字体环境"
    echo "8) 安装 Zsh / Oh My Zsh / Powerlevel10k"
    echo "9) 安装 Hyprland 桌面环境"
    echo "10) 安装 Proxy 代理环境（可选：mihomo / MetaCubeXD / sing-box）"
    echo "11) 安装开发环境组合"
    echo "12) 安装完整工作站"
    echo "13) 查看当前配置"
    echo "0) 退出"
    echo "----------------------------------------------------------"
    read -r -p "请选择 [12]: " select_num
    select_num="${select_num:-12}"
    case "${select_num}" in
      1) confirm_and_run_command "base" "基础环境"; pause ;;
      2) confirm_and_run_command "archlinuxcn" "archlinuxcn 源"; pause ;;
      3) confirm_and_run_command "git" "Git / GitHub 环境"; pause ;;
      4) confirm_and_run_command "runtime" "Runtime 环境"; pause ;;
      5) confirm_and_run_command "nvim" "Neovim 环境"; pause ;;
      6) confirm_and_run_command "docker" "Docker 环境"; pause ;;
      7) confirm_and_run_command "fonts" "字体环境"; pause ;;
      8) confirm_and_run_command "shell" "Zsh / Oh My Zsh / Powerlevel10k"; pause ;;
      9) confirm_and_run_command "desktop" "Hyprland 桌面环境"; pause ;;
      10) confirm_and_run_command "proxy" "Proxy 代理环境"; pause ;;
      11) confirm_and_run_command "dev" "开发环境组合"; pause ;;
      12) confirm_and_run_command "workstation" "完整工作站"; pause ;;
      13) show_config; pause ;;
      0) exit 0 ;;
      *) log_warn "未知选择：${select_num}"; pause ;;
    esac
  done
}

main() {
  parse_args "$@"
  require_normal_user
  require_cmd sudo
  case "${COMMAND}" in
    menu) show_menu ;;
    config) show_config ;;
    help) show_help ;;
    base) confirm_and_run_command "base" "基础环境" ;;
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
