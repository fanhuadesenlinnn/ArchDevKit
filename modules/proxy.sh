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
  [[ "${MIHOMO_CONFIG_SOURCE:-}" == "${SCRIPT_DIR}/files/mihomo/config.yaml" ]]
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

render_default_mihomo_config() {
  local source="${SCRIPT_DIR}/files/mihomo/config.yaml"
  local target="$1"
  local tmp_file allow_lan secret external_ui

  [[ -f "${source}" ]] || die "默认 Mihomo 配置不存在：${source}"
  [[ -n "${target}" ]] || die "Mihomo 配置目标为空"

  mkdir -p "$(dirname "${target}")"
  allow_lan="$(bool_to_yaml "${MIHOMO_ALLOW_LAN:-0}")"
  secret="$(quote_yaml_string "${MIHOMO_SECRET:-}")"
  external_ui="${METACUBEXD_WEB_ROOT:-/usr/share/metacubexd}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ render ${source} -> ${target}"
    return 0
  fi

  tmp_file="$(mktemp)"
  awk \
    -v mixed_port="${MIHOMO_MIXED_PORT:-7890}" \
    -v allow_lan="${allow_lan}" \
    -v bind_address="${MIHOMO_BIND_ADDRESS:-127.0.0.1}" \
    -v controller_host="${MIHOMO_CONTROLLER_HOST:-127.0.0.1}" \
    -v controller_port="${MIHOMO_CONTROLLER_PORT:-9090}" \
    -v dns_listen="${MIHOMO_DNS_LISTEN:-127.0.0.1:1053}" \
    -v secret="${secret}" \
    -v enable_ui="${ENABLE_METACUBEXD:-0}" \
    -v external_ui="${external_ui}" '
      BEGIN { in_dns=0; ui_written=0 }
      /^dns:/ { in_dns=1; print; next }
      /^[^[:space:]][^:]*:/ && $0 !~ /^dns:/ { in_dns=0 }
      /^mixed-port:/ { print "mixed-port: " mixed_port; next }
      /^allow-lan:/ { print "allow-lan: " allow_lan; next }
      /^bind-address:/ { print "bind-address: \"" bind_address "\""; next }
      /^external-controller:/ {
        print "external-controller: " controller_host ":" controller_port
        next
      }
      /^external-ui:/ {
        if (enable_ui == 1) {
          print "external-ui: " external_ui
          ui_written=1
        }
        next
      }
      /^secret:/ { print "secret: " secret; next }
      in_dns && /^  listen:/ { print "  listen: " dns_listen; next }
      { print }
      END {
        if (enable_ui == 1 && ui_written == 0) {
          print "external-ui: " external_ui
        }
      }
    ' "${source}" > "${tmp_file}"

  backup_path "${target}"
  install -m 0600 "${tmp_file}" "${target}"
  rm -f "${tmp_file}"
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
  elif proxy_config_source_to_file "${MIHOMO_CONFIG_SOURCE:-}" "${config_file}"; then
    :
  else
    write_default_mihomo_config "${config_file}"
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

write_default_mihomo_config() {
  local config_file="$1"
  local external_controller="${MIHOMO_CONTROLLER_HOST:-127.0.0.1}:${MIHOMO_CONTROLLER_PORT:-9090}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write default Mihomo config ${config_file}"
    return 0
  fi

  mkdir -p "$(dirname "${config_file}")"
  backup_path "${config_file}"
  {
    echo "mixed-port: ${MIHOMO_MIXED_PORT:-7890}"
    echo "allow-lan: false"
    echo "mode: rule"
    echo "log-level: info"
    echo "external-controller: ${external_controller}"
    if [[ -n "${MIHOMO_SECRET:-}" ]]; then
      printf 'secret: "%s"\n' "${MIHOMO_SECRET}"
    fi
    if [[ "${ENABLE_METACUBEXD:-0}" -eq 1 ]]; then
      echo "external-ui: ${METACUBEXD_WEB_ROOT:-/usr/share/metacubexd}"
    fi
    cat <<'EOF'
dns:
  enable: true
  listen: 127.0.0.1:1053
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
proxies: []
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT
rules:
  - MATCH,DIRECT
EOF
  } > "${config_file}"
}

install_metacubexd() {
  local package="${METACUBEXD_PACKAGE:-metacubexd-bin}"
  log_info "安装 MetaCubeXD 面板：${package}"
  install_package_or_aur "${package}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ test -f ${METACUBEXD_WEB_ROOT:-/usr/share/metacubexd}/index.html"
    return 0
  fi

  [[ -f "${METACUBEXD_WEB_ROOT:-/usr/share/metacubexd}/index.html" ]] || \
    log_warn "未找到 MetaCubeXD 静态入口：${METACUBEXD_WEB_ROOT:-/usr/share/metacubexd}/index.html，请检查面板包安装路径"
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
  if proxy_config_source_to_file "${SING_BOX_CONFIG_SOURCE:-}" "${config_file}"; then
    :
  else
    write_default_sing_box_config "${config_file}"
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

write_default_sing_box_config() {
  local config_file="$1"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write default sing-box config ${config_file}"
    return 0
  fi

  mkdir -p "$(dirname "${config_file}")"
  backup_path "${config_file}"
  cat > "${config_file}" <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": ${SING_BOX_MIXED_PORT:-7890}
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "direct"
  }
}
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
    log_warn "请先替换 proxy-providers.all-proxies.url，或使用 --mihomo-config 指定自己的配置"
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
