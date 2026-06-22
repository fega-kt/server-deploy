#!/bin/bash
# Chạy sau mỗi lần restart server để unseal Vault.
# Thêm vào crontab để tự động: @reboot /opt/zhizhu/Infrastructure/unseal.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEY_FILE="$SCRIPT_DIR/.vault-unseal-key"

if [ ! -f "$KEY_FILE" ]; then
    echo "Không tìm thấy $KEY_FILE — chạy init-vault.sh trước."
    exit 1
fi

# Chờ container sẵn sàng (tối đa 30s)
for i in $(seq 1 15); do
    if docker exec vault vault status -format=json 2>/dev/null | grep -q '"initialized"'; then
        break
    fi
    echo "Chờ Vault container... ($i/15)"
    sleep 2
done

STATUS=$(docker exec vault vault status -format=json 2>/dev/null || echo '{}')
SEALED=$(echo "$STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sealed', True))" 2>/dev/null || echo "true")

if [ "$SEALED" = "False" ] || [ "$SEALED" = "false" ]; then
    echo "Vault đã được unseal rồi."
    exit 0
fi

echo "Đang unseal Vault..."
docker exec vault vault operator unseal "$(cat "$KEY_FILE")"
echo "Vault đã unseal thành công."
