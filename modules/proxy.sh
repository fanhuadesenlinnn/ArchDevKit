#!/usr/bin/env bash
# Proxy 模块
# 负责安装 Mihomo / sing-box 代理核心，可选安装 MetaCubeXD 面板静态文件，并生成用户级 systemd 服务。

proxy_service_name() {
  case "${PROXY_CORE:-mihomo}" in
    mihomo) printf "archdevkit-mihomo.service" ;;
    sing-box) printf "archdevkit-sing-box.service" ;;
    *) die "未知代理核心：${PROXY_CORE}" ;;
  esac
}

proxy_config_source_to_file() {
  local source="$1" target="$2" tmp_file
  [[ -n "${target}" ]] || die "代理配置目标文件为空"

  mkdir -p "$(dirname "${target}")"
  [[ -n "${source}" ]] || return 1

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ install config ${source} -> ${target}"
    return 0
  fi

  tmp_file="$(mktemp)"
  case "${source}" in
    http://*|https://*)
      require_cmd curl
      log_info "下载代理配置：${source}"
      curl -fL "${source}" -o "${tmp_file}" || {
        rm -f "${tmp_file}"
        die "下载代理配置失败：${source}"
      }
      ;;
    *)
      [[ -f "${source}" ]] || die "代理配置文件不存在：${source}"
      cp -a "${source}" "${tmp_file}"
      ;;
  esac

  backup_path "${target}"
  install -m 0600 "${tmp_file}" "${target}"
  rm -f "${tmp_file}"
}

is_default_mihomo_config_source() {
  case "${MIHOMO_CONFIG_SOURCE:-}" in
    ""|"${SCRIPT_DIR}/files/mihomo/config.yaml.tpl"|"${SCRIPT_DIR}/files/mihomo/config.yaml")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_default_sing_box_config_source() {
  case "${SING_BOX_CONFIG_SOURCE:-}" in
    ""|"${SCRIPT_DIR}/files/sing-box/config.json.tpl")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

bool_to_yaml() {
  case "${1:-0}" in
    1|true|yes|on) printf "true" ;;
    *) printf "false" ;;
  esac
}

quote_yaml_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "${value}"
}

render_proxy_template() {
  local template="$1" target="$2" mode="${3:-0600}" tmp_file
  shift 3 || true

  [[ -f "${template}" ]] || die "代理模板不存在：${template}"
  [[ -n "${target}" ]] || die "代理模板目标为空"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ render ${template} -> ${target}"
    return 0
  fi

  mkdir -p "$(dirname "${target}")"
  tmp_file="$(mktemp)"
  sed "$@" "${template}" > "${tmp_file}"

  backup_path "${target}"
  install -m "${mode}" "${tmp_file}" "${target}"
  rm -f "${tmp_file}"
}

render_mihomo_config_template() {
  local template="$1" target="$2"
  local allow_lan secret external_ui_line external_ui_dir

  allow_lan="$(sed_escape_replacement "$(bool_to_yaml "${MIHOMO_ALLOW_LAN:-0}")")"
  secret="$(sed_escape_replacement "$(quote_yaml_string "${MIHOMO_SECRET:-}")")"
  if [[ "${ENABLE_METACUBEXD:-0}" -eq 1 ]]; then
    external_ui_dir="${MIHOMO_EXTERNAL_UI_DIR:-${MIHOMO_CONFIG_DIR:-${HOME}/.config/mihomo}/ui}"
    external_ui_line="$(sed_escape_replacement "external-ui: ${external_ui_dir}")"
  else
    external_ui_line=""
  fi

  render_proxy_template "${template}" "${target}" 0600 \
    -e "s/__MIHOMO_MIXED_PORT__/$(sed_escape_replacement "${MIHOMO_MIXED_PORT:-7890}")/g" \
    -e "s/__MIHOMO_ALLOW_LAN__/${allow_lan}/g" \
    -e "s/__MIHOMO_BIND_ADDRESS__/$(sed_escape_replacement "${MIHOMO_BIND_ADDRESS:-127.0.0.1}")/g" \
    -e "s/__MIHOMO_CONTROLLER_HOST__/$(sed_escape_replacement "${MIHOMO_CONTROLLER_HOST:-127.0.0.1}")/g" \
    -e "s/__MIHOMO_CONTROLLER_PORT__/$(sed_escape_replacement "${MIHOMO_CONTROLLER_PORT:-9090}")/g" \
    -e "s/__MIHOMO_DNS_LISTEN__/$(sed_escape_replacement "${MIHOMO_DNS_LISTEN:-127.0.0.1:1053}")/g" \
    -e "s/__MIHOMO_SECRET_YAML__/${secret}/g" \
    -e "s/__METACUBEXD_EXTERNAL_UI_LINE__/${external_ui_line}/g"
}

