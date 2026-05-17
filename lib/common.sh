#!/usr/bin/env bash
# 公共函数库：日志、确认、备份、命令执行、GitHub 代理、模块执行标记。

declare -gA MODULE_DONE=()

log_info()  { printf '\033[32m----> %s\033[0m\n' "$*"; }
log_warn()  { printf '\033[33m----> %s\033[0m\n' "$*"; }
log_error() { printf '\033[31m----> %s\033[0m\n' "$*" >&2; }
die()       { log_error "$*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }
require_cmd() { need_cmd "$1" || die "缺少命令：$1"; }
require_arch() { [[ -f /etc/arch-release ]] && need_cmd pacman || die "当前脚本只支持 Arch Linux / Arch 系发行版"; }
require_normal_user() { [[ "${EUID}" -ne 0 ]] || die "请使用普通用户执行脚本，不要直接使用 root 或 sudo 执行"; }

bool_text() {
  case "${1:-0}" in
    1|true|yes|on) printf "启用" ;;
    0|false|no|off) printf "关闭" ;;
    *) printf "%s" "$1" ;;
  esac
}

to_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
pause() { read -r -p "按回车键继续..." _; }

mark_done() { MODULE_DONE["$1"]=1; }
is_done() { [[ "${MODULE_DONE[$1]:-0}" -eq 1 ]]; }

run_cmd() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf '+'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

run_sudo() {
  if [[ "${EUID}" -eq 0 ]]; then run_cmd "$@"; else run_cmd sudo "$@"; fi
}

pacman_update() {
  require_arch
  log_info "刷新并更新系统软件包"
  run_sudo pacman -Syu --noconfirm
}

pacman_install() {
  require_arch
  [[ "$#" -eq 0 ]] && return 0
  log_info "安装软件包：$*"
  run_sudo pacman -S --needed --noconfirm "$@"
}

pacman_package_available() {
  local package="$1"
  pacman -Si "${package}" >/dev/null 2>&1
}

pacman_package_installed() {
  local package="$1"
  pacman -Q "${package}" >/dev/null 2>&1
}

install_aur_package() {
  local package="$1" aur_url tmp_dir package_dir
  [[ -n "${package}" ]] || die "AUR 包名为空"

  require_cmd git
  require_cmd makepkg

  aur_url="https://aur.archlinux.org/${package}.git"
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/archdevkit-aur-${package}.XXXXXX")"
  package_dir="${tmp_dir}/${package}"

  log_info "从 AUR 安装：${package}"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ git clone ${aur_url} ${package_dir}"
    echo "+ cd ${package_dir} && makepkg -si --needed --noconfirm"
    rmdir "${tmp_dir}"
    return 0
  fi

  git clone "${aur_url}" "${package_dir}" || {
    rm -rf "${tmp_dir}"
    die "克隆 AUR 仓库失败：${aur_url}"
  }

  (cd "${package_dir}" && makepkg -si --needed --noconfirm) || {
    rm -rf "${tmp_dir}"
    die "AUR 包安装失败：${package}"
  }

  rm -rf "${tmp_dir}"
}

install_package_or_aur() {
  local package="$1"
  [[ -n "${package}" ]] || die "软件包名为空"

  if pacman_package_installed "${package}"; then
    log_info "软件包已安装：${package}"
    return 0
  fi

  if pacman_package_available "${package}"; then
    pacman_install "${package}"
  else
    log_warn "当前 pacman 源未提供 ${package}，改用 AUR 构建安装"
    install_aur_package "${package}"
  fi
}

backup_path() {
  local path="$1"
  [[ -n "${path}" ]] || die "备份路径为空"
  [[ -e "${path}" || -L "${path}" ]] || return 0
  local bak="${path}.bak.$(date +%Y%m%d-%H%M%S)"
  mv "${path}" "${bak}"
  log_warn "已备份：${path} -> ${bak}"
}

