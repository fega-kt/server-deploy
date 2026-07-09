# Docker UI

Portainer CE với nginx làm reverse proxy. Cloudflare Tunnel trỏ vào `127.0.0.1:8081`.

## Cấu trúc

```
docker/
├── docker-compose.yml   # Portainer + nginx
├── nginx.conf           # Reverse proxy config
└── README.md
```

## Lần đầu triển khai

```bash
cd /opt/zhizhu/docker
docker compose up -d
```

Truy cập Portainer lần đầu qua tunnel hoặc tạm thời qua `http://<server-ip>:8081` để tạo tài khoản admin (phải làm trong vòng vài phút sau khi khởi động).

## Cập nhật

```bash
cd /opt/zhizhu/docker
docker compose up -d --pull always
```

Flag `--pull always` kéo image mới nhất rồi restart container nếu có thay đổi.

## Logs & kiểm tra

```bash
docker logs portainer      -n 100
docker logs docker-ui-nginx -n 100
```

## Dừng / xóa

```bash
# Dừng (giữ data)
docker compose down

# Dừng + xóa volume (mất toàn bộ data Portainer)
docker compose down -v
```

## Cloudflare Tunnel

Thêm public hostname trong Cloudflare Tunnel dashboard:

| Hostname | Service |
|---|---|
| `portainer.zhizhu.online` | `http://127.0.0.1:8081` |
