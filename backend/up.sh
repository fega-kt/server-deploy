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

write_env "VAULT_TOKEN=$VAULT_TOKEN" "VAULT_SECRET_PATH_MAPPED=$SECRET_PATH" "VAULT_AUTH_METHOD=token"
echo -e "${GREEN}✔ Secrets written to .env${NC}"
deploy
