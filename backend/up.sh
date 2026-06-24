#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .vault.json ]; then
  echo "Error: .vault.json not found. Copy .vault.json.example and fill in your values." >&2
  exit 1
fi

npx --yes @zhizhu_dev/vault-start production --write-env

docker compose pull
docker compose up -d
