#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_DIR}"

echo "==> bash syntax"
bash -n install.sh lib/*.sh modules/*.sh

echo "==> plan json"
bash install.sh plan workstation --json | ruby -rjson -e '
  data = JSON.parse(STDIN.read)
  raise "schema mismatch" unless data.fetch("schemaVersion") == "1"
  raise "command mismatch" unless data.fetch("command") == "plan"
  raise "target mismatch" unless data.fetch("target") == "workstation"
  keys = data.fetch("modules").map { |m| m.fetch("key") }
  %w[base dns proxy desktop_hyprland].each do |key|
    raise "missing module #{key}" unless keys.include?(key)
  end
'

echo "==> module registry"
bash install.sh status --json | ruby -rjson -e '
  data = JSON.parse(STDIN.read)
  keys = data.fetch("modules").map { |m| m.fetch("key") }
  expected = %w[base dns archlinuxcn git runtime nvim docker fonts shell_zsh proxy desktop_hyprland]
  raise "registry mismatch" unless keys == expected
'
bash install.sh plan base --json | ruby -rjson -e '
  data = JSON.parse(STDIN.read)
  mod = data.fetch("modules").fetch(0)
  raise "base key mismatch" unless mod.fetch("key") == "base"
  raise "base description missing" if mod.fetch("description").empty?
'

echo "==> user config file"
tmp_home="$(mktemp -d)"
mkdir -p "${tmp_home}/.config/archdevkit"
cat > "${tmp_home}/.config/archdevkit/config.env" <<'EOF'
ARCHDEVKIT_DEFAULT_PROFILE=dev
ENABLE_PROXY=0
DNS_SERVERS=223.5.5.5,119.29.29.29
DOCKER_MIRRORS=https://mirror.example.com,https://mirror2.example.com
EOF
HOME="${tmp_home}" bash install.sh plan --json | ruby -rjson -e '
  data = JSON.parse(STDIN.read)
  raise "target mismatch" unless data.fetch("target") == "dev"
  keys = data.fetch("modules").map { |m| m.fetch("key") }
  raise "proxy should be skipped" if keys.include?("proxy")
  raise "missing dns" unless keys.include?("dns")
'
rm -rf "${tmp_home}"

echo "==> status json"
bash install.sh status --json | ruby -rjson -e '
  data = JSON.parse(STDIN.read)
  raise "schema mismatch" unless data.fetch("schemaVersion") == "1"
  raise "command mismatch" unless data.fetch("command") == "status"
  raise "missing modules" unless data.fetch("modules").is_a?(Array)
'

echo "==> systemd helpers"
systemd_output="$(
  DRY_RUN=1 bash -c '
    set -Eeuo pipefail
    source lib/common.sh
    source lib/systemd.sh
    enable_system_service mihomo.service
    enable_system_service_on_boot sddm.service
    enable_user_service archdevkit-sing-box.service
  '
)"
[[ "${systemd_output}" == *"sudo systemctl daemon-reload"* ]] || { echo "missing system daemon-reload"; exit 1; }
[[ "${systemd_output}" == *"sudo systemctl enable --now mihomo.service"* ]] || { echo "missing system enable"; exit 1; }
[[ "${systemd_output}" == *"sudo systemctl enable sddm.service"* ]] || { echo "missing boot enable"; exit 1; }
[[ "${systemd_output}" == *"systemctl --user daemon-reload"* ]] || { echo "missing user daemon-reload"; exit 1; }
[[ "${systemd_output}" == *"systemctl --user enable --now archdevkit-sing-box.service"* ]] || { echo "missing user enable"; exit 1; }

echo "==> doctor json"
bash install.sh doctor --json | ruby -rjson -e '
  data = JSON.parse(STDIN.read)
  raise "schema mismatch" unless data.fetch("schemaVersion") == "1"
  raise "command mismatch" unless data.fetch("command") == "doctor"
  raise "missing checks" unless data.fetch("checks").is_a?(Array)
'

echo "==> recovery hints"
recovery_output="$(
  TARGET=workstation ARCHDEVKIT_LOG_FILE=/tmp/archdevkit-test.log bash -c '
    set -Eeuo pipefail
    source lib/module_registry.sh
    source lib/recovery.sh
    enable_install_recovery
    set_current_module runtime 3 10
    false
  ' 2>&1 || true
)"
[[ "${recovery_output}" == *"[安装中断]"* ]] || { echo "missing recovery title"; exit 1; }
[[ "${recovery_output}" == *"失败模块: runtime"* ]] || { echo "missing failed module"; exit 1; }
[[ "${recovery_output}" == *"bash install.sh install workstation --yes"* ]] || { echo "missing target retry"; exit 1; }
[[ "${recovery_output}" == *"bash install.sh install runtime --force --yes"* ]] || { echo "missing module retry"; exit 1; }
[[ "${recovery_output}" == *"bash install.sh reset-state runtime"* ]] || { echo "missing reset hint"; exit 1; }

echo "==> mihomo yaml render"
tmp_mihomo="$(mktemp)"
sed \
  -e 's/__MIHOMO_MIXED_PORT__/7890/g' \
  -e 's/__MIHOMO_ALLOW_LAN__/false/g' \
  -e 's/__MIHOMO_BIND_ADDRESS__/0.0.0.0/g' \
  -e 's/__MIHOMO_CONTROLLER_HOST__/0.0.0.0/g' \
  -e 's/__MIHOMO_CONTROLLER_PORT__/9090/g' \
  -e 's#__MIHOMO_DNS_LISTEN__#0.0.0.0:1053#g' \
  -e 's/__MIHOMO_SECRET_YAML__/""/g' \
  -e 's#__METACUBEXD_EXTERNAL_UI_LINE__#external-ui: /var/lib/mihomo/ui#g' \
  files/mihomo/config.yaml.tpl > "${tmp_mihomo}"
ruby -ryaml -e '
  data = YAML.load_file(ARGV.fetch(0))
  raise "missing direct-nameserver" unless data.dig("dns", "direct-nameserver")
  raise "airport not direct" unless data.dig("proxy-providers", "airport", "proxy") == "DIRECT"
' "${tmp_mihomo}"
rm -f "${tmp_mihomo}"

echo "==> sing-box json render"
tmp_sing_box="$(mktemp)"
sed -e 's/__SING_BOX_MIXED_PORT__/7890/g' files/sing-box/config.json.tpl > "${tmp_sing_box}"
ruby -rjson -e 'JSON.parse(File.read(ARGV.fetch(0)))' "${tmp_sing_box}"
rm -f "${tmp_sing_box}"

echo "All checks passed."
