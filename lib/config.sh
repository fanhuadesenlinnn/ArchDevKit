#!/usr/bin/env bash
# 配置层：加载用户配置、归一化默认值，并在安装前做轻量校验。

CONFIG_FILE_LOADED=0
CONFIG_LOAD_WARNINGS=()
CONFIG_WARNINGS=()

config_scalar_keys() {
  cat <<'EOF'
ASSUME_YES DRY_RUN ARCHDEVKIT_DEFAULT_PROFILE ARCHDEVKIT_USE_STATE ARCHDEVKIT_STATE_DIR ARCHDEVKIT_LOAD_CONFIG_FILE ARCHDEVKIT_CONFIG_FILE ARCHDEVKIT_JSON_SCHEMA_VERSION
ENABLE_CHINA_MIRROR ENABLE_GITHUB_PROXY GITHUB_PROXY NPM_REGISTRY PIP_INDEX_URL PIP_TRUSTED_HOST NODE_MIRROR_URL GO_DOWNLOAD_MIRROR GO_REPO_URL PYTHON_BUILD_MIRROR_URL PYENV_REPO_URL ENABLE_MISE_GITHUB_URL_REPLACEMENT
ENABLE_DNS DNS_DNSSEC DNS_OVER_TLS DNS_CACHE DNS_LLMNR DNS_MULTICAST_DNS DNS_CONFIGURE_NETWORKMANAGER DNS_LINK_RESOLV_CONF DNS_RESTART_NETWORKMANAGER
INSTALL_ARCHLINUXCN ARCHLINUXCN_SERVER INSTALL_ARCHLINUXCN_MIRRORLIST
RUNTIME_MANAGER NODE_VERSION NPM_VERSION PYTHON_VERSION GO_VERSION ENABLE_COREPACK
NVIM_REPO NVIM_BRANCH NVIM_CONFIG_DIR SYNC_NVIM_PLUGINS
INSTALL_OH_MY_ZSH INSTALL_POWERLEVEL10K INSTALL_P10K_CONFIG SET_ZSH_AS_DEFAULT OH_MY_ZSH_REPO ZSH_AUTOSUGGESTIONS_REPO ZSH_SYNTAX_HIGHLIGHTING_REPO POWERLEVEL10K_REPO ZSH_THEME_NAME ZSH_PLUGINS P10K_CONFIG_SOURCE
INSTALL_CN_FONTS INSTALL_NERD_FONTS INSTALL_MONACO_FONT MONACO_AS_SYSTEM_FONT SYSTEM_FONT_FAMILY SYSTEM_MONOSPACE_FONT_FAMILY SYSTEM_CJK_FONT_FAMILY SYSTEM_EMOJI_FONT_FAMILY MONACO_FONT_PACKAGE
ENABLE_DOCKER_SERVICE ADD_USER_TO_DOCKER_GROUP CONFIGURE_DOCKER_MIRRORS
ENABLE_SDDM ENABLE_BLUETOOTH ENABLE_FCITX5 INPUT_METHOD_ENGINE RIME_SCHEMA INSTALL_RIME_CONFIG RIME_CONFIG_REPO RIME_CONFIG_BRANCH RIME_CONFIG_DIR GPU_TYPE VMWARE_HYPRLAND_MONITOR_MODE VMWARE_FORCE_SOFTWARE_RENDERER VM_HYPRLAND_MONITOR_MODE VM_HYPRLAND_DYNAMIC_RESIZE VM_HYPRLAND_LOW_LATENCY HYPRLAND_CONFIG_MODE HYPRDOTS_SOURCE_DIR HYPRDOTS_SOURCE_COMMIT HYPRDOTS_LOCAL_BIN_DIR HYPRDOTS_WALLPAPER_DIR INSTALL_HYPRDOTS_OBSIDIAN TERMINAL_APP APP_LAUNCHER FILE_MANAGER BROWSER_PACKAGE BROWSER_APP
ENABLE_PROXY PROXY_CORE PROXY_AUTO_ENABLE_SERVICE MIHOMO_PACKAGE MIHOMO_SERVICE_NAME MIHOMO_CONFIG_DIR MIHOMO_CONFIG_FILE MIHOMO_CONFIG_SOURCE MIHOMO_MIXED_PORT MIHOMO_ALLOW_LAN MIHOMO_BIND_ADDRESS MIHOMO_CONTROLLER_HOST MIHOMO_CONTROLLER_PORT MIHOMO_DNS_LISTEN MIHOMO_SECRET MIHOMO_STATE_DIR MIHOMO_EXTERNAL_UI_DIR ENABLE_METACUBEXD METACUBEXD_PACKAGE METACUBEXD_WEB_ROOT SING_BOX_PACKAGE SING_BOX_CONFIG_DIR SING_BOX_CONFIG_FILE SING_BOX_CONFIG_SOURCE SING_BOX_MIXED_PORT
EOF
}

