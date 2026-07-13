# Mailu

Mail server (Postfix + Dovecot + Rspamd + Roundcube), 7 containers.

Web UI và webmail expose qua Cloudflare Tunnel. Mail ports tiếp nhận trực tiếp từ internet.
Secrets được lấy từ HashiCorp Vault thay vì chỉnh `.env` tay.

## Cổng

| Cổng | Giao thức  | Binding   | Expose qua        |
| ---- | ---------- | --------- | ----------------- |
| 80   | HTTP       | 127.0.0.1 | Cloudflare Tunnel |
| 443  | HTTPS      | 127.0.0.1 | Cloudflare Tunnel |
| 25   | SMTP       | 0.0.0.0   | Trực tiếp         |
| 465  | SMTPS      | 0.0.0.0   | Trực tiếp         |
| 587  | Submission | 0.0.0.0   | Trực tiếp         |
| 143  | IMAP       | 0.0.0.0   | Trực tiếp         |
| 993  | IMAPS      | 0.0.0.0   | Trực tiếp         |
| 110  | POP3       | 0.0.0.0   | Trực tiếp         |
| 995  | POP3S      | 0.0.0.0   | Trực tiếp         |

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
    "production": "secret/mailu"
  }
}
```

Lưu tất cả key trong `.env.example` vào Vault tại `secret/mailu`, sau đó:

```bash
bash up.sh
```

Script sẽ:

1. Hỏi auth method: **Token**, **Userpass**, hoặc **LDAP**
2. Xác thực với Vault và fetch secrets mới nhất → ghi vào `.env`
3. Pull image mới từ registry
4. Recreate container với image và env mới

## Biến môi trường (`.env`)

| Biến                  | Mô tả                                              |
| --------------------- | -------------------------------------------------- |
| `SECRET_KEY`          | Session encryption key — tạo bằng `openssl rand -hex 16` |
| `SUBNET`              | Subnet Docker nội bộ (`192.168.203.0/24`)          |
| `DOMAIN`              | Domain mail chính (`zhizhu.online`)                |
| `HOSTNAMES`           | FQDN mail server (`mail.zhizhu.online`)            |
| `POSTMASTER`          | Local part của postmaster (`admin`)                |
| `TLS_FLAVOR`          | Cách quản lý TLS — xem phần bên dưới              |
| `ADMIN`               | Bật admin UI (`true`)                              |
| `WEB_ADMIN`           | Path admin UI (`/admin`)                           |
| `WEB_WEBMAIL`         | Path webmail (`/webmail`)                          |
| `AUTH_RATELIMIT_IP`   | Giới hạn login theo IP (`60/hour`)                 |
| `AUTH_RATELIMIT_USER` | Giới hạn login theo user (`100/day`)               |
| `ANTIVIRUS`           | Backend antivirus (`none`)                         |
| `LOG_LEVEL`           | Log level (`WARNING`)                              |
| `DISABLE_STATISTICS`  | Tắt gửi stats về Mailu (`True`)                    |

## TLS

`TLS_FLAVOR=cert` — cung cấp cert thủ công qua acme.sh + Cloudflare DNS-01:

```bash
# Cài acme.sh (một lần)
curl https://get.acme.sh | sh

# Cấp cert qua DNS-01 (không cần mở port 80)
CF_Token="<cloudflare_api_token>" \
  acme.sh --issue -d mail.zhizhu.online --dns dns_cf

# Tìm mountpoint volume mailu_certs
CERT_MOUNT=$(docker volume inspect mailu_mailu_certs --format '{{.Mountpoint}}')

# Copy cert và thiết lập auto-renew
acme.sh --install-cert -d mail.zhizhu.online \
  --fullchain-file "$CERT_MOUNT/cert.pem" \
  --key-file       "$CERT_MOUNT/key.pem" \
  --reloadcmd      "docker compose -f /opt/zhizhu/mailu/docker-compose.yml restart front"
```

acme.sh tự renew mỗi 60 ngày và restart `front` để load cert mới.

## Cloudflare Tunnel

Thêm vào `cloudflared/config.yml`:

```yaml
ingress:
  # ... các route hiện có ...
  - hostname: mail.zhizhu.online
    service: http://127.0.0.1:80
```

Restart cloudflared sau khi sửa config.

## DNS records

Tất cả records bên dưới: **DNS only** (không proxy qua Cloudflare — orange cloud OFF).

```
; A record
mail.zhizhu.online.          A    <IP_server>
autoconfig.zhizhu.online.    A    <IP_server>
autodiscover.zhizhu.online.  A    <IP_server>

; MX
zhizhu.online.               MX   10   mail.zhizhu.online.

; SPF
zhizhu.online.               TXT  "v=spf1 mx ~all"

; DKIM — lấy sau khi Mailu chạy (xem phần Lấy DKIM key)
mailu._domainkey.zhizhu.online.  TXT  "v=DKIM1; k=rsa; p=..."

; DMARC
_dmarc.zhizhu.online.        TXT  "v=DMARC1; p=quarantine; rua=mailto:admin@zhizhu.online"

; PTR — cấu hình ở phía nhà cung cấp VPS
; <IP_server>  PTR  mail.zhizhu.online.
```

## Lấy DKIM key

Sau khi Mailu chạy và đã thêm domain qua Admin UI:

```bash
# Vào Admin UI → Domains → chọn domain → Generate DKIM keys
# Copy DNS record hiển thị ra, thêm vào DNS

# Hoặc xem file trực tiếp:
docker exec -it mailu-admin-1 cat /dkim/zhizhu.online.dns.txt
```

## Tạo admin user lần đầu

```bash
docker exec -it mailu-admin-1 flask mailu admin admin zhizhu.online <password>
```

Đăng nhập tại `https://mail.zhizhu.online/admin`.

## Quản lý

```bash
# Logs
docker compose logs -f
docker compose logs -f smtp
docker compose logs -f front

# Restart một service
docker compose restart smtp

# Dừng
docker compose down

# Update
bash up.sh
```

## Gửi email từ backend

```
Host: 127.0.0.1
Port: 587
Security: STARTTLS
User: user@zhizhu.online
Pass: (mật khẩu mailbox)
```
