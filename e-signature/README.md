# E-signature

Service ký số nội bộ (ASP.NET Core 8): giữ khóa ký của người dùng (mã hóa, mở bằng PIN) và CA nội bộ, ký / xác thực PDF.
Chạy trên cổng `8094` (chỉ bind `127.0.0.1`).

Image được build & push lên GHCR từ repo [`e-signature`](https://github.com/fega-kt/e-signature) — compose ở đây chỉ pull & chạy.
Mỗi lần push `main` ở repo đó, GitHub Actions chạy test, build image mới rồi SSH vào server (qua Cloudflare Access, giống backend)
chạy `VAULT_TOKEN=... APP_IMAGE=... bash up.sh` trong thư mục này.

**Chỉ dùng nội bộ**: không thêm route Cloudflare Tunnel. Backend gọi qua Docker DNS, đặt trong secret Vault của backend:

```text
ESIGN_URL=http://zhizhu-e-signature:8080
ESIGN_SERVICE_TOKEN=<trùng Signing__ServiceToken>
```

## Lần đầu cài đặt

```bash
cd ~/apps/server-deploy/e-signature
cp .vault.json.example .vault.json
nano .vault.json   # điền addr Vault và đường dẫn secret (mặc định secret/zhizhu/e-signature)
```

Lưu các key trong `.env.example` vào Vault tại `secret/zhizhu/e-signature`, rồi:

```bash
bash up.sh
# Tạo CA nội bộ — chỉ một lần
curl -X POST -H "X-Service-Token: <Signing__ServiceToken>" http://127.0.0.1:8094/ca/init
```

**`Signing__MasterKey` mất là mất toàn bộ khóa ký** (mọi người phải đăng ký chữ ký lại) — lưu thêm một bản ở nơi an toàn ngoài Vault.

## Chạy / cập nhật

```bash
bash up.sh   # fetch secrets mới từ Vault → ghi .env → pull image → recreate container
```

## Biến môi trường (secret trong Vault, xem `.env.example`)

| Biến | Mô tả |
| ---- | ----- |
| `Signing__MasterKey` | base64 của 32 byte ngẫu nhiên (`openssl rand -base64 32`) — khóa bọc mọi khóa ký |
| `Signing__ServiceToken` | Token dùng chung với backend, ≥ 32 ký tự |
| `Signing__Organization`, `Signing__CaName` | Tên tổ chức / tên CA ghi trong chứng thư |
| `Signing__KeyStore__Driver` | `r2` |
| `Signing__KeyStore__R2AccountId`, `R2AccessKeyId`, `R2SecretAccessKey`, `R2Bucket` | Bucket R2 **riêng** cho khóa ký, token chỉ có quyền trên bucket này |
| `APP_IMAGE` | Image GHCR — mặc định `:latest`, override để pin bản `sha-<commit>` |
| `E_SIGNATURE_PORT` | Port host bind (mặc định `8094`) |

## Kiểm tra

```bash
curl -s http://127.0.0.1:8094/health
docker logs zhizhu-e-signature -n 100
```
