# Monitoring — Grafana + Prometheus + Node Exporter + cAdvisor

## Tổng quan

```text
Cloudflare Tunnel (monitor.zhizhu.online)
        │
        ▼
  Grafana :3001          ← dashboard, alert
        │
        ▼
  Prometheus :9090       ← thu thập & lưu metrics
    ├── Node Exporter    ← CPU, RAM, disk, network của host
    ├── cAdvisor         ← CPU, RAM, network từng Docker container
    └── zhizhu-backend   ← app metrics (nếu backend expose /metrics)
```

Tất cả services giao tiếp qua network `monitoring_internal` (nội bộ). Chỉ Grafana join thêm `zhizhu_net` để có thể scrape backend nếu cần.

## Yêu cầu

- Docker + Docker Compose, `jq`, `curl` trên host
- Vault đang chạy và có secret tại `secret/monitoring`

## Secrets trong Vault

Toàn bộ config đọc từ Vault. Tạo secret trước khi deploy:

```bash
vault kv put secret/monitoring \
  GF_SECURITY_ADMIN_USER=admin \
  GF_SECURITY_ADMIN_PASSWORD=$(openssl rand -hex 16) \
  GRAFANA_PORT=3001 \
  GRAFANA_ROOT_URL=https://monitor.zhizhu.online \
  PROMETHEUS_PORT=9090 \
  PROMETHEUS_RETENTION=15d
```

| Key | Mô tả |
| --- | --- |
| `GF_SECURITY_ADMIN_USER` | Tên đăng nhập admin Grafana |
| `GF_SECURITY_ADMIN_PASSWORD` | Mật khẩu admin Grafana |
| `GRAFANA_PORT` | Port Grafana bind trên host |
| `GRAFANA_ROOT_URL` | Public URL của Grafana |
| `PROMETHEUS_PORT` | Port Prometheus bind trên host |
| `PROMETHEUS_RETENTION` | Thời gian lưu metrics (VD: `15d`) |

## Cách hoạt động

```text
up.sh
  ├── đọc addr + path từ .vault.json
  ├── lấy VAULT_TOKEN (env hoặc nhập tay)
  ├── fetch toàn bộ secret/monitoring → export vào shell env
  │     (GRAFANA_PORT, PROMETHEUS_PORT... dùng cho docker compose substitution)
  └── docker compose up
            │
            └── Grafana container (vault-init.sh)
                  ├── fetch lại secret/monitoring từ Vault
                  │     (GF_SECURITY_ADMIN_USER, GF_SECURITY_ADMIN_PASSWORD)
                  └── exec /run.sh
```

Secrets không bao giờ ghi ra disk.

## Deploy lần đầu

```bash
cd /opt/zhizhu/monitoring
cp .vault.json.example .vault.json   # kiểm tra "addr" trỏ đúng Vault
bash up.sh
# → chọn login method (Token / Userpass / LDAP)
# → nhập credentials
# → docker compose pull && docker compose up -d
```

## Restart / sau server reboot

```bash
docker compose up -d
```

Không cần chạy `up.sh` lại — `VAULT_TOKEN` đã được bake vào Docker container config từ lần deploy đầu. Grafana tự fetch lại secrets từ Vault mỗi lần khởi động. Port binding dùng defaults trong `docker-compose.yml`.

## Redeploy / cập nhật config

```bash
bash up.sh
```

## Kiểm tra

```bash
docker logs zhizhu-grafana       -n 50
docker logs zhizhu-prometheus    -n 50
docker logs zhizhu-node-exporter -n 50
docker logs zhizhu-cadvisor      -n 50

# Prometheus targets (tất cả phải UP)
curl http://localhost:9090/targets
```

## Grafana

Truy cập `http://localhost:3001` (hoặc `https://monitor.zhizhu.online` nếu đã cấu hình tunnel).

Datasource Prometheus và 2 dashboard được provisioning tự động:

| Dashboard | Nội dung |
| --- | --- |
| Node Exporter — Host Metrics | CPU, RAM, disk, network của host |
| Docker Containers | CPU, RAM, network từng container (via cAdvisor) |

## Cloudflare Tunnel

Thêm route vào tunnel config:

```yaml
- hostname: monitor.zhizhu.online
  service: http://localhost:3001
```

## Ghi chú bảo mật

- Mọi config đều lấy từ Vault, không có file `.env` trên disk.
- `VAULT_TOKEN` lưu trong Docker container config — nếu bị lộ, revoke trong Vault là vô hiệu hóa ngay.
- Prometheus và Grafana chỉ bind `127.0.0.1` — không expose trực tiếp ra internet.