render_default_mihomo_config() {
  render_mihomo_config_template "${SCRIPT_DIR}/files/mihomo/config.yaml.tpl" "$1"
}

render_sing_box_config_template() {
  local template="$1" target="$2"

  render_proxy_template "${template}" "${target}" 0600 \
    -e "s/__SING_BOX_MIXED_PORT__/$(sed_escape_replacement "${SING_BOX_MIXED_PORT:-7890}")/g"
}

render_default_sing_box_config() {
  render_sing_box_config_template "${SCRIPT_DIR}/files/sing-box/config.json.tpl" "$1"
}

mihomo_config_has_placeholder_subscription() {
  local config_file="$1"
  [[ -f "${config_file}" ]] || return 1
  grep -Fq "https://example.com/your-subscription-url" "${config_file}"
}

install_proxy_env() {
  if is_done "proxy"; then
    log_info "Proxy 环境已处理，跳过"
    return 0
  fi

  ensure_base

  log_info "开始安装 Proxy 环境：${PROXY_CORE}"
  case "${PROXY_CORE:-mihomo}" in
    mihomo)
      install_mihomo
      configure_mihomo
      if [[ "${ENABLE_METACUBEXD:-0}" -eq 1 ]]; then
        install_metacubexd
      fi
      ;;
    sing-box)
      install_sing_box
      configure_sing_box
      ;;
    *)
      die "未知代理核心：${PROXY_CORE}"
      ;;
  esac

  enable_proxy_service_if_needed
  verify_proxy_env

  mark_done "proxy"
  log_info "Proxy 环境安装完成"
}

install_mihomo() {
  local package="${MIHOMO_PACKAGE:-mihomo}"
  log_info "安装 Mihomo 核心：${package}"
  install_package_or_aur "${package}"
}

