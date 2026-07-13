# Mailu

Mail server (Postfix + Dovecot + Rspamd + ClamAV + Roundcube), ~7 containers.

Web UI và webmail expose qua Cloudflare Tunnel. Mail ports tiếp nhận trực tiếp từ internet.

## Cổng

| Cổng | Giao thức    | Binding   | Expose qua        |
| ---- | ------------ | --------- | ----------------- |
| 80   | HTTP         | 127.0.0.1 | Cloudflare Tunnel |
| 443  | HTTPS        | 127.0.0.1 | Cloudflare Tunnel |
| 25   | SMTP         | 0.0.0.0   | Trực tiếp         |
| 465  | SMTPS        | 0.0.0.0   | Trực tiếp         |
| 587  | Submission   | 0.0.0.0   | Trực tiếp         |
| 143  | IMAP         | 0.0.0.0   | Trực tiếp         |
| 993  | IMAPS        | 0.0.0.0   | Trực tiếp         |
| 110  | POP3         | 0.0.0.0   | Trực tiếp         |
| 995  | POP3S        | 0.0.0.0   | Trực tiếp         |

## Lần đầu cài đặt

```bash
cd /opt/zhizhu/mailu

# 1. Tạo config
cp mailu.env.example mailu.env
nano mailu.env          # điền SECRET_KEY, DOMAIN, HOSTNAMES

# 2. Khởi động
bash up.sh
```

### Tạo SECRET_KEY

```bash
openssl rand -hex 16
```

## TLS / Let's Encrypt

Vì `front` bind HTTP vào `127.0.0.1`, HTTP-01 challenge không tiếp cận được từ internet.

**Cách A — Tạm mở port 80 khi cấp cert lần đầu:**

```bash
# Đổi sang 0.0.0.0 trong docker-compose.yml tạm thời:
#   - "0.0.0.0:80:80"
bash up.sh
# Chờ cert được cấp (xem log front)
docker compose logs -f front

# Sau khi có cert, đổi lại:
#   - "127.0.0.1:80:80"
bash up.sh
```

**Cách B — Cert thủ công (acme.sh + Cloudflare DNS-01):**

```bash
# Cấp cert qua DNS challenge
CF_Token="<cloudflare_api_token>" acme.sh --issue \
  -d mail.zhizhu.online --dns dns_cf

# Copy vào volume mailu_certs
# Tìm mountpoint:
docker volume inspect mailu_mailu_certs

# Copy cert + key
cp /path/to/fullchain.pem <mountpoint>/cert.pem
cp /path/to/key.pem       <mountpoint>/key.pem

# Dùng TLS_FLAVOR=cert trong mailu.env
sed -i 's/^TLS_FLAVOR=.*/TLS_FLAVOR=cert/' mailu.env
bash up.sh
```

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
mail.zhizhu.online.    A    <IP_server>

; MX
zhizhu.online.         MX   10   mail.zhizhu.online.

; SPF
zhizhu.online.         TXT  "v=spf1 mx ~all"

; DKIM — lấy sau khi Mailu chạy (xem phần dưới)
mailu._domainkey.zhizhu.online.  TXT  "v=DKIM1; k=rsa; p=..."

; DMARC
_dmarc.zhizhu.online.  TXT  "v=DMARC1; p=quarantine; rua=mailto:admin@zhizhu.online"

; Autoconfig (giúp email clients tự cấu hình)
autoconfig.zhizhu.online.  A    <IP_server>
autodiscover.zhizhu.online. A   <IP_server>

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

Sau đó đăng nhập tại `https://mail.zhizhu.online/admin`.

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
docker compose pull && docker compose up -d --force-recreate
```

## Gửi email từ backend

```
Host: 127.0.0.1
Port: 587
Security: STARTTLS
User: user@zhizhu.online
Pass: (mật khẩu mailbox)
```
