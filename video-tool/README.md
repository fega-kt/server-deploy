# Video Tool

Giao diện web tạo video YouTube bằng AI (Streamlit), chạy trên cổng `8501` (chỉ bind `127.0.0.1`), expose ra Internet qua Cloudflare Tunnel tại `video.zhizhu.online`.

Image được build & push lên GHCR từ repo [`tools_video`](https://github.com/fega-kt/tools_video) — compose ở đây chỉ pull & chạy. Mỗi lần push `main` ở repo đó, GitHub Actions build image mới rồi SSH vào server chạy `docker compose pull && up -d` trong thư mục này.

Secrets được lấy từ HashiCorp Vault thay vì chỉnh `.env` tay.

## Lần đầu cài đặt

```bash
cd /opt/zhizhu/video-tool
cp .vault.json.example .vault.json
nano .vault.json   # điền addr Vault và đường dẫn secret (mặc định secret/video-tool)
```

Lưu các key trong `.env.example` vào Vault tại `secret/video-tool`, rồi:

```bash
bash up.sh
```

Tạo tài khoản admin đầu tiên (lưu trong MongoDB):

```bash
docker exec -it zhizhu-video-tool python -m ui.auth
```

## Chạy / cập nhật

```bash
bash up.sh   # fetch secrets mới từ Vault → ghi .env → pull image → recreate container
```

Chỉ cập nhật image (không đổi secret) — GitHub Actions tự làm, hoặc tay:

```bash
docker compose pull && docker compose up -d
```

## Dữ liệu

| Đường dẫn trên host | Trong container | Nội dung |
| ---- | ---- | ---- |
| `./data` | `/data` | `branding.json`, `logo.png`, `data/.env` (ngôn ngữ / giọng mặc định đổi từ giao diện) |
| `OUTPUT_PATH` (mặc định `./data/output`) | `/output` | Video, thumbnail, kịch bản đã làm |

Có 2 file env khác nhau: `.env` (ở thư mục này, do `up.sh` ghi từ Vault, nạp vào container) và `data/.env` (giao diện ghi khi đổi cài đặt). Key có trong Vault luôn được ưu tiên — đổi key đó trong giao diện sẽ không có tác dụng.

Container chạy với UID `1000`; `up.sh` tự `chown` thư mục dữ liệu nếu cần.

## Biến môi trường (secret trong Vault, xem `.env.example`)

| Biến | Mô tả |
| ---- | ----- |
| `APP_IMAGE` | Image GHCR — mặc định `:latest`, override để pin bản `sha-<commit>` |
| `VIDEO_TOOL_PORT` | Port host bind (mặc định `8501`) |
| `CLAUDE_CODE_OAUTH_TOKEN` | Token gói Claude Max (`claude setup-token`) — viết kịch bản, kiểm chứng, chọn thumbnail |
| `MONGODB_URI` / `MONGODB_DB` | MongoDB lưu user và phiên đăng nhập |
| `AUTH_SECRET` | Khóa bí mật băm mật khẩu + token (≥ 32 ký tự). Giống máy cá nhân nếu dùng chung DB |
| `SESSION_DAYS` | Số ngày giữ đăng nhập (mặc định 30) |
| `PIXABAY_API_KEY` | Video nền |
| `VIDEO_LANG` | Ngôn ngữ mặc định `vi` / `en` |
| `OUTPUT_PATH` | (Tuỳ chọn) thư mục video trên host |

## Cloudflare Tunnel

Thêm route vào `cloudflared/config.example.yml` (đã có sẵn ở repo này):

```text
video.zhizhu.online -> http://127.0.0.1:8501
```

## Logs

```bash
docker logs zhizhu-video-tool -n 100
```
