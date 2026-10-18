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
├── flowable
│   ├── docker-compose.yml
│   └── .env.example
├── ado
│   ├── docker-compose.yml
│   └── .env.example
├── video-tool
│   ├── docker-compose.yml
│   └── .env.example
├── sp-nextjs
│   └── docker-compose.yml
├── file-converter
│   ├── docker-compose.yml
│   ├── up.sh
│   └── .env.example
├── e-signature
│   ├── docker-compose.yml
│   ├── up.sh
│   └── .env.example
└── cloudflared
    └── config.example.yml
```

## Bảng port đang dùng

Tra bảng này trước khi thêm service mới / đổi `*_PORT` trong `.env` để tránh xung đột port trên host (đã từng xảy ra: `flowable` chọn `8081` trùng với Portainer).

| Port | Bind | Service | Container | Thư mục |
| ---- | ---- | ------- | --------- | ------- |
| `25` | `0.0.0.0` | Mailu SMTP (direct, không qua tunnel) | `mailu` | `mailu/` |
| `80` | `127.0.0.1` | Mailu HTTP | `mailu` | `mailu/` |
| `443` | `127.0.0.1` | Mailu HTTPS | `mailu` | `mailu/` |
| `2000` | `127.0.0.1` | Backend — core | `zhizhu-be-core` | `backend/` |
| `2001` | `127.0.0.1` | Backend — app | `zhizhu-be-app` | `backend/` |
| `2002` | `127.0.0.1` | Backend — core-jobs | `zhizhu-be-core-jobs` | `backend/` |
| `2003` | `127.0.0.1` | Backend — app-jobs | `zhizhu-be-app-jobs` | `backend/` |
| `3001` | `127.0.0.1` | Grafana | `zhizhu-grafana` | `monitoring/` |
| `3333` | `0.0.0.0` ⚠️ | Frontend | `zhizhu-frontend` | `frontend/` |
| `5672` | `127.0.0.1` | RabbitMQ — AMQP | `zhizhu-rabbitmq` | `rabbitmq/` |
| `6379` | `127.0.0.1` | Redis | `zhizhu-redis` | `redis/` |
| `8080` | `127.0.0.1` | Web | `zhizhu-web` | `web/` |
| `8081` | `0.0.0.0` ⚠️ | Portainer (qua nginx) | `docker-ui-nginx` | `docker/` |
| `8082` | `127.0.0.1` | Flowable (BPMN engine) | `zhizhu-flowable` | `flowable/` |
| `8090` | `127.0.0.1` | OnlyOffice | `zhizhu-onlyoffice` | `onlyoffice/` |
| `8091` | `127.0.0.1` | ADO Dashboard | `zhizhu-ado` | `ado/` |
| `8092` | `127.0.0.1` | SharePoint Downloader | `zhizhu-sp-nextjs` | `sp-nextjs/` |
| `8093` | `127.0.0.1` | File Converter (Word/Excel → PDF, chỉ nội bộ) | `zhizhu-file-converter` | `file-converter/` |
| `8094` | `127.0.0.1` | E-signature (ký số nội bộ, chỉ nội bộ) | `zhizhu-e-signature` | `e-signature/` |
| `8200` | `127.0.0.1` | Vault | `vault` | `infrastructure/` |
| `8501` | `127.0.0.1` | Video Tool (Streamlit) | `zhizhu-video-tool` | `video-tool/` |
| `9090` | `127.0.0.1` | Prometheus | `zhizhu-prometheus` | `monitoring/` |
| `9093` | `127.0.0.1` | Alertmanager | `zhizhu-alertmanager` | `monitoring/` |
| `15672` | `127.0.0.1` | RabbitMQ — Management UI | `zhizhu-rabbitmq` | `rabbitmq/` |

⚠️ = bind `0.0.0.0` (không giới hạn `127.0.0.1` như convention chung — xem [Key conventions](CLAUDE.md) — cân nhắc siết lại nếu không cần truy cập trực tiếp ngoài tunnel.

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

## 6. Chạy Flowable

Flowable lấy secrets từ HashiCorp Vault thay vì chỉnh `.env` tay (image build từ repo `flowable` riêng):

```bash
cd /opt/zhizhu/flowable
cp .vault.json.example .vault.json
nano .vault.json   # điền đúng addr và đường dẫn secret

bash up.sh
```

> **Lưu ý:** Vault phải đang chạy và đã được unseal trước bước này. Xem [infrastructure/README.md](infrastructure/README.md).

## 7. Chạy ADO Dashboard

```bash
cd /opt/zhizhu/ado
cp .env.example .env
nano .env

docker compose up -d
```

## 8. Chạy SharePoint Downloader

Không cần `.env` (xem [sp-nextjs/README.md](sp-nextjs/README.md)):

```bash
cd /opt/zhizhu/sp-nextjs
docker compose up -d
```

CI của repo `sp-nextjs` tự `pull` + `up -d` mỗi lần push lên `main`.

## 8a. Chạy File Converter

Secret (`SYNCFUSION_LICENSE_KEY`) lấy từ Vault (xem [file-converter/README.md](file-converter/README.md)):

```bash
cd /opt/zhizhu/file-converter
cp .vault.json.example .vault.json
bash up.sh
```

Chỉ dùng nội bộ (không route Cloudflare Tunnel): backend gọi `http://zhizhu-file-converter:8080`.
CI của repo `netcore` tự chạy `up.sh` mỗi lần push lên `main`.

## 8b. Chạy E-signature

Secret (`Signing__MasterKey`, `Signing__ServiceToken`, `Signing__KeyStore__*`) lấy từ Vault (xem [e-signature/README.md](e-signature/README.md)):

```bash
cd /opt/zhizhu/e-signature
cp .vault.json.example .vault.json
bash up.sh
curl -X POST -H "X-Service-Token: <Signing__ServiceToken>" http://127.0.0.1:8094/ca/init   # tạo CA, chỉ một lần
```

Chỉ dùng nội bộ (không route Cloudflare Tunnel): backend gọi `http://zhizhu-e-signature:8080`.
CI của repo `e-signature` tự chạy `up.sh` mỗi lần push lên `main`.

## 9. Kiểm tra

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

Logs flowable:

```bash
docker logs zhizhu-flowable -n 100
```

Logs ado:

```bash
docker logs zhizhu-ado -n 100
```

Logs sp-nextjs:

```bash
docker logs zhizhu-sp-nextjs -n 100
```

Logs file-converter:

```bash
docker logs zhizhu-file-converter -n 100
```

Logs e-signature:

```bash
docker logs zhizhu-e-signature -n 100
```

## 10. Cloudflared

Ví dụ route:

```text
api.zhizhu.online -> http://127.0.0.1:3000
app.zhizhu.online -> http://127.0.0.1:8080
flowable.zhizhu.online -> http://127.0.0.1:8082
ado.zhizhu.online -> http://127.0.0.1:8091
sp.zhizhu.online -> http://127.0.0.1:8092
```

Tham khảo file:

```text
cloudflared/config.example.yml
```
