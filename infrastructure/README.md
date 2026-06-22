# Infrastructure — HashiCorp Vault

Quản lý secrets (env vars) cho toàn bộ hệ thống. Data lưu trên Docker volume `vault_data`, không mất sau khi restart.

## Lần đầu tiên

```bash
docker compose up -d
bash init-vault.sh
```

`init-vault.sh` sẽ:
- Khởi tạo Vault với 1 unseal key
- Tự động unseal lần đầu
- Lưu key và root token vào `.vault-unseal-key` và `.vault-root-token`
- In ra lệnh bật KV secrets engine

Sau khi init xong, bật KV engine (chạy lệnh in ra từ script):

```bash
docker exec -e VAULT_TOKEN=$(cat .vault-root-token) vault \
  vault secrets enable -path=secret kv-v2
```

## Lưu và đọc secrets

```bash
# Lưu env cho một service
docker exec -e VAULT_TOKEN=$(cat .vault-root-token) vault \
  vault kv put secret/backend \
    DATABASE_URL="postgresql://user:pass@host:5432/db" \
    REDIS_PASSWORD="your_password" \
    NODE_ENV="production"

# Đọc lại
docker exec -e VAULT_TOKEN=$(cat .vault-root-token) vault \
  vault kv get secret/backend
```

## Sau mỗi lần restart server

Vault tự động sealed khi khởi động lại — chạy script để unseal:

```bash
bash unseal.sh
```

Hoặc thêm vào crontab để tự động (`crontab -e`):

```
@reboot /opt/zhizhu/Infrastructure/unseal.sh
```

## Vault UI

Truy cập tại `http://localhost:8200` (hoặc qua tunnel nếu cần).  
Đăng nhập bằng root token trong file `.vault-root-token`.

## Lưu ý

- Backup 3 file `.vault-init.json`, `.vault-unseal-key`, `.vault-root-token` ra nơi an toàn ngoài server. Nếu mất unseal key, dữ liệu trong Vault sẽ không thể truy cập.
- 3 file trên đã được `.gitignore` — không bao giờ commit lên git.
