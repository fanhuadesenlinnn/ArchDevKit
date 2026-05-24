#!/usr/bin/env bash
# DNS 模块
# 使用 systemd-resolved 配置适合中国大陆网络的系统 DNS 基线。

install_dns_env() {
  if is_done "dns"; then
    log_info "DNS 环境已处理，跳过"
    return 0
  fi

  require_arch
  require_normal_user

  log_info "开始配置系统 DNS：systemd-resolved + 国内公共 DNS"
  configure_systemd_resolved_dns
  configure_networkmanager_dns_backend
  enable_systemd_resolved
  link_resolv_conf_to_resolved
  verify_dns_env

  mark_done "dns"
  log_info "DNS 环境配置完成"
}

dns_join_values() {
  printf '%s ' "$@"
}

dns_systemd_unit_exists() {
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl list-unit-files "$1" >/dev/null 2>&1
}

configure_systemd_resolved_dns() {
  local target="/etc/systemd/resolved.conf.d/90-archdevkit-dns.conf"
  local tmp_file dns_servers fallback_servers

  dns_servers="$(dns_join_values "${DNS_SERVERS[@]:-223.5.5.5 223.6.6.6 119.29.29.29 114.114.114.114}")"
  fallback_servers="$(dns_join_values \
    "${DNS_FALLBACK_SERVERS[@]:-180.76.76.76 114.114.115.115}" \
    "${DNS_FOREIGN_FALLBACK_SERVERS[@]:-1.1.1.1 8.8.8.8}")"

  log_info "写入 systemd-resolved DNS 配置：${target}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sudo install DNS config -> ${target}"
    return 0
  fi

  tmp_file="$(mktemp)"
  cat > "${tmp_file}" <<EOF
# ArchDevKit generated. Mainland China friendly DNS baseline.
[Resolve]
DNS=${dns_servers% }
FallbackDNS=${fallback_servers% }
DNSSEC=${DNS_DNSSEC:-no}
DNSOverTLS=${DNS_OVER_TLS:-no}
Cache=${DNS_CACHE:-yes}
LLMNR=${DNS_LLMNR:-no}
MulticastDNS=${DNS_MULTICAST_DNS:-no}
EOF

  run_sudo install -d -m 0755 /etc/systemd/resolved.conf.d
  backup_file_root "${target}"
  run_sudo install -m 0644 "${tmp_file}" "${target}"
  rm -f "${tmp_file}"
}

configure_networkmanager_dns_backend() {
  [[ "${DNS_CONFIGURE_NETWORKMANAGER:-1}" -eq 1 ]] || return 0

  local target="/etc/NetworkManager/conf.d/90-archdevkit-dns.conf"
  local tmp_file

  log_info "配置 NetworkManager 使用 systemd-resolved：${target}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sudo install NetworkManager DNS config -> ${target}"
    return 0
  fi

  tmp_file="$(mktemp)"
  cat > "${tmp_file}" <<'EOF'
# ArchDevKit generated. Keep NetworkManager and systemd-resolved aligned.
[main]
dns=systemd-resolved
rc-manager=symlink
EOF

  run_sudo install -d -m 0755 /etc/NetworkManager/conf.d
  backup_file_root "${target}"
  run_sudo install -m 0644 "${tmp_file}" "${target}"
  rm -f "${tmp_file}"
}

enable_systemd_resolved() {
  log_info "启用 systemd-resolved"
  run_sudo systemctl enable --now systemd-resolved.service

  if [[ "${DNS_RESTART_NETWORKMANAGER:-0}" -eq 1 ]] && dns_systemd_unit_exists NetworkManager.service; then
    log_warn "按配置重载 NetworkManager，当前网络连接可能短暂中断"
    run_sudo systemctl try-reload-or-restart NetworkManager.service || \
      log_warn "NetworkManager 重载失败，可稍后手动执行：sudo systemctl restart NetworkManager"
  elif dns_systemd_unit_exists NetworkManager.service; then
    log_warn "NetworkManager DNS 后端配置将在服务重启后完全生效"
  fi
}

link_resolv_conf_to_resolved() {
  [[ "${DNS_LINK_RESOLV_CONF:-1}" -eq 1 ]] || return 0

  local target="/run/systemd/resolve/stub-resolv.conf"

  log_info "设置 /etc/resolv.conf 指向 systemd-resolved stub"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sudo ln -sfn ${target} /etc/resolv.conf"
    return 0
  fi

  if [[ -L /etc/resolv.conf && "$(readlink /etc/resolv.conf)" == "${target}" ]]; then
    return 0
  fi

  backup_file_root /etc/resolv.conf
  run_sudo ln -sfn "${target}" /etc/resolv.conf
}

verify_dns_env() {
  log_info "验证 DNS 配置"
  run_cmd resolvectl status || true
}

ensure_dns_env() {
  if [[ "${ENABLE_DNS:-0}" -eq 1 ]]; then
    install_dns_env
  else
    log_info "当前配置未启用 DNS 模块，跳过"
  fi
}
