# SharePoint Downloader

Tải file từ SharePoint qua Access Token / Certificate / Client Secret, chạy trên cổng `8092` (chỉ bind `127.0.0.1`).

Image build từ [repo sp-nextjs](https://github.com/fega-kt/sp-nextjs). Không cần `.env` hay Vault — credentials do người dùng nhập ngay trên trình duyệt, server không lưu.

## Chạy

```bash
docker compose up -d
```

## Biến môi trường (tuỳ chọn, `.env`)

| Biến | Mô tả |
|------|-------|
| `SP_IMAGE` | Docker image, mặc định `ghcr.io/fega-kt/sp-nextjs:latest` — pin theo `sha-<commit>` nếu cần |
| `SP_PORT` | Cổng expose ra host (mặc định `8092`) |

## Cập nhật image mới

CI của repo `sp-nextjs` tự làm khi push lên `main` (SSH vào server rồi chạy 2 lệnh dưới). Làm tay:

```bash
docker compose pull
docker compose up -d
```

## Logs

```bash
docker logs zhizhu-sp-nextjs -f
docker logs zhizhu-sp-nextjs -n 100
```
