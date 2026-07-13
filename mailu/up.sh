#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ ! -f mailu.env ]; then
  echo -e "${RED}✗ mailu.env không tồn tại. Copy mailu.env.example và điền giá trị.${NC}" >&2
  exit 1
fi

echo -e "${GREEN}→ Pull images mới nhất...${NC}"
docker compose pull

echo -e "${GREEN}→ Khởi động Mailu...${NC}"
docker compose up -d --force-recreate

echo ""
echo -e "${GREEN}✔ Mailu đang chạy.${NC}"
echo ""
echo "  Web UI:   http://127.0.0.1/admin  (qua Cloudflare Tunnel → mail.zhizhu.online/admin)"
echo "  Webmail:  http://127.0.0.1/webmail"
echo ""
echo "  Logs:     docker compose logs -f"
echo "  Status:   docker compose ps"
