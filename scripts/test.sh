#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_DIR}"

echo "==> bash syntax"
bash -n install.sh lib/common.sh modules/*.sh

echo "==> plan json"
bash install.sh plan workstation --json | ruby -rjson -e '
  data = JSON.parse(STDIN.read)
  raise "target mismatch" unless data.fetch("target") == "workstation"
  keys = data.fetch("modules").map { |m| m.fetch("key") }
  %w[base dns proxy desktop_hyprland].each do |key|
    raise "missing module #{key}" unless keys.include?(key)
  end
'

echo "==> status json"
bash install.sh status --json | ruby -rjson -e '
  data = JSON.parse(STDIN.read)
  raise "missing modules" unless data.fetch("modules").is_a?(Array)
'

echo "==> doctor json"
bash install.sh doctor --json | ruby -rjson -e '
  data = JSON.parse(STDIN.read)
  raise "missing checks" unless data.fetch("checks").is_a?(Array)
'

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
