# RabbitMQ

Message broker, chạy trên hai cổng (chỉ bind `127.0.0.1`):

| Cổng    | Mục đích                                 |
| ------- | ---------------------------------------- |
| `5672`  | AMQP — ứng dụng kết nối                  |
| `15672` | Management UI — `http://127.0.0.1:15672` |

Dữ liệu được persist vào Docker volume `rabbitmq_data`.

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
    "production": "secret/rabbitmq"
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

| Biến                     | Mô tả                                     |
| ------------------------ | ----------------------------------------- |
| `RABBITMQ_DEFAULT_USER`  | Username đăng nhập (AMQP + Management UI) |
| `RABBITMQ_DEFAULT_PASS`  | Password                                  |
| `RABBITMQ_DEFAULT_VHOST` | Virtual host, thường để `/`               |

## Kết nối từ backend

```
amqp://<user>:<pass>@zhizhu-rabbitmq:5672/
```

Dùng tên container `zhizhu-rabbitmq` — cả backend và rabbitmq đều ở `zhizhu_net`.

## Logs

```bash
docker logs zhizhu-rabbitmq -f
docker logs zhizhu-rabbitmq -n 100
```
