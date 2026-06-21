#!/bin/bash
# Chạy MỘT LẦN DUY NHẤT sau khi start Vault lần đầu.
# Lưu unseal key và root token vào file — backup 2 file này ra nơi an toàn.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INIT_FILE="$SCRIPT_DIR/.vault-init.json"

if [ -f "$SCRIPT_DIR/.vault-unseal-key" ]; then
    echo "Vault đã được init rồi (tìm thấy .vault-unseal-key). Bỏ qua."
    exit 0
fi

echo "Đang init Vault..."
INIT_OUTPUT=$(docker exec vault vault operator init -key-shares=1 -key-threshold=1 -format=json)
echo "$INIT_OUTPUT" > "$INIT_FILE"

# Parse JSON — dùng python3 nếu không có jq
if command -v jq &>/dev/null; then
    UNSEAL_KEY=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')
    ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
else
    UNSEAL_KEY=$(echo "$INIT_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['unseal_keys_b64'][0])")
    ROOT_TOKEN=$(echo "$INIT_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['root_token'])")
fi

echo "$UNSEAL_KEY" > "$SCRIPT_DIR/.vault-unseal-key"
echo "$ROOT_TOKEN"  > "$SCRIPT_DIR/.vault-root-token"
chmod 600 "$SCRIPT_DIR/.vault-unseal-key" "$SCRIPT_DIR/.vault-root-token" "$INIT_FILE"

echo "Đang unseal Vault lần đầu..."
docker exec vault vault operator unseal "$UNSEAL_KEY"

echo ""
echo "=== Vault sẵn sàng ==="
echo "Root Token : $ROOT_TOKEN"
echo "Vault UI   : http://localhost:8200"
echo ""
echo "Bật KV secrets engine:"
echo "  docker exec -e VAULT_TOKEN=$ROOT_TOKEN vault vault secrets enable -path=secret kv-v2"
echo ""
echo "QUAN TRỌNG: backup .vault-init.json, .vault-unseal-key, .vault-root-token ra nơi an toàn!"