config_list_keys() {
  cat <<'EOF'
DNS_SERVERS DNS_FALLBACK_SERVERS DNS_FOREIGN_FALLBACK_SERVERS DOCKER_MIRRORS HYPRDOTS_CONFIG_MODULES
EOF
}

config_bool_keys() {
  cat <<'EOF'
ASSUME_YES DRY_RUN ARCHDEVKIT_USE_STATE ARCHDEVKIT_LOAD_CONFIG_FILE ENABLE_CHINA_MIRROR ENABLE_GITHUB_PROXY ENABLE_MISE_GITHUB_URL_REPLACEMENT ENABLE_DNS DNS_CONFIGURE_NETWORKMANAGER DNS_LINK_RESOLV_CONF DNS_RESTART_NETWORKMANAGER INSTALL_ARCHLINUXCN INSTALL_ARCHLINUXCN_MIRRORLIST ENABLE_COREPACK SYNC_NVIM_PLUGINS INSTALL_OH_MY_ZSH INSTALL_POWERLEVEL10K INSTALL_P10K_CONFIG SET_ZSH_AS_DEFAULT INSTALL_CN_FONTS INSTALL_NERD_FONTS INSTALL_MONACO_FONT MONACO_AS_SYSTEM_FONT ENABLE_DOCKER_SERVICE ADD_USER_TO_DOCKER_GROUP CONFIGURE_DOCKER_MIRRORS ENABLE_SDDM ENABLE_BLUETOOTH ENABLE_FCITX5 INSTALL_RIME_CONFIG VMWARE_FORCE_SOFTWARE_RENDERER VM_HYPRLAND_DYNAMIC_RESIZE VM_HYPRLAND_LOW_LATENCY INSTALL_HYPRDOTS_OBSIDIAN ENABLE_PROXY PROXY_AUTO_ENABLE_SERVICE MIHOMO_ALLOW_LAN ENABLE_METACUBEXD
EOF
}

word_list_has() {
  local wanted="$1" item
  while IFS= read -r item; do
    for item in ${item}; do
      [[ "${item}" == "${wanted}" ]] && return 0
    done
  done
  return 1
}

config_scalar_allowed() {
  config_scalar_keys | word_list_has "$1"
}

config_list_allowed() {
  config_list_keys | word_list_has "$1"
}

trim_config_value() {
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<<"$1"
}

strip_optional_quotes() {
  local value="$1" first last length
  length="${#value}"
  if [[ "${length}" -ge 2 ]]; then
    first="${value:0:1}"
    last="${value:length-1:1}"
    if [[ ( "${first}" == '"' && "${last}" == '"' ) || ( "${first}" == "'" && "${last}" == "'" ) ]]; then
      value="${value:1:length-2}"
    fi
  fi
  printf "%s" "${value}"
}

add_config_load_warning() {
  CONFIG_LOAD_WARNINGS+=("$1")
}

add_config_warning() {
  CONFIG_WARNINGS+=("$1")
}

split_config_list() {
  local value="$1" item
  CONFIG_SPLIT_VALUES=()
  value="${value//,/ }"
  for item in ${value}; do
    [[ -n "${item}" ]] && CONFIG_SPLIT_VALUES+=("${item}")
  done
}

