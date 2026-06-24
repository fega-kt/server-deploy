# Backend

API server, chạy trên cổng `3000` (chỉ bind `127.0.0.1`).

Secrets được lấy từ HashiCorp Vault thay vì chỉnh `.env` tay.

## Lần đầu cài đặt

```bash
cp .vault.json.example .vault.json
nano .vault.json   # điền addr Vault và đường dẫn secret
```

Cấu trúc `.vault.json`:

```json
{
  "addr": "http://127.0.0.1:8200",
  "kv": 2,
  "envs": {
    "production": "secret/zhizhu/backend"
  }
}
```

## Chạy / cập nhật

```bash
bash up.sh
```

Script sẽ:

1. Hỏi auth method: **Token**, **Userpass**, hoặc **LDAP**
2. Xác thực với Vault và fetch secrets mới nhất → ghi vào `.env`
3. Pull image mới từ registry
4. Recreate container với image và env mới

## Biến môi trường (`.env`)

| Biến             | Mô tả                                                          |
| ---------------- | -------------------------------------------------------------- |
| `APP_IMAGE`      | Docker image của backend, ví dụ `ghcr.io/owner/repo:1.2.3`     |
| `NODE_ENV`       | `production`                                                   |
| `APP_PORT`       | Cổng expose ra host (mặc định `3000`)                          |
| `REDIS_HOST`     | Giữ nguyên `zhizhu-redis` — tên container trong Docker network |
| `REDIS_PORT`     | `6379`                                                         |
| `REDIS_PASSWORD` | Phải khớp với `REDIS_PASSWORD` trong `redis/.env`              |
| `DATABASE_URL`   | Connection string tới PostgreSQL                               |

## Cập nhật image mới

```bash
docker compose pull   # tải image mới từ registry, container cũ vẫn chạy
docker compose up -d  # so sánh image hash — nếu thay đổi: dừng container cũ, tạo và start container mới
```

`docker compose up -d` **không** re-fetch secrets từ Vault. File `.env` hiện tại được tái sử dụng.

Nếu secrets trong Vault cũng thay đổi (ví dụ rotate password), chạy `bash up.sh` thay thế — nó fetch secrets mới rồi mới `up -d`.

## Logs

```bash
docker logs zhizhu-backend -f
docker logs zhizhu-backend -n 100
```
