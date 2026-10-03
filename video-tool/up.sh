#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

source "../lib/vault-common.sh"

check_vault_json
read_vault_addr

SECRET_PATH=$(jq -r '.envs.production // empty' .vault.json)
KV=$(jq -r '.kv // 2' .vault.json)
[ -z "$SECRET_PATH" ] && { echo -e "${RED}[up.sh] Secret path is required. Set \"envs.production\" in .vault.json.${NC}" >&2; exit 1; }

vault_login
fetch_secrets "$SECRET_PATH" "$KV"

write_env

# Container chạy với UID 1000 — thư mục dữ liệu và thư mục video phải ghi được.
OUTPUT_PATH=$(grep -E '^OUTPUT_PATH=' .env | tail -1 | cut -d= -f2- || true)
mkdir -p data "${OUTPUT_PATH:-data/output}"
if [ "$(stat -c %u data)" != "1000" ]; then
  sudo chown -R 1000:1000 data "${OUTPUT_PATH:-data/output}"
fi

deploy