assign_config_list() {
  local key="$1"
  if [[ "${#CONFIG_SPLIT_VALUES[@]}" -eq 0 ]]; then
    case "${key}" in
      DNS_SERVERS) DNS_SERVERS=() ;;
      DNS_FALLBACK_SERVERS) DNS_FALLBACK_SERVERS=() ;;
      DNS_FOREIGN_FALLBACK_SERVERS) DNS_FOREIGN_FALLBACK_SERVERS=() ;;
      DOCKER_MIRRORS) DOCKER_MIRRORS=() ;;
      HYPRDOTS_CONFIG_MODULES) HYPRDOTS_CONFIG_MODULES=() ;;
      *) return 1 ;;
    esac
    return 0
  fi
  case "${key}" in
    DNS_SERVERS) DNS_SERVERS=("${CONFIG_SPLIT_VALUES[@]}") ;;
    DNS_FALLBACK_SERVERS) DNS_FALLBACK_SERVERS=("${CONFIG_SPLIT_VALUES[@]}") ;;
    DNS_FOREIGN_FALLBACK_SERVERS) DNS_FOREIGN_FALLBACK_SERVERS=("${CONFIG_SPLIT_VALUES[@]}") ;;
    DOCKER_MIRRORS) DOCKER_MIRRORS=("${CONFIG_SPLIT_VALUES[@]}") ;;
    HYPRDOTS_CONFIG_MODULES)
      # shellcheck disable=SC2034
      HYPRDOTS_CONFIG_MODULES=("${CONFIG_SPLIT_VALUES[@]}")
      ;;
    *) return 1 ;;
  esac
}

apply_config_assignment() {
  local key="$1" value="$2"
  if config_scalar_allowed "${key}"; then
    printf -v "${key}" "%s" "${value}"
    return 0
  fi
  if config_list_allowed "${key}"; then
    split_config_list "${value}"
    assign_config_list "${key}"
    return 0
  fi
  add_config_load_warning "配置文件忽略不支持的键：${key}"
}

load_user_config_file() {
  local config_file line key value line_no=0
  case "$(to_lower "${ARCHDEVKIT_LOAD_CONFIG_FILE:-1}")" in
    1|true|yes|y|on) ;;
    *) return 0 ;;
  esac
  config_file="${ARCHDEVKIT_CONFIG_FILE:-${HOME}/.config/archdevkit/config.env}"
  [[ -f "${config_file}" ]] || return 0

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line_no=$((line_no + 1))
    line="$(trim_config_value "${line}")"
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    if [[ "${line}" != *=* ]]; then
      add_config_load_warning "配置文件第 ${line_no} 行缺少 =，已忽略"
      continue
    fi
    key="$(trim_config_value "${line%%=*}")"
    value="$(trim_config_value "${line#*=}")"
    value="$(strip_optional_quotes "${value}")"
    if [[ ! "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      add_config_load_warning "配置文件第 ${line_no} 行键名非法，已忽略：${key}"
      continue
    fi
    apply_config_assignment "${key}" "${value}"
  done < "${config_file}"

  # shellcheck disable=SC2034
  CONFIG_FILE_LOADED=1
}

parse_config_file_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config-file)
        [[ $# -ge 2 && -n "${2:-}" ]] || die "--config-file 需要路径"
        ARCHDEVKIT_CONFIG_FILE="$2"
        ARCHDEVKIT_LOAD_CONFIG_FILE=1
        shift 2
        ;;
      --config-file=*)
        ARCHDEVKIT_CONFIG_FILE="${1#*=}"
        [[ -n "${ARCHDEVKIT_CONFIG_FILE}" ]] || die "--config-file 需要路径"
        ARCHDEVKIT_LOAD_CONFIG_FILE=1
        shift
        ;;
      --no-config-file)
        ARCHDEVKIT_LOAD_CONFIG_FILE=0
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
}

normalize_bool_var() {
  local key="$1" value
  value="${!key-}"
  [[ -n "${value}" ]] || return 0
  case "$(to_lower "${value}")" in
    1|true|yes|y|on|enable|enabled) printf -v "${key}" "%s" "1" ;;
    0|false|no|n|off|disable|disabled) printf -v "${key}" "%s" "0" ;;
    *) die "${key} 仅支持布尔值：1/0、true/false、yes/no、on/off；当前值：${value}" ;;
  esac
}

