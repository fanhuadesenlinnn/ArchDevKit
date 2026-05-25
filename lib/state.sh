#!/usr/bin/env bash
# 模块状态：安装成功记录、状态校验、跳过判断和 status 输出。

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
  local modules=() target="${TARGET:-all}"
  if [[ "${target}" == "all" ]]; then
    read -r -a modules <<<"$(all_modules)"
  else
    read -r -a modules <<<"$(modules_for_target "${target}")"
  fi

  if [[ "${OUTPUT_JSON:-0}" -eq 1 ]]; then
    state_status_json "${modules[@]}"
  else
    state_status_text "${modules[@]}"
  fi
}
