#!/usr/bin/env bash
# Runtime 模块
# 使用 mise 统一管理当前用户的 Node.js / npm / Python / Go 版本。

setup_mise_shell() {
  log_info "配置 mise shell 初始化"
  append_unique_line 'eval "$(mise activate bash)"' "${HOME}/.bashrc"
  append_unique_line 'eval "$(mise activate zsh)"' "${HOME}/.zshrc"
  log_warn "mise 初始化已写入 ~/.bashrc 和 ~/.zshrc，重新打开终端后完全生效"
}

install_runtime_env() {
  if is_done "runtime"; then
    log_info "Runtime 环境已处理，跳过"
    return 0
  fi

  ensure_base
  log_info "开始安装 Runtime 环境：mise + Node.js/npm/Python/Go"
  pacman_install mise
  setup_mise_shell

  log_info "使用 mise 安装 Node.js ${NODE_VERSION}"
  run_cmd mise use -g node@"${NODE_VERSION}"

  log_info "使用 Node.js 自带 npm 安装 npm ${NPM_VERSION}"
  run_cmd mise exec -- npm install -g npm@"${NPM_VERSION}"

  log_info "使用 mise 安装 Python ${PYTHON_VERSION}"
  run_cmd mise use -g python@"${PYTHON_VERSION}"

  log_info "使用 mise 安装 Go ${GO_VERSION}"
  run_cmd mise use -g go@"${GO_VERSION}"

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