normalize_config() {
  local key
  for key in $(config_bool_keys); do
    normalize_bool_var "${key}"
  done
}

require_non_empty_config() {
  local key="$1" desc="$2" value
  value="${!key-}"
  [[ -n "${value}" ]] || die "${desc} 不能为空：${key}"
}

validate_http_url_var() {
  local key="$1" desc="$2" value
  value="${!key-}"
  [[ -n "${value}" ]] || return 0
  case "${value}" in
    http://*|https://*) ;;
    *) die "${desc} 必须是 http(s) URL：${key}=${value}" ;;
  esac
}

validate_repo_url_var() {
  local key="$1" desc="$2" value
  value="${!key-}"
  [[ -n "${value}" ]] || return 0
  case "${value}" in
    http://*|https://*|git@*|ssh://*) ;;
    *) die "${desc} 必须是 Git URL 或 http(s) URL：${key}=${value}" ;;
  esac
}

validate_port_var() {
  local key="$1" desc="$2" value
  value="${!key-}"
  [[ "${value}" =~ ^[0-9]+$ ]] || die "${desc} 必须是数字端口：${key}=${value}"
  (( value >= 1 && value <= 65535 )) || die "${desc} 端口范围必须是 1-65535：${key}=${value}"
}

validate_source_reference() {
  local key="$1" desc="$2" value
  value="${!key-}"
  [[ -n "${value}" ]] || return 0
  case "${value}" in
    http://*|https://*) return 0 ;;
  esac
  [[ -e "${value}" ]] || add_config_warning "${desc} 本地路径当前不存在，安装时会失败：${value}"
}

validate_dns_list() {
  local key="$1" desc="$2" item
  local values=()
  case "${key}" in
    DNS_SERVERS) values=("${DNS_SERVERS[@]}") ;;
    DNS_FALLBACK_SERVERS) values=("${DNS_FALLBACK_SERVERS[@]}") ;;
    DNS_FOREIGN_FALLBACK_SERVERS) values=("${DNS_FOREIGN_FALLBACK_SERVERS[@]}") ;;
    *) die "未知 DNS 列表：${key}" ;;
  esac
  [[ "${#values[@]}" -gt 0 ]] || die "${desc} 不能为空：${key}"
  for item in "${values[@]}"; do
    [[ -n "${item}" ]] || die "${desc} 中包含空值：${key}"
  done
}

validate_mihomo_dns_listen() {
  local listen="${MIHOMO_DNS_LISTEN:-}"
  [[ -n "${listen}" ]] || die "MIHOMO_DNS_LISTEN 不能为空"
  if [[ "${listen}" != *:* ]]; then
    die "MIHOMO_DNS_LISTEN 需要包含 host:port：${listen}"
  fi
  local port="${listen##*:}"
  [[ "${port}" =~ ^[0-9]+$ ]] || die "MIHOMO_DNS_LISTEN 端口必须是数字：${listen}"
  (( port >= 1 && port <= 65535 )) || die "MIHOMO_DNS_LISTEN 端口范围必须是 1-65535：${listen}"
}

