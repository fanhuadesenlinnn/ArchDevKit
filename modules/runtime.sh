#!/usr/bin/env bash
# Runtime 模块
# 使用 mise 统一管理当前用户的 Node.js / npm / Python / Go 版本。

setup_mise_shell() {
  log_info "配置 mise shell 初始化"
  # shellcheck disable=SC2016
  append_unique_line 'eval "$(mise activate bash)"' "${HOME}/.bashrc"
  # shellcheck disable=SC2016
  append_unique_line 'eval "$(mise activate zsh)"' "${HOME}/.zshrc"
  log_warn "mise 初始化已写入 ~/.bashrc 和 ~/.zshrc，重新打开终端后完全生效"
}

mise_china_env_prefix() {
  local envs=()

  [[ "${ENABLE_CHINA_MIRROR:-0}" -eq 1 ]] || return 0

  [[ -n "${NODE_MIRROR_URL:-}" ]] && envs+=("MISE_NODE_MIRROR_URL=${NODE_MIRROR_URL}")
  [[ -n "${GO_DOWNLOAD_MIRROR:-}" ]] && envs+=("MISE_GO_DOWNLOAD_MIRROR=${GO_DOWNLOAD_MIRROR}")

  if [[ "${#envs[@]}" -gt 0 ]]; then
    printf 'env'
    printf ' %q' "${envs[@]}"
  fi
}

mise_run() {
  local env_prefix
  env_prefix="$(mise_china_env_prefix)"

  if [[ -n "${env_prefix}" ]]; then
    # shellcheck disable=SC2086
    run_cmd ${env_prefix} mise "$@"
  else
    run_cmd mise "$@"
  fi
}

configure_mise_china_mirrors() {
  [[ "${ENABLE_CHINA_MIRROR:-0}" -eq 1 ]] || return 0

  log_info "配置 mise 国内下载镜像"

  if [[ -n "${NODE_MIRROR_URL:-}" ]]; then
    log_info "配置 mise Node.js 镜像：${NODE_MIRROR_URL}"
    mise_run settings set node.mirror_url "${NODE_MIRROR_URL}" || true
  fi

  if [[ -n "${GO_DOWNLOAD_MIRROR:-}" ]]; then
    log_info "配置 mise Go 下载镜像：${GO_DOWNLOAD_MIRROR}"
    mise_run settings set go.download_mirror "${GO_DOWNLOAD_MIRROR}" || true
  fi

  if [[ "${ENABLE_MISE_GITHUB_URL_REPLACEMENT:-0}" -eq 1 && "${ENABLE_GITHUB_PROXY:-0}" -eq 1 && -n "${GITHUB_PROXY:-}" ]]; then
    log_info "配置 mise GitHub URL 替换：${GITHUB_PROXY}"
    mise_run settings set url_replacements.github "${GITHUB_PROXY}https://github.com" || true
  fi
}

install_runtime_env() {
  if is_done "runtime"; then
    log_info "Runtime 环境已处理，跳过"
    return 0
  fi

  log_info "开始安装 Runtime 环境：mise + Node.js/npm/Python/Go"
  pacman_install mise
  setup_mise_shell
  configure_mise_china_mirrors

  log_info "使用 mise 安装 Node.js ${NODE_VERSION}"
  mise_run use -g node@"${NODE_VERSION}"

  log_info "使用 Node.js 自带 npm 安装 npm ${NPM_VERSION}"
  run_cmd mise exec -- npm install -g npm@"${NPM_VERSION}"

  log_info "使用 mise 安装 Python ${PYTHON_VERSION}"
  mise_run use -g python@"${PYTHON_VERSION}"

  log_info "使用 mise 安装 Go ${GO_VERSION}"
  mise_run use -g go@"${GO_VERSION}"

  if [[ "${ENABLE_CHINA_MIRROR:-0}" -eq 1 ]]; then
    log_info "配置 npm 国内源：${NPM_REGISTRY}"
    run_cmd mise exec -- npm config set registry "${NPM_REGISTRY}"

    log_info "配置 pip 国内源：${PIP_INDEX_URL}"
    run_cmd mise exec -- python -m pip config set global.index-url "${PIP_INDEX_URL}"
    run_cmd mise exec -- python -m pip config set install.trusted-host "${PIP_TRUSTED_HOST}" || true
  fi

  if [[ "${ENABLE_COREPACK:-0}" -eq 1 ]]; then
    log_info "启用 corepack，方便 pnpm/yarn 项目使用"
    run_cmd mise exec -- corepack enable || log_warn "corepack 启用失败，可忽略或稍后手动处理"
  fi

  if [[ "${INSTALL_PYNVIM:-0}" -eq 1 ]]; then
    log_info "安装 Python pynvim provider"
    run_cmd mise exec -- python -m pip install -U pynvim
  fi

  verify_runtime
  mark_done "runtime"
  log_info "Runtime 环境安装完成"
}

verify_runtime() {
  log_info "验证 Runtime 版本"
  run_cmd mise exec -- node -v
  run_cmd mise exec -- npm -v
  run_cmd mise exec -- python --version
  run_cmd mise exec -- go version
}

ensure_runtime() {
  if ! is_done "runtime"; then
    install_runtime_env
  fi
}
