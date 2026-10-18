# File Converter

Service chuyển Word / Excel / PowerPoint / ảnh / HTML sang PDF (ASP.NET Core 8 + Syncfusion), chạy trên cổng `8093` (chỉ bind `127.0.0.1`).
Backend dùng để chuyển "Văn bản tờ trình" sang PDF trước khi ký số.

Image được build & push lên GHCR từ repo [`netcore`](https://github.com/fega-kt/netcore) — compose ở đây chỉ pull & chạy.
Mỗi lần push `main` ở repo đó, GitHub Actions build image mới rồi SSH vào server (qua Cloudflare Access, giống backend)
chạy `VAULT_TOKEN=... APP_IMAGE=<sha> bash up.sh` trong thư mục này.

**Chỉ dùng nội bộ**: service không có xác thực, nên không thêm route Cloudflare Tunnel. Backend gọi qua Docker DNS:

```text
FILE_CONVERTER_URL=http://zhizhu-file-converter:8080
```

(đặt biến này trong secret Vault của backend).

## Lần đầu cài đặt

```bash
cd /opt/zhizhu/file-converter
cp .vault.json.example .vault.json
nano .vault.json   # điền addr Vault và đường dẫn secret (mặc định secret/zhizhu/file-converter)
```

Lưu các key trong `.env.example` vào Vault tại `secret/zhizhu/file-converter`, rồi:

```bash
bash up.sh
```

## Chạy / cập nhật

```bash
bash up.sh   # fetch secrets mới từ Vault → ghi .env → pull image → recreate container
```

Chỉ cập nhật image (không đổi secret) — GitHub Actions tự làm, hoặc tay:

```bash
docker compose pull && docker compose up -d
```

## Biến môi trường (secret trong Vault, xem `.env.example`)

| Biến | Mô tả |
| ---- | ----- |
| `SYNCFUSION_LICENSE_KEY` | License Syncfusion Community, tạo cho đúng bản 33.x. Thiếu / sai thì PDF có watermark |
| `APP_IMAGE` | Image GHCR — mặc định `:latest`, override để pin bản `sha-<commit>` |
| `FILE_CONVERTER_PORT` | Port host bind (mặc định `8093`) |

## Kiểm tra

```bash
curl -s http://127.0.0.1:8093/api/health
curl -s -F "file=@test.docx" http://127.0.0.1:8093/api/convert/file -o test.pdf
docker logs zhizhu-file-converter -n 100
```