validate_config() {
  CONFIG_WARNINGS=()
  if [[ "${#CONFIG_LOAD_WARNINGS[@]}" -gt 0 ]]; then
    CONFIG_WARNINGS=("${CONFIG_LOAD_WARNINGS[@]}")
  fi
  normalize_config

  case "${ARCHDEVKIT_DEFAULT_PROFILE:-workstation}" in
    base|dns|archlinuxcn|git|runtime|nvim|docker|fonts|shell|zsh|desktop|hyprland|proxy|dev|workstation) ;;
    *) die "ARCHDEVKIT_DEFAULT_PROFILE 不支持：${ARCHDEVKIT_DEFAULT_PROFILE}" ;;
  esac
  case "${PROXY_CORE:-mihomo}" in
    mihomo|sing-box) ;;
    *) die "PROXY_CORE 仅支持 mihomo / sing-box：${PROXY_CORE}" ;;
  esac
  case "${DNS_OVER_TLS:-no}" in
    no|opportunistic|yes) ;;
    *) die "DNS_OVER_TLS 仅支持 no / opportunistic / yes：${DNS_OVER_TLS}" ;;
  esac
  case "${GPU_TYPE:-auto}" in
    auto|intel|amd|nvidia|vmware|virtio|qxl|virtualbox|none) ;;
    *) die "GPU_TYPE 不支持：${GPU_TYPE}" ;;
  esac
  case "${RUNTIME_MANAGER:-mise}" in
    mise) ;;
    *) add_config_warning "当前只实现了 mise runtime 管理器，RUNTIME_MANAGER=${RUNTIME_MANAGER} 会被安装逻辑按 mise 处理" ;;
  esac
  case "${INPUT_METHOD_ENGINE:-rime}" in
    rime|pinyin) ;;
    *) die "INPUT_METHOD_ENGINE 仅支持 rime / pinyin：${INPUT_METHOD_ENGINE}" ;;
  esac

  validate_hyprland_config_mode

  if [[ "${ENABLE_DNS:-0}" -eq 1 ]]; then
    validate_dns_list DNS_SERVERS "DNS 服务器列表"
    validate_dns_list DNS_FALLBACK_SERVERS "DNS fallback 列表"
    validate_dns_list DNS_FOREIGN_FALLBACK_SERVERS "DNS 国外 fallback 列表"
  fi

  if [[ "${ENABLE_CHINA_MIRROR:-0}" -eq 1 ]]; then
    validate_http_url_var NPM_REGISTRY "npm 源"
    validate_http_url_var PIP_INDEX_URL "pip 源"
    validate_http_url_var NODE_MIRROR_URL "Node 下载镜像"
    validate_http_url_var GO_DOWNLOAD_MIRROR "Go 下载镜像"
    validate_http_url_var PYTHON_BUILD_MIRROR_URL "python-build 下载镜像"
  fi
  if [[ "${ENABLE_GITHUB_PROXY:-0}" -eq 1 ]]; then
    validate_http_url_var GITHUB_PROXY "GitHub 代理"
  fi
  validate_repo_url_var GO_REPO_URL "Go 源码仓库"
  validate_repo_url_var PYENV_REPO_URL "pyenv 仓库"
  validate_repo_url_var NVIM_REPO "Neovim 配置仓库"
  if [[ "${INSTALL_RIME_CONFIG:-0}" -eq 1 ]]; then
    validate_repo_url_var RIME_CONFIG_REPO "Rime 配置仓库"
  fi

  if [[ "${CONFIGURE_DOCKER_MIRRORS:-0}" -eq 1 && "${#DOCKER_MIRRORS[@]}" -eq 0 ]]; then
    die "CONFIGURE_DOCKER_MIRRORS=1 时 DOCKER_MIRRORS 不能为空"
  fi

  require_non_empty_config BROWSER_PACKAGE "浏览器安装包"
  require_non_empty_config BROWSER_APP "浏览器启动命令"

  if [[ "${PROXY_CORE:-mihomo}" == "mihomo" ]]; then
    validate_port_var MIHOMO_MIXED_PORT "Mihomo mixed-port"
    validate_port_var MIHOMO_CONTROLLER_PORT "Mihomo 控制接口"
    validate_mihomo_dns_listen
    validate_source_reference MIHOMO_CONFIG_SOURCE "Mihomo 配置来源"
    if [[ ( "${TARGET:-}" == "proxy" || ( "${TARGET:-}" =~ ^(dev|workstation)$ && "${ENABLE_PROXY:-0}" -eq 1 ) ) && \
          "${MIHOMO_CONTROLLER_HOST:-127.0.0.1}" == "0.0.0.0" && -z "${MIHOMO_SECRET:-}" ]]; then
      add_config_warning "Mihomo 控制接口监听 0.0.0.0 且 secret 为空；这是当前默认值，但局域网可访问控制 API"
    fi
  else
    validate_port_var SING_BOX_MIXED_PORT "sing-box mixed-port"
    validate_source_reference SING_BOX_CONFIG_SOURCE "sing-box 配置来源"
  fi
}
