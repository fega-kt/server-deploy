# Backend

API server, chạy trên cổng `3000` (chỉ bind `127.0.0.1`).

## Chạy

```bash
cp .env.example .env
nano .env          # điền đúng giá trị
docker compose up -d
```

## Biến môi trường (`.env`)

| Biến | Mô tả |
|------|-------|
| `APP_IMAGE` | Docker image của backend, ví dụ `ghcr.io/owner/repo:1.2.3` |
| `NODE_ENV` | `production` |
| `APP_PORT` | Cổng expose ra host (mặc định `3000`) |
| `REDIS_HOST` | Giữ nguyên `zhizhu-redis` — tên container trong Docker network |
| `REDIS_PORT` | `6379` |
| `REDIS_PASSWORD` | Phải khớp với `REDIS_PASSWORD` trong `redis/.env` |
| `DATABASE_URL` | Connection string tới PostgreSQL |

## Cập nhật image mới

```bash
docker compose pull
docker compose up -d
```

## Logs

```bash
docker logs zhizhu-backend -f
docker logs zhizhu-backend -n 100
```
