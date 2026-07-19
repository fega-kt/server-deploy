# Redis

Cache / session store, chạy trên cổng `6379` (chỉ bind `127.0.0.1`).  
Dữ liệu được persist qua AOF vào Docker volume `redis_data`.

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
    "production": "secret/redis"
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

| Biến             | Mô tả                                                    |
| ---------------- | --------------------------------------------------------- |
| `REDIS_PASSWORD` | Password — **bắt buộc**, container sẽ báo lỗi và không start nếu thiếu |
| `REDIS_PORT`     | Port host bind (mặc định `6379`)                          |
| `REDIS_USER`     | Tùy chọn — xem mục [User / ACL](#user--acl)               |

> Đặt `REDIS_PASSWORD` giống nhau ở đây và trong secret Vault của `backend`.

## User / ACL

Container tự chọn chế độ auth dựa vào `REDIS_USER` khi start:

- **Không set `REDIS_USER`** (mặc định) — dùng `default` user kiểu cũ, `--requirepass <password>`. Backend hiện tại (chỉ gửi password, không username) hoạt động bình thường, không cần sửa gì.
- **Có set `REDIS_USER`** — user `default` bị **tắt hoàn toàn**, chỉ user tên `$REDIS_USER` được bật, full quyền (`~* &* +@all`). Lúc này **phải** cập nhật backend để gửi kèm username khi connect (`AUTH <user> <password>`), nếu không backend sẽ mất kết nối redis.
- **Thiếu `REDIS_PASSWORD`** — container in lỗi `[redis] ERROR: REDIS_PASSWORD is required` ra log rồi thoát, không start.

## Kiểm tra kết nối

```bash
# Không set REDIS_USER (default user)
docker exec zhizhu-redis redis-cli -a $(grep REDIS_PASSWORD .env | cut -d= -f2) ping

# Có set REDIS_USER
docker exec zhizhu-redis redis-cli --user $(grep REDIS_USER .env | cut -d= -f2) -a $(grep REDIS_PASSWORD .env | cut -d= -f2) ping

# Kết quả: PONG
```

## Logs

```bash
docker logs zhizhu-redis -f
docker logs zhizhu-redis -n 100
```
