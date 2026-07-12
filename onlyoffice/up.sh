#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .vault.json ]; then
  echo "Error: .vault.json not found. Copy .vault.json.example and fill in your values." >&2
  exit 1
fi

VAULT_ADDR=$(jq -r '.addr // empty' .vault.json)

if [ -z "$VAULT_ADDR" ]; then
  echo '[up.sh] Vault address is required. Set "addr" in .vault.json.' >&2
  exit 1
fi

# ── auth method ──────────────────────────────────────────────────────────────

if [ -n "${VAULT_TOKEN:-}" ]; then
  echo "✔ Using VAULT_TOKEN from environment"
else
  echo ""
  echo "? Which login method?"
  PS3="> "
  select METHOD in "Token" "Userpass" "LDAP"; do
    [ -n "$METHOD" ] && break
  done

  case $METHOD in
    Token)
      read -rsp "? Vault token: " VAULT_TOKEN; echo
      ;;
    Userpass)
      read -rp  "? Username: "   USERNAME
      read -rsp "? Password: "   PASSWORD; echo
      VAULT_TOKEN=$(curl -sf "${VAULT_ADDR}/v1/auth/userpass/login/${USERNAME}" \
        -d "{\"password\":\"${PASSWORD}\"}" | jq -r '.auth.client_token')
      ;;
    LDAP)
      read -rp  "? LDAP username: " USERNAME
      read -rsp "? LDAP password: " PASSWORD; echo
      VAULT_TOKEN=$(curl -sf "${VAULT_ADDR}/v1/auth/ldap/login/${USERNAME}" \
        -d "{\"password\":\"${PASSWORD}\"}" | jq -r '.auth.client_token')
      ;;
  esac
fi

# ── write .env ────────────────────────────────────────────────────────────────

rm -f .env
{
  printf "VAULT_ADDR=%s\n"  "$VAULT_ADDR"
  printf "VAULT_TOKEN=%s\n" "$VAULT_TOKEN"
} > .env
echo "✔ .env written"

# ── deploy (secrets fetched by vault-init.sh inside container) ───────────────

export VAULT_ADDR VAULT_TOKEN

docker compose pull
docker compose up -d
