#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

source "../lib/vault-common.sh"

check_vault_json
read_vault_addr

VAULT_SECRET_PATH=$(jq -r '.path // empty' .vault.json)
[ -z "$VAULT_SECRET_PATH" ] && { echo -e "${RED}[up.sh] Vault secret path is required. Set \"path\" in .vault.json.${NC}" >&2; exit 1; }

vault_login
fetch_secrets "$VAULT_SECRET_PATH"
export_secrets_to_shell
echo "[up.sh] Config loaded from Vault"

write_env "VAULT_ADDR=$VAULT_ADDR" "VAULT_TOKEN=$VAULT_TOKEN" "VAULT_SECRET_PATH=$VAULT_SECRET_PATH"
echo -e "${GREEN}✔ .env written to $(pwd)/.env — subsequent 'docker compose up -d' will work without re-authenticating${NC}"

export VAULT_ADDR VAULT_TOKEN VAULT_SECRET_PATH
deploy
