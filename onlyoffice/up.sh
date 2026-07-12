#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

source "../lib/vault-common.sh"

check_vault_json
read_vault_addr
vault_login

write_env "VAULT_ADDR=$VAULT_ADDR" "VAULT_TOKEN=$VAULT_TOKEN"
echo -e "${GREEN}✔ .env written to $(pwd)/.env${NC}"

export VAULT_ADDR VAULT_TOKEN
deploy
