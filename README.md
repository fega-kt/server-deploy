# Zhizhu Server Deploy

Cấu trúc này tách riêng từng service để dễ quản lý:

```text
/opt/zhizhu
├── backend
│   ├── docker-compose.yml
│   └── .env.example
├── redis
│   ├── docker-compose.yml
│   └── .env.example
├── web
│   ├── docker-compose.yml
│   └── .env.example
└── cloudflared
    └── config.example.yml
```

## 1. Copy lên server

```bash
sudo mkdir -p /opt/zhizhu
sudo chown -R $USER:$USER /opt/zhizhu
```

Copy các thư mục trong project này vào `/opt/zhizhu`.

## 2. Tạo Docker network dùng chung

Chạy 1 lần duy nhất:

```bash
docker network create zhizhu_net
```

## 3. Chạy Redis

Redis lấy secrets từ HashiCorp Vault thay vì chỉnh `.env` tay:

```bash
cd /opt/zhizhu/redis
cp .vault.json.example .vault.json
nano .vault.json   # điền đúng addr và đường dẫn secret

bash up.sh
```

> **Lưu ý:** Vault phải đang chạy và đã được unseal trước bước này. Xem [infrastructure/README.md](infrastructure/README.md).

## 4. Chạy Backend

Backend lấy secrets từ HashiCorp Vault thay vì chỉnh `.env` tay:

```bash
cd /opt/zhizhu/backend
cp .vault.json.example .vault.json
nano .vault.json   # điền đúng addr và đường dẫn secret

bash up.sh
```

Script sẽ hỏi auth method (Token / Userpass / LDAP), xác thực với Vault, ghi secrets vào `.env` rồi `docker compose up -d` tự động.

> **Lưu ý:** Vault phải đang chạy và đã được unseal trước bước này. Xem [infrastructure/README.md](infrastructure/README.md).

## 5. Chạy Web

```bash
cd /opt/zhizhu/web
cp .env.example .env
nano .env

docker compose up -d
```

## 6. Kiểm tra

```bash
docker ps
```

Logs backend:

```bash
docker logs zhizhu-backend -n 100
```

Logs redis:

```bash
docker logs zhizhu-redis -n 100
```

Logs web:

```bash
docker logs zhizhu-web -n 100
```

## 7. Cloudflared

Ví dụ route:

```text
api.zhizhu.online -> http://127.0.0.1:3000
app.zhizhu.online -> http://127.0.0.1:8080
```

Tham khảo file:

```text
cloudflared/config.example.yml
```
