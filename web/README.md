# Web

Frontend, chạy trên cổng `8080` (chỉ bind `127.0.0.1`).

## Chạy

```bash
cp .env.example .env
nano .env          # điền đúng giá trị
docker compose up -d
```

## Biến môi trường (`.env`)

| Biến | Mô tả |
|------|-------|
| `WEB_IMAGE` | Docker image của frontend, ví dụ `ghcr.io/owner/web:1.2.3` |
| `WEB_PORT` | Cổng expose ra host (mặc định `8080`) |

## Cập nhật image mới

```bash
docker compose pull
docker compose up -d
```

## Logs

```bash
docker logs zhizhu-web -f
docker logs zhizhu-web -n 100
```
