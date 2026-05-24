#!/usr/bin/env bash
# Proxy 模块
# 负责安装 Mihomo / sing-box 代理核心。
# Mihomo 使用系统级 /etc/mihomo 配置和包自带 systemd 服务；sing-box 仍使用 ArchDevKit 用户级服务。

proxy_service_name() {
  case "${PROXY_CORE:-mihomo}" in
    mihomo) printf "%s" "${MIHOMO_SERVICE_NAME:-mihomo.service}" ;;
    sing-box) printf "archdevkit-sing-box.service" ;;
    *) die "未知代理核心：${PROXY_CORE}" ;;
  esac
}

install_proxy_shell_env_template() {
  local rc_file line
  local lines=(
    "# ArchDevKit proxy environment template. Uncomment when needed."
    "# export http_proxy=\"http://127.0.0.1:7890\""
    "# export https_proxy=\"http://127.0.0.1:7890\""
    "# export all_proxy=\"socks5://127.0.0.1:7890\""
    "# export HTTP_PROXY=\"\$http_proxy\""
    "# export HTTPS_PROXY=\"\$https_proxy\""
    "# export ALL_PROXY=\"\$all_proxy\""
    "# export no_proxy=\"localhost,127.0.0.1,::1\""
    "# export NO_PROXY=\"\$no_proxy\""
  )

  log_info "写入 shell 代理环境变量模板（默认注释）"
  for rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
    for line in "${lines[@]}"; do
      append_unique_line "${line}" "${rc_file}"
    done
  done
}

proxy_needs_archlinuxcn() {
  local package
  case "${PROXY_CORE:-mihomo}" in
    mihomo)
      package="${MIHOMO_PACKAGE:-mihomo}"
      package_needs_archlinuxcn_repo "${package}" && return 0
      if [[ "${ENABLE_METACUBEXD:-0}" -eq 1 ]]; then
        package_needs_archlinuxcn_repo "${METACUBEXD_PACKAGE:-metacubexd-bin}" && return 0
      fi
      ;;
    sing-box)
      package_needs_archlinuxcn_repo "${SING_BOX_PACKAGE:-sing-box}" && return 0
      ;;
  esac

  return 1
}

proxy_config_source_to_file() {
  local source="$1" target="$2" actual_source tmp_file
  [[ -n "${target}" ]] || die "代理配置目标文件为空"

  mkdir -p "$(dirname "${target}")"
  [[ -n "${source}" ]] || return 1
  actual_source="$(github_proxy_url "${source}")"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ install config ${actual_source} -> ${target}"
    return 0
  fi

  tmp_file="$(mktemp)"
  case "${actual_source}" in
    http://*|https://*)
      ensure_curl_command
      log_info "下载代理配置：${source}"
      [[ "${source}" != "${actual_source}" ]] && log_info "实际下载地址：${actual_source}"
      curl -fL "${actual_source}" -o "${tmp_file}" || {
        rm -f "${tmp_file}"
        die "下载代理配置失败：${source}"
      }
      ;;
    *)
      [[ -f "${actual_source}" ]] || die "代理配置文件不存在：${source}"
      cp -a "${actual_source}" "${tmp_file}"
      ;;
  esac

  backup_path "${target}"
  install -m 0600 "${tmp_file}" "${target}"
  rm -f "${tmp_file}"
}

proxy_config_source_to_root_file() {
  local source="$1" target="$2" mode="${3:-0600}" actual_source tmp_file
  [[ -n "${target}" ]] || die "代理配置目标文件为空"
  [[ -n "${source}" ]] || return 1
  actual_source="$(github_proxy_url "${source}")"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sudo install config ${actual_source} -> ${target}"
    return 0
  fi

  tmp_file="$(mktemp)"
  case "${actual_source}" in
    http://*|https://*)
      ensure_curl_command
      log_info "下载代理配置：${source}"
      [[ "${source}" != "${actual_source}" ]] && log_info "实际下载地址：${actual_source}"
      curl -fL "${actual_source}" -o "${tmp_file}" || {
        rm -f "${tmp_file}"
        die "下载代理配置失败：${source}"
      }
      ;;
    *)
      [[ -f "${actual_source}" ]] || die "代理配置文件不存在：${source}"
      cp -a "${actual_source}" "${tmp_file}"
      ;;
  esac

  run_sudo mkdir -p "$(dirname "${target}")"
  backup_file_root "${target}"
  run_sudo install -m "${mode}" "${tmp_file}" "${target}"
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

mihomo_unit_file() {
  local service="${1:-${MIHOMO_SERVICE_NAME:-mihomo.service}}" unit_file

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf "/usr/lib/systemd/system/%s" "${service}"
    return 0
  fi

  unit_file="$(systemctl show -P FragmentPath "${service}" 2>/dev/null || true)"
  [[ -n "${unit_file}" ]] && printf "%s" "${unit_file}"
}

