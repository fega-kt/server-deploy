# ADO Dashboard

So sánh 2 nhánh Azure DevOps qua Pull Request, chạy trên cổng `8091` (chỉ bind `127.0.0.1`).

Container serve trang tĩnh và làm proxy same-origin sang Azure DevOps Server để né CORS
(xem [repo ado](https://github.com/fega-kt/ado)). PAT do người dùng nhập ngay trên trình
duyệt, không lưu ở phía server.

## Chạy

```bash
cp .env.example .env
nano .env          # điền đúng ALLOWED_HOSTS = host thật của ADO Server
docker compose up -d
```

## Biến môi trường (`.env`)

| Biến | Mô tả |
|------|-------|
| `ADO_IMAGE` | Docker image, ví dụ `ghcr.io/fega-kt/ado:latest` hoặc pin theo sha |
| `ADO_PORT` | Cổng expose ra host (mặc định `8091`) |
| `ALLOWED_HOSTS` | Danh sách hostname ADO Server được phép proxy tới, cách nhau bởi dấu phẩy — chặn proxy bị lợi dụng gọi ra domain khác (SSRF) |

## Cập nhật image mới

```bash
docker compose pull
docker compose up -d
```

## Logs

```bash
docker logs zhizhu-ado -f
docker logs zhizhu-ado -n 100
```
