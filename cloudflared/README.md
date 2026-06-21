# Cloudflared

Cloudflare Tunnel — expose các service ra internet mà không cần mở port trên firewall.

## Cấu hình

```bash
cp config.example.yml config.yml
nano config.yml    # điền TUNNEL_ID và đường dẫn credentials
```

Cấu trúc routing mặc định:

| Domain | Service |
|--------|---------|
| `api.zhizhu.online` | `http://127.0.0.1:3000` (backend) |
| `app.zhizhu.online` | `http://127.0.0.1:8080` (web) |

## Chạy tunnel

```bash
cloudflared tunnel run
```

Hoặc chạy dưới dạng service hệ thống:

```bash
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

## Tạo tunnel mới (nếu chưa có)

```bash
cloudflared tunnel create zhizhu
cloudflared tunnel route dns zhizhu api.zhizhu.online
cloudflared tunnel route dns zhizhu app.zhizhu.online
```

Sau đó lấy `TUNNEL_ID` và đường dẫn file credentials từ output để điền vào `config.yml`.