configure_mihomo() {
  local config_file="${MIHOMO_CONFIG_FILE:-${HOME}/.config/mihomo/config.yaml}"
  local config_dir="${MIHOMO_CONFIG_DIR:-$(dirname "${config_file}")}"
  local service_dir="${HOME}/.config/systemd/user"
  local service_file="${service_dir}/archdevkit-mihomo.service"

  log_info "配置 Mihomo：${config_file}"
  mkdir -p "${config_dir}" "${config_dir}/providers" "${config_dir}/ruleset"
  if is_default_mihomo_config_source; then
    render_default_mihomo_config "${config_file}"
  elif [[ "${MIHOMO_CONFIG_SOURCE:-}" == *.tpl && "${MIHOMO_CONFIG_SOURCE:-}" != http://* && "${MIHOMO_CONFIG_SOURCE:-}" != https://* ]]; then
    render_mihomo_config_template "${MIHOMO_CONFIG_SOURCE}" "${config_file}"
  elif proxy_config_source_to_file "${MIHOMO_CONFIG_SOURCE:-}" "${config_file}"; then
    :
  else
    render_default_mihomo_config "${config_file}"
  fi

  mkdir -p "${service_dir}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write ${service_file}"
    return 0
  fi

  backup_path "${service_file}"
  cat > "${service_file}" <<EOF
[Unit]
Description=ArchDevKit Mihomo Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${config_dir}
ExecStart=/usr/bin/mihomo -d ${config_dir}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
}

install_metacubexd() {
  local package="${METACUBEXD_PACKAGE:-metacubexd-bin}"
  local source_root="${METACUBEXD_WEB_ROOT:-/usr/share/metacubexd}"
  local target_root="${MIHOMO_EXTERNAL_UI_DIR:-${MIHOMO_CONFIG_DIR:-${HOME}/.config/mihomo}/ui}"

  log_info "安装 MetaCubeXD 面板：${package}"
  install_package_or_aur "${package}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ install MetaCubeXD UI ${source_root} -> ${target_root}"
    return 0
  fi

  [[ -f "${source_root}/index.html" ]] || \
    log_warn "未找到 MetaCubeXD 静态入口：${source_root}/index.html，请检查面板包安装路径"

  if [[ -f "${source_root}/index.html" ]]; then
    rm -rf "${target_root}"
    mkdir -p "$(dirname "${target_root}")"
    cp -a "${source_root}" "${target_root}"
    log_info "MetaCubeXD UI 已安装到：${target_root}"
  fi
}

install_sing_box() {
  local package="${SING_BOX_PACKAGE:-sing-box}"
  log_info "安装 sing-box 核心：${package}"
  install_package_or_aur "${package}"
}

configure_sing_box() {
  local config_file="${SING_BOX_CONFIG_FILE:-${HOME}/.config/sing-box/config.json}"
  local config_dir="${SING_BOX_CONFIG_DIR:-$(dirname "${config_file}")}"
  local service_dir="${HOME}/.config/systemd/user"
  local service_file="${service_dir}/archdevkit-sing-box.service"

  log_info "配置 sing-box：${config_file}"
  mkdir -p "${config_dir}"
  if is_default_sing_box_config_source; then
    render_default_sing_box_config "${config_file}"
  elif [[ "${SING_BOX_CONFIG_SOURCE:-}" == *.tpl && "${SING_BOX_CONFIG_SOURCE:-}" != http://* && "${SING_BOX_CONFIG_SOURCE:-}" != https://* ]]; then
    render_sing_box_config_template "${SING_BOX_CONFIG_SOURCE}" "${config_file}"
  elif proxy_config_source_to_file "${SING_BOX_CONFIG_SOURCE:-}" "${config_file}"; then
    :
  else
    render_default_sing_box_config "${config_file}"
  fi

  mkdir -p "${service_dir}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write ${service_file}"
    return 0
  fi

  backup_path "${service_file}"
  cat > "${service_file}" <<EOF
[Unit]
Description=ArchDevKit sing-box Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${config_dir}
ExecStart=/usr/bin/sing-box run -c ${config_file}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
}

enable_user_service() {
  local service="$1"
  [[ -n "${service}" ]] || die "systemd 用户服务名为空"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ systemctl --user daemon-reload"
    echo "+ systemctl --user enable --now ${service}"
    return 0
  fi

  systemctl --user daemon-reload || {
    log_warn "systemd 用户服务刷新失败，请登录图形会话后手动执行：systemctl --user daemon-reload"
    return 0
  }
  systemctl --user enable --now "${service}" || \
    log_warn "用户服务启用失败，可稍后手动执行：systemctl --user enable --now ${service}"
}

enable_proxy_service_if_needed() {
  [[ "${PROXY_AUTO_ENABLE_SERVICE:-0}" -eq 1 ]] || {
    log_warn "当前配置不自动启用 Proxy 服务"
    return 0
  }

  if [[ "${PROXY_CORE:-mihomo}" == "mihomo" ]] && mihomo_config_has_placeholder_subscription "${MIHOMO_CONFIG_FILE:-${HOME}/.config/mihomo/config.yaml}"; then
    log_warn "检测到默认 Mihomo 配置仍使用示例订阅地址，已跳过自动启动服务"
    log_warn "请先替换 proxy-providers.airport.url，或使用 --mihomo-config 指定自己的配置"
    return 0
  fi

  enable_user_service "$(proxy_service_name)"
}

verify_proxy_env() {
  log_info "验证 Proxy 环境"
  case "${PROXY_CORE:-mihomo}" in
    mihomo)
      run_cmd mihomo -v || true
      log_info "Mihomo mixed-port：127.0.0.1:${MIHOMO_MIXED_PORT:-7890}"
      log_info "Mihomo 控制接口：http://${MIHOMO_CONTROLLER_HOST:-127.0.0.1}:${MIHOMO_CONTROLLER_PORT:-9090}"
      if [[ "${ENABLE_METACUBEXD:-0}" -eq 1 ]]; then
        log_info "MetaCubeXD 面板由 Mihomo 托管：http://${MIHOMO_CONTROLLER_HOST:-127.0.0.1}:${MIHOMO_CONTROLLER_PORT:-9090}/ui/"
      fi
      ;;
    sing-box)
      run_cmd sing-box version || true
      log_info "sing-box mixed-port：127.0.0.1:${SING_BOX_MIXED_PORT:-7890}"
      ;;
  esac
}

ensure_proxy_env() {
  if [[ "${ENABLE_PROXY:-0}" -eq 1 ]]; then
    install_proxy_env
  else
    log_info "当前配置未启用 Proxy，跳过"
  fi
}
