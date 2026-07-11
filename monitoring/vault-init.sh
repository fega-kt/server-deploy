#!/bin/bash
set -e

[ -z "${VAULT_TOKEN:-}" ]       && { echo "[vault-init] VAULT_TOKEN required" >&2; exit 1; }
[ -z "${VAULT_ADDR:-}" ]        && { echo "[vault-init] VAULT_ADDR required" >&2; exit 1; }
[ -z "${VAULT_SECRET_PATH:-}" ] && { echo "[vault-init] VAULT_SECRET_PATH required" >&2; exit 1; }

MOUNT="${VAULT_SECRET_PATH%%/*}"
REST="${VAULT_SECRET_PATH#*/}"
API_PATH="${MOUNT}/data/${REST}"

RESPONSE=$(curl -sf "${VAULT_ADDR}/v1/${API_PATH}" \
  -H "X-Vault-Token: ${VAULT_TOKEN}") || {
  echo "[vault-init] Failed to reach Vault at ${VAULT_ADDR}/v1/${API_PATH}" >&2
  exit 1
}

while IFS= read -r line; do
  [ -z "$line" ] && continue
  key="${line%%=*}"
  value="${line#*=}"
  export "$key=$value"
done < <(python3 -c "
import sys, json
r = json.loads(sys.stdin.read())
for k, v in r['data']['data'].items():
    print(f'{k}={str(v).lower() if isinstance(v, bool) else v}')
" <<< "$RESPONSE") || { echo "[vault-init] Failed to parse Vault response" >&2; exit 1; }

echo "[vault-init] Secrets loaded from Vault"
echo "[vault-init] GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER:-not set}"

exec "$@"
