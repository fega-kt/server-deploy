#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .vault.json ]; then
  echo "Error: .vault.json not found. Copy .vault.json.example and fill in your values." >&2
  exit 1
fi

VAULT_ADDR=$(jq -r '.addr // empty' .vault.json)
VAULT_SECRET_PATH=$(jq -r '.path // empty' .vault.json)

if [ -z "$VAULT_ADDR" ]; then
  echo '[up.sh] Vault address is required. Set "addr" in .vault.json.' >&2
  exit 1
fi

if [ -z "$VAULT_SECRET_PATH" ]; then
  echo '[up.sh] Vault secret path is required. Set "path" in .vault.json.' >&2
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

# ── fetch all config from Vault and export to shell ──────────────────────────

MOUNT="${VAULT_SECRET_PATH%%/*}"
REST="${VAULT_SECRET_PATH#*/}"
API_PATH="${MOUNT}/data/${REST}"

RESPONSE=$(curl -sf "${VAULT_ADDR}/v1/${API_PATH}" \
  -H "X-Vault-Token: ${VAULT_TOKEN}") || {
  echo "[up.sh] Failed to reach Vault at ${VAULT_ADDR}/v1/${API_PATH}" >&2
  exit 1
}

while IFS= read -r line; do
  [ -z "$line" ] && continue
  key="${line%%=*}"
  value="${line#*=}"
  export "$key=$value"
done < <(echo "$RESPONSE" | jq -r '.data.data | to_entries[] | "\(.key)=\(.value)"') || {
  echo "[up.sh] Failed to parse Vault response" >&2
  exit 1
}

echo "[up.sh] Config loaded from Vault"

# ── write .env ────────────────────────────────────────────────────────────────

rm -f .env
{
  echo "$RESPONSE" | jq -r '.data.data | to_entries[] | "\(.key)=\(.value)"'
  printf "VAULT_ADDR=%s\n"        "$VAULT_ADDR"
  printf "VAULT_TOKEN=%s\n"       "$VAULT_TOKEN"
  printf "VAULT_SECRET_PATH=%s\n" "$VAULT_SECRET_PATH"
} > .env
echo "✔ .env written — subsequent 'docker compose up -d' will work without re-authenticating"

# ── deploy ───────────────────────────────────────────────────────────────────

export VAULT_ADDR VAULT_TOKEN VAULT_SECRET_PATH

docker compose pull
docker compose up -d
