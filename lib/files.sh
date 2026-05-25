#!/usr/bin/env bash
# 文件写入公共操作：统一临时文件、备份、安装权限、root 写入和模板渲染。

install_file_from_temp() {
  local tmp_file="$1" target="$2" mode="${3:-0644}"
  [[ -n "${tmp_file}" && -f "${tmp_file}" ]] || die "临时文件不存在：${tmp_file}"
  [[ -n "${target}" ]] || die "目标文件路径为空"

  mkdir -p "$(dirname "${target}")"
  backup_path "${target}"
  install -m "${mode}" "${tmp_file}" "${target}"
}

install_root_file_from_temp() {
  local tmp_file="$1" target="$2" mode="${3:-0644}"
  [[ -n "${tmp_file}" && -f "${tmp_file}" ]] || die "临时文件不存在：${tmp_file}"
  [[ -n "${target}" ]] || die "root 目标文件路径为空"

  run_sudo mkdir -p "$(dirname "${target}")"
  backup_file_root "${target}"
  run_sudo install -m "${mode}" "${tmp_file}" "${target}"
}

write_file_from_stdin() {
  local target="$1" mode="${2:-0644}" tmp_file
  [[ -n "${target}" ]] || die "目标文件路径为空"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ write ${target}"
    return 0
  fi

  tmp_file="$(mktemp)"
  if ! cat > "${tmp_file}"; then
    rm -f "${tmp_file}"
    return 1
  fi
  install_file_from_temp "${tmp_file}" "${target}" "${mode}"
  rm -f "${tmp_file}"
}

write_root_file_from_stdin() {
  local target="$1" mode="${2:-0644}" tmp_file
  [[ -n "${target}" ]] || die "root 目标文件路径为空"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sudo write ${target}"
    return 0
  fi

  tmp_file="$(mktemp)"
  if ! cat > "${tmp_file}"; then
    rm -f "${tmp_file}"
    return 1
  fi
  install_root_file_from_temp "${tmp_file}" "${target}" "${mode}"
  rm -f "${tmp_file}"
}

render_template_file() {
  local template="$1" target="$2" mode="${3:-0644}" tmp_file
  shift 3 || true

  [[ -f "${template}" ]] || die "模板文件不存在：${template}"
  [[ -n "${target}" ]] || die "模板目标文件路径为空"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ render ${template} -> ${target}"
    return 0
  fi

  tmp_file="$(mktemp)"
  if [[ "$#" -gt 0 ]]; then
    sed "$@" "${template}" > "${tmp_file}" || {
      rm -f "${tmp_file}"
      return 1
    }
  else
    cp -a "${template}" "${tmp_file}" || {
      rm -f "${tmp_file}"
      return 1
    }
  fi
  install_file_from_temp "${tmp_file}" "${target}" "${mode}"
  rm -f "${tmp_file}"
}

render_template_root_file() {
  local template="$1" target="$2" mode="${3:-0644}" tmp_file
  shift 3 || true

  [[ -f "${template}" ]] || die "模板文件不存在：${template}"
  [[ -n "${target}" ]] || die "root 模板目标文件路径为空"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sudo render ${template} -> ${target}"
    return 0
  fi

  tmp_file="$(mktemp)"
  if [[ "$#" -gt 0 ]]; then
    sed "$@" "${template}" > "${tmp_file}" || {
      rm -f "${tmp_file}"
      return 1
    }
  else
    cp -a "${template}" "${tmp_file}" || {
      rm -f "${tmp_file}"
      return 1
    }
  fi
  install_root_file_from_temp "${tmp_file}" "${target}" "${mode}"
  rm -f "${tmp_file}"
}
