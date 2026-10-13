#!/bin/bash
set -e

[ -z "${VAULT_TOKEN:-}" ]      && { echo "[vault-init] VAULT_TOKEN required" >&2; exit 1; }
[ -z "${VAULT_ADDR:-}" ]       && { echo "[vault-init] VAULT_ADDR required" >&2; exit 1; }
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
echo "[vault-init] JWT_ENABLED=${JWT_ENABLED:-not set}"
echo "[vault-init] EXAMPLE_ENABLED=${EXAMPLE_ENABLED:-not set}"

# Nới thời gian tải file nguồn của converter (mặc định 2m) sau khi run-document-server.sh đã sinh local.json
if [ -n "${DOWNLOAD_TIMEOUT_WHOLE_CYCLE:-}" ]; then
  (until supervisorctl status ds:docservice 2>/dev/null | grep -q RUNNING; do sleep 5; done
   python3 -c "
import json, os
path = '/etc/onlyoffice/documentserver/local.json'
with open(path) as f:
    cfg = json.load(f)
timeout = cfg.setdefault('FileConverter', {}).setdefault('converter', {}).setdefault('downloadTimeout', {})
timeout['wholeCycle'] = os.environ['DOWNLOAD_TIMEOUT_WHOLE_CYCLE']
with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)
"
   echo "[vault-init] Patched converter downloadTimeout.wholeCycle=${DOWNLOAD_TIMEOUT_WHOLE_CYCLE}"
   supervisorctl restart ds:converter
   echo "[vault-init] ds:converter restarted") &
fi

# Start ds:example after docservice is ready (only if EXAMPLE_ENABLED=true)
if [ "${EXAMPLE_ENABLED:-false}" = "true" ]; then
  echo "[vault-init] EXAMPLE_ENABLED=true, waiting for ds:docservice..."
  (until supervisorctl status ds:docservice 2>/dev/null | grep -q RUNNING; do sleep 5; done
   python3 -c "
import json, os
path = '/etc/onlyoffice/documentserver-example/local.json'
with open(path) as f:
    cfg = json.load(f)
cfg.setdefault('server', {})
cfg['server']['token'] = {'enable': os.environ.get('JWT_ENABLED', 'false') == 'true', 'secret': os.environ['JWT_SECRET'], 'authorizationHeader': os.environ.get('JWT_HEADER', 'Authorization')}
with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)
"
   echo "[vault-init] Patched example config (JWT + siteUrl)"
   supervisorctl restart ds:example
   echo "[vault-init] ds:example started") &
else
  echo "[vault-init] EXAMPLE_ENABLED=false, stopping ds:example..."
  (until supervisorctl status ds:docservice 2>/dev/null | grep -q RUNNING; do sleep 5; done
   supervisorctl stop ds:example 2>/dev/null || true
   echo "[vault-init] ds:example stopped") &
fi

exec "$@"