backup_file_root() {
  local file="$1"
  [[ -n "${file}" ]] || die "备份文件路径为空"
  [[ -e "${file}" ]] || return 0
  local bak="${file}.bak.$(date +%Y%m%d-%H%M%S)"
  run_sudo cp -a "${file}" "${bak}"
  log_warn "已备份：${file} -> ${bak}"
}

append_unique_line() {
  local line="$1" file="$2"
  mkdir -p "$(dirname "${file}")"
  touch "${file}"
  grep -Fqx -- "${line}" "${file}" || echo "${line}" >> "${file}"
}

ask_value() {
  local prompt="$1" default_value="$2" input
  read -r -p "${prompt} [${default_value}]: " input
  printf '%s' "${input:-${default_value}}"
}

confirm_yes() {
  local prompt="$1" input
  [[ "${ASSUME_YES:-0}" -eq 1 ]] && return 0
  read -r -p "${prompt} [Y/n]: " input
  input="$(to_lower "${input:-yes}")"
  case "${input}" in y|yes) return 0 ;; n|no) return 1 ;; *) log_warn "请输入 y/yes 或 n/no"; confirm_yes "${prompt}" ;; esac
}

confirm_no() {
  local prompt="$1" input
  [[ "${ASSUME_YES:-0}" -eq 1 ]] && return 0
  read -r -p "${prompt} [y/N]: " input
  input="$(to_lower "${input:-no}")"
  case "${input}" in y|yes) return 0 ;; n|no) return 1 ;; *) log_warn "请输入 y/yes 或 n/no"; confirm_no "${prompt}" ;; esac
}

normalize_url_slash() {
  local url="$1"
  [[ "${url}" == */ ]] || url="${url}/"
  printf '%s' "${url}"
}

github_proxy_url() {
  local url="$1" proxy
  if [[ "${ENABLE_GITHUB_PROXY:-0}" -eq 1 && "${url}" == https://github.com/* ]]; then
    proxy="$(normalize_url_slash "${GITHUB_PROXY}")"
    printf '%s%s' "${proxy}" "${url}"
  else
    printf '%s' "${url}"
  fi
}

run_with_github_proxy() {
  local proxy
  if [[ "${ENABLE_GITHUB_PROXY:-0}" -eq 1 ]]; then
    proxy="$(normalize_url_slash "${GITHUB_PROXY}")"
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      log_info "dry-run：将使用临时 GitHub 代理执行命令：${proxy}"
      printf '+'; printf ' %q' "$@"; printf '\n'; return 0
    fi
    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0="url.${proxy}https://github.com/.insteadOf" \
    GIT_CONFIG_VALUE_0="https://github.com/" \
    "$@"
  else
    run_cmd "$@"
  fi
}

clone_repo_safe() {
  local repo_url="$1" target_dir="$2" branch="${3:-}" actual_url tmp_dir
  [[ -n "${repo_url}" ]] || die "仓库地址为空"
  [[ -n "${target_dir}" ]] || die "目标目录为空"
  actual_url="$(github_proxy_url "${repo_url}")"
  tmp_dir="$(mktemp -d)"
  log_info "准备克隆仓库：${repo_url}"
  [[ "${repo_url}" != "${actual_url}" ]] && log_info "实际下载地址：${actual_url}"
  local args=(clone --depth=1)
  [[ -n "${branch}" ]] && args+=(-b "${branch}")
  args+=("${actual_url}" "${tmp_dir}/repo")
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf '+ git'; printf ' %q' "${args[@]}"; printf '\n'; rm -rf "${tmp_dir}"; return 0
  fi
  git "${args[@]}" || { rm -rf "${tmp_dir}"; die "克隆仓库失败：${repo_url}"; }
  mkdir -p "$(dirname "${target_dir}")"
  backup_path "${target_dir}"
  mv "${tmp_dir}/repo" "${target_dir}"
  rm -rf "${tmp_dir}"
  log_info "仓库已安装到：${target_dir}"
}