mihomo_unit_setting_value() {
  local unit_file="$1" key="$2"
  [[ -n "${unit_file}" && -r "${unit_file}" ]] || return 1
  sed -n "s/^${key}=//p" "${unit_file}" | tail -n 1
}

mihomo_unit_has_setting() {
  local unit_file="$1" pattern="$2"
  [[ -n "${unit_file}" && -r "${unit_file}" ]] || return 1
  grep -Eq "${pattern}" "${unit_file}"
}

mihomo_state_dir() {
  local service="${MIHOMO_SERVICE_NAME:-mihomo.service}" unit_file state_name

  [[ -n "${MIHOMO_STATE_DIR:-}" ]] && {
    printf "%s" "${MIHOMO_STATE_DIR}"
    return 0
  }

  unit_file="$(mihomo_unit_file "${service}")"
  if [[ -n "${unit_file}" ]]; then
    state_name="$(mihomo_unit_setting_value "${unit_file}" "StateDirectory" | awk '{print $1}')"
    if [[ -n "${state_name}" ]]; then
      if [[ "${state_name}" == /* ]]; then
        printf "%s" "${state_name}"
      else
        printf "/var/lib/%s" "${state_name}"
      fi
      return 0
    fi
  fi

  printf "/var/lib/mihomo"
}

mihomo_safe_external_ui_dir() {
  local state_dir requested
  state_dir="$(mihomo_state_dir)"
  requested="${MIHOMO_EXTERNAL_UI_DIR:-${state_dir}/ui}"

  case "${requested}" in
    "${state_dir}"|"${state_dir}"/*)
      printf "%s" "${requested}"
      ;;
    *)
      log_warn "Mihomo service 只允许访问 ${state_dir}；MetaCubeXD UI 目录已改为 ${state_dir}/ui" >&2
      printf "%s/ui" "${state_dir}"
      ;;
  esac
}

mihomo_rule_provider_url_prefix() {
  local prefix="${MIHOMO_RULE_PROVIDER_URL_PREFIX:-}"
  [[ "${ENABLE_GITHUB_PROXY:-0}" -eq 1 ]] || return 0
  [[ -n "${prefix}" ]] || return 0
  normalize_url_slash "${prefix}"
}

warn_mihomo_exposure() {
  if [[ "${MIHOMO_CONTROLLER_HOST:-127.0.0.1}" == "0.0.0.0" && -z "${MIHOMO_SECRET:-}" ]]; then
    log_warn "Mihomo 控制接口监听 0.0.0.0 且 MIHOMO_SECRET 为空，局域网可访问控制 API"
    log_warn "如需开放 MetaCubeXD，建议在 install_vars 设置 MIHOMO_SECRET"
  fi
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

render_proxy_template_root() {
  local template="$1" target="$2" mode="${3:-0600}" tmp_file
  shift 3 || true

  [[ -f "${template}" ]] || die "代理模板不存在：${template}"
  [[ -n "${target}" ]] || die "代理模板目标为空"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sudo render ${template} -> ${target}"
    return 0
  fi

  tmp_file="$(mktemp)"
  sed "$@" "${template}" > "${tmp_file}"

  run_sudo mkdir -p "$(dirname "${target}")"
  backup_file_root "${target}"
  run_sudo install -m "${mode}" "${tmp_file}" "${target}"
  rm -f "${tmp_file}"
}

render_mihomo_config_template() {
  local template="$1" target="$2"
  local allow_lan secret external_ui_line external_ui_dir rule_provider_prefix

  warn_mihomo_exposure
  allow_lan="$(sed_escape_replacement "$(bool_to_yaml "${MIHOMO_ALLOW_LAN:-0}")")"
  secret="$(sed_escape_replacement "$(quote_yaml_string "${MIHOMO_SECRET:-}")")"
  rule_provider_prefix="$(sed_escape_replacement "$(mihomo_rule_provider_url_prefix)")"
  if [[ "${ENABLE_METACUBEXD:-0}" -eq 1 ]]; then
    external_ui_dir="$(mihomo_safe_external_ui_dir)"
    external_ui_line="$(sed_escape_replacement "external-ui: ${external_ui_dir}")"
  else
    external_ui_line=""
  fi

  render_proxy_template_root "${template}" "${target}" 0600 \
    -e "s/__MIHOMO_MIXED_PORT__/$(sed_escape_replacement "${MIHOMO_MIXED_PORT:-7890}")/g" \
    -e "s/__MIHOMO_ALLOW_LAN__/${allow_lan}/g" \
    -e "s/__MIHOMO_BIND_ADDRESS__/$(sed_escape_replacement "${MIHOMO_BIND_ADDRESS:-127.0.0.1}")/g" \
    -e "s/__MIHOMO_CONTROLLER_HOST__/$(sed_escape_replacement "${MIHOMO_CONTROLLER_HOST:-127.0.0.1}")/g" \
    -e "s/__MIHOMO_CONTROLLER_PORT__/$(sed_escape_replacement "${MIHOMO_CONTROLLER_PORT:-9090}")/g" \
    -e "s/__MIHOMO_DNS_LISTEN__/$(sed_escape_replacement "${MIHOMO_DNS_LISTEN:-127.0.0.1:1053}")/g" \
    -e "s/__MIHOMO_SECRET_YAML__/${secret}/g" \
    -e "s/__MIHOMO_RULE_PROVIDER_URL_PREFIX__/${rule_provider_prefix}/g" \
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
  [[ -e "${config_file}" ]] || return 1

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    return 1
  fi

  if [[ -r "${config_file}" ]]; then
    grep -Fq "https://example.com/your-subscription-url" "${config_file}"
  else
    sudo grep -Fq "https://example.com/your-subscription-url" "${config_file}"
  fi
}

inspect_mihomo_systemd_service() {
  local service="${MIHOMO_SERVICE_NAME:-mihomo.service}" unit_file
  unit_file="$(mihomo_unit_file "${service}")"

  if [[ -z "${unit_file}" ]]; then
    log_warn "未找到 ${service} 的 systemd unit，稍后启用服务可能失败"
    return 0
  fi

  log_info "检测 Mihomo systemd unit：${unit_file}"
  if mihomo_unit_has_setting "${unit_file}" '^StateDirectory=' && \
     mihomo_unit_has_setting "${unit_file}" '^LoadCredential=.*config\.ya?ml'; then
    log_info "检测到 ${service} 使用 StateDirectory + LoadCredential，按服务运行目录校验配置"
  else
    log_warn "${service} 未使用预期的 StateDirectory + LoadCredential 模式，请留意发行版包差异"
  fi
}

mihomo_stop_failed_service() {
  local service="${MIHOMO_SERVICE_NAME:-mihomo.service}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sudo systemctl disable --now ${service}"
    echo "+ sudo systemctl reset-failed ${service}"
    return 0
  fi

  run_sudo systemctl disable --now "${service}" || true
  run_sudo systemctl reset-failed "${service}" || true
}

mihomo_test_config_for_service() {
  local config_file="$1" state_dir
  [[ -n "${config_file}" ]] || die "Mihomo 配置文件为空"
  state_dir="$(mihomo_state_dir)"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sudo install ${config_file} ${state_dir}/config.yaml"
    echo "+ sudo mihomo -t -d ${state_dir}"
    echo "+ sudo rm -f ${state_dir}/config.yaml"
    return 0
  fi

  require_cmd mihomo
  run_sudo mkdir -p "${state_dir}"
  if [[ -r "${config_file}" ]]; then
    run_sudo install -m 0600 "${config_file}" "${state_dir}/config.yaml"
  else
    sudo install -m 0600 "${config_file}" "${state_dir}/config.yaml"
  fi

  if run_sudo mihomo -t -d "${state_dir}"; then
    run_sudo rm -f "${state_dir}/config.yaml"
    return 0
  fi

  run_sudo rm -f "${state_dir}/config.yaml"
  return 1
}

mihomo_service_ready() {
  local config_file="${MIHOMO_CONFIG_FILE:-/etc/mihomo/config.yaml}"

  inspect_mihomo_systemd_service

  if mihomo_config_has_placeholder_subscription "${config_file}"; then
    log_warn "Mihomo 配置仍使用示例订阅地址，不能保证服务启动成功"
    log_warn "请先替换 proxy-providers.airport.url，或使用 --mihomo-config 指定自己的配置"
    mihomo_stop_failed_service
    return 1
  fi

  log_info "按 mihomo.service 的运行方式测试配置"
  if mihomo_test_config_for_service "${config_file}"; then
    return 0
  fi

  log_warn "Mihomo 配置测试失败，已跳过自动启动服务，避免 systemd 反复重启"
  log_warn "可查看详细日志：sudo journalctl -u ${MIHOMO_SERVICE_NAME:-mihomo.service} -n 80 --no-pager"
  mihomo_stop_failed_service
  return 1
}

install_proxy_env() {
  if is_done "proxy"; then
    log_info "Proxy 环境已处理，跳过"
    return 0
  fi

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

  install_proxy_shell_env_template
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
  local config_file="${MIHOMO_CONFIG_FILE:-/etc/mihomo/config.yaml}"
  local config_dir="${MIHOMO_CONFIG_DIR:-$(dirname "${config_file}")}"

  log_info "配置 Mihomo：${config_file}"
  run_sudo mkdir -p "${config_dir}" "${config_dir}/providers" "${config_dir}/ruleset"
  if is_default_mihomo_config_source; then
    render_default_mihomo_config "${config_file}"
  elif [[ "${MIHOMO_CONFIG_SOURCE:-}" == *.tpl && "${MIHOMO_CONFIG_SOURCE:-}" != http://* && "${MIHOMO_CONFIG_SOURCE:-}" != https://* ]]; then
    render_mihomo_config_template "${MIHOMO_CONFIG_SOURCE}" "${config_file}"
  elif proxy_config_source_to_root_file "${MIHOMO_CONFIG_SOURCE:-}" "${config_file}" 0600; then
    :
  else
    render_default_mihomo_config "${config_file}"
  fi
}

install_metacubexd() {
  local package="${METACUBEXD_PACKAGE:-metacubexd-bin}"
  local source_root="${METACUBEXD_WEB_ROOT:-/usr/share/metacubexd}"
  local target_root
  target_root="$(mihomo_safe_external_ui_dir)"

  log_info "安装 MetaCubeXD 面板：${package}"
  install_package_or_aur "${package}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sudo install MetaCubeXD UI ${source_root} -> ${target_root}"
    return 0
  fi

  [[ -f "${source_root}/index.html" ]] || \
    log_warn "未找到 MetaCubeXD 静态入口：${source_root}/index.html，请检查面板包安装路径"

  if [[ -f "${source_root}/index.html" ]]; then
    run_sudo rm -rf "${target_root}"
    run_sudo mkdir -p "$(dirname "${target_root}")"
    run_sudo cp -a "${source_root}" "${target_root}"
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

enable_system_service() {
  local service="$1"
  [[ -n "${service}" ]] || die "systemd 系统服务名为空"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sudo systemctl daemon-reload"
    echo "+ sudo systemctl enable --now ${service}"
    echo "+ sudo systemctl is-active --quiet ${service}"
    return 0
  fi

  run_sudo systemctl daemon-reload || \
    log_warn "systemd 服务刷新失败，请稍后手动执行：sudo systemctl daemon-reload"
  run_sudo systemctl enable --now "${service}" || {
    log_warn "系统服务启用失败，可稍后手动执行：sudo systemctl enable --now ${service}"
    return 1
  }

  sleep 2
  if run_sudo systemctl is-active --quiet "${service}"; then
    log_info "系统服务已启动：${service}"
    return 0
  fi

  log_warn "系统服务未保持 active：${service}"
  run_sudo journalctl -u "${service}" -n 50 --no-pager || true
  return 1
}

enable_proxy_service_if_needed() {
  [[ "${PROXY_AUTO_ENABLE_SERVICE:-0}" -eq 1 ]] || {
    log_warn "当前配置不自动启用 Proxy 服务"
    return 0
  }

  case "${PROXY_CORE:-mihomo}" in
    mihomo)
      if mihomo_service_ready; then
        enable_system_service "$(proxy_service_name)" || die "Mihomo 服务启动失败，请根据上方日志修正配置后重试"
      else
        log_warn "已跳过 Mihomo 服务启动；配置修正后执行：sudo systemctl enable --now ${MIHOMO_SERVICE_NAME:-mihomo.service}"
      fi
      ;;
    sing-box) enable_user_service "$(proxy_service_name)" ;;
  esac
}

verify_proxy_env() {
  log_info "验证 Proxy 环境"
  case "${PROXY_CORE:-mihomo}" in
    mihomo)
      run_cmd mihomo -v || true
      log_info "Mihomo 配置目录：${MIHOMO_CONFIG_DIR:-/etc/mihomo}"
      log_info "Mihomo 配置文件：${MIHOMO_CONFIG_FILE:-/etc/mihomo/config.yaml}"
      log_info "Mihomo 系统服务：${MIHOMO_SERVICE_NAME:-mihomo.service}"
      log_info "Mihomo mixed-port：${MIHOMO_BIND_ADDRESS:-127.0.0.1}:${MIHOMO_MIXED_PORT:-7890}"
      log_info "Mihomo 控制接口：http://${MIHOMO_CONTROLLER_HOST:-127.0.0.1}:${MIHOMO_CONTROLLER_PORT:-9090}"
      log_info "Mihomo 规则源前缀：$(mihomo_rule_provider_url_prefix)"
      if [[ "${ENABLE_METACUBEXD:-0}" -eq 1 ]]; then
        log_info "MetaCubeXD 面板由 Mihomo 托管：http://${MIHOMO_CONTROLLER_HOST:-127.0.0.1}:${MIHOMO_CONTROLLER_PORT:-9090}/ui/"
        log_info "MetaCubeXD UI 目录：$(mihomo_safe_external_ui_dir)"
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
