# Flowable

BPMN engine (Flowable REST), chạy trên cổng `8082` (chỉ bind `127.0.0.1` — `8080` đã dùng bởi `zhizhu-web`, `8081` đã dùng bởi Portainer), expose ra Internet qua Cloudflare Tunnel tại `flowable.zhizhu.online`.

Image được build & push lên GHCR từ repo `flowable` riêng (không phải repo này) — compose ở đây chỉ pull & chạy.

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
    "production": "secret/flowable"
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
3. Pull image mới từ GHCR
4. Recreate container với image và env mới

## Biến môi trường (secret trong Vault, xem `.env.example`)

| Biến | Mô tả |
| ---- | ----- |
| `APP_IMAGE` | Image GHCR — mặc định `:latest`, override để pin bản `sha-<commit>` |
| `FLOWABLE_PORT` | Port host bind (mặc định `8082` — `8080` đã dùng bởi `zhizhu-web`, `8081` đã dùng bởi Portainer) |
| `SUPABASE_DB_HOST` / `SUPABASE_DB_PORT` / `SUPABASE_DB_NAME` / `SUPABASE_DB_USER` / `SUPABASE_DB_PASSWORD` | Kết nối Supabase PostgreSQL (docker-compose tự ghép thành JDBC URL). Nên dùng **direct connection** (`db.[PROJECT_REF].supabase.co:5432`, user `postgres`); nếu qua pooler thì dùng port `5432` (Session mode), không dùng `6543` (Transaction mode) — xem ghi chú trong `.env.example` |
| `FLOWABLE_DB_SCHEMA` | Schema chứa bảng `ACT_*` bên trong `SUPABASE_DB_NAME`. Dùng chung DB với service khác → đặt tên schema riêng (mặc định `flowable`, phải `CREATE SCHEMA` trước). Tách hẳn 1 database riêng cho Flowable → đặt `public` |
| `FLOWABLE_ADMIN_USER` / `FLOWABLE_ADMIN_PASSWORD` / `FLOWABLE_ADMIN_EMAIL` | Admin dùng để gọi Flowable REST API |
| `INTERNAL_SERVICE_TOKEN` | Shared secret giữa Flowable và NestJS (header `X-Internal-Auth`) |
| `NESTJS_INTERNAL_BASE_URL` | **Placeholder** — chưa có service NestJS (approval-app) trong `zhizhu-server-deploy`. Điền URL thật khi service đó được deploy (container name nếu cùng join `zhizhu_net`, hoặc URL external) |

## Cloudflare Tunnel

Thêm route vào `cloudflared/config.example.yml` (đã có sẵn ở repo này):

```text
flowable.zhizhu.online -> http://127.0.0.1:8082
```

## Kiểm tra

```bash
curl -u admin:your-password http://127.0.0.1:8082/flowable-rest/service/repository/deployments
```

Kết quả mong đợi:

```json
{ "data": [], "total": 0, "start": 0, "size": 0 }
```

Container có healthcheck tự động gọi endpoint trên mỗi 30 giây (timeout 10s, tối đa 5 lần retry, chờ 90s khởi động).

## Logs

```bash
docker logs zhizhu-flowable -f
docker logs zhizhu-flowable -n 100
```
