# Hướng dẫn xây dựng OnlyOffice Document Server để View File

## 1. Tổng quan

**OnlyOffice Document Server** là một dịch vụ độc lập (chạy bằng Docker) cho phép:
- Xem (view) file Word, Excel, PowerPoint, PDF... ngay trên trình duyệt
- Chỉnh sửa trực tuyến (nếu cần, có thể tắt để chỉ dùng chế độ view)
- Tích hợp vào bất kỳ hệ thống web nào (CMS, quản lý tài liệu, ERP...) thông qua một đoạn JavaScript nhúng (config.js)

Kiến trúc tổng quát:

```
Người dùng (trình duyệt)
        │
        ▼
  Ứng dụng của bạn (Web App / Backend)
        │  (sinh config, JWT token, URL file)
        ▼
  OnlyOffice Document Server (Docker container)
        │
        ▼
  Storage lưu file (local disk / S3 / server riêng)
```

Ứng dụng của bạn **không nhúng file trực tiếp**, mà:
1. Cung cấp URL để Document Server tải file về (file phải truy cập được qua HTTP/HTTPS từ container)
2. Document Server render ra và trả về iframe hiển thị cho người dùng

---

## 2. Yêu cầu hệ thống

| Thành phần | Tối thiểu | Khuyến nghị |
|---|---|---|
| CPU | 2 core | 4 core |
| RAM | 4 GB | 8 GB+ |
| Ổ đĩa | 40 GB | 100 GB+ (SSD) |
| OS | Linux (Ubuntu/CentOS) | Ubuntu 22.04 LTS |
| Docker | 20.x+ | Bản mới nhất |
| Domain + SSL | Có (khuyến nghị bắt buộc cho production) | Let's Encrypt |

---

## 3. Cài đặt bằng Docker (cách khuyến nghị)

### 3.1. Cài Docker (nếu chưa có)

```bash
curl -fsSL https://get.docker.com | sh
sudo systemctl enable --now docker
```

### 3.2. Deploy bằng Docker Compose + Vault

Project này dùng `docker-compose.yml` kết hợp script `up.sh` để kéo secrets từ Vault rồi mới chạy container — không lưu secret trực tiếp trong file.

**Bước 1 — Chuẩn bị Vault:**

Lưu secrets vào Vault tại path `secret/zhizhu/onlyoffice`:

```bash
vault kv put secret/zhizhu/onlyoffice \
  ONLYOFFICE_PORT=8090 \
  JWT_SECRET=$(openssl rand -hex 32)
```

**Bước 2 — Cấu hình Vault connection:**

```bash
cd /opt/zhizhu/onlyoffice
cp .vault.json.example .vault.json
# Sửa "addr" nếu Vault chạy ở địa chỉ khác
```

Nội dung `.vault.json`:

```json
{
  "addr": "http://127.0.0.1:8200",
  "kv": 2,
  "envs": {
    "production": "secret/zhizhu/onlyoffice"
  }
}
```

**Bước 3 — Chạy:**

```bash
bash up.sh
# → chọn login method (Token / Userpass / LDAP)
# → nhập credentials
# → secrets tự ghi vào .env
# → docker compose pull && docker compose up -d
```

**Giải thích các biến quan trọng:**

- `JWT_ENABLED=true`: bật xác thực bằng JWT — **bắt buộc** nếu server public ra internet, tránh bị lợi dụng để render file tuỳ ý.
- `JWT_SECRET`: chuỗi bí mật dùng để ký token, phải trùng với secret dùng ở phía ứng dụng backend. Lưu trong Vault, không hardcode.
- `ONLYOFFICE_PORT`: port lắng nghe trên host, chỉ bind `127.0.0.1` — traffic vào qua Cloudflare Tunnel.

### 3.3. Kiểm tra hoạt động

```bash
docker ps
curl http://localhost:8090/healthcheck
# Kết quả mong đợi: true
```

Trang test tích hợp (upload & xem file trực tiếp, không cần frontend):

```text
http://localhost:8090/example/
```

---

## 4. Cấu hình Nginx Reverse Proxy + SSL

Để chạy production an toàn, nên đặt Nginx phía trước container, dùng HTTPS.

### 4.1. Cài Nginx & Certbot

```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
```

### 4.2. Cấu hình file `/etc/nginx/sites-available/onlyoffice.conf`

```nginx
server {
    listen 80;
    server_name office.example.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Bắt buộc cho WebSocket (đồng bộ realtime)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        client_max_body_size 100m;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/onlyoffice.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 4.3. Bật SSL miễn phí

```bash
sudo certbot --nginx -d office.example.com
```

Sau bước này, Document Server sẽ chạy tại `https://office.example.com`.

---

## 5. Tích hợp vào ứng dụng để View File

### 5.1. Luồng hoạt động

1. Backend của bạn tạo một object cấu hình (config) mô tả file cần xem: URL tải file, loại file, quyền (chỉ xem), thông tin người dùng...
2. Backend ký config này bằng JWT (cùng secret đã cấu hình ở bước 3.2).
3. Frontend nhúng script `api.js` của Document Server và khởi tạo `DocsAPI.DocEditor` với config đã ký.

### 5.2. Nhúng script phía Frontend (HTML)

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Xem tài liệu</title>
</head>
<body>
  <div id="placeholder" style="width:100%; height:100vh;"></div>

  <!-- Script này lấy từ chính Document Server -->
  <script src="https://office.example.com/web-apps/apps/api/documents/api.js"></script>
  <script>
    const config = {
      "document": {
        "fileType": "docx",
        "key": "unique-doc-id-12345",      // key duy nhất, đổi khi file thay đổi
        "title": "BaoCao-Q3.docx",
        "url": "https://cdn.example.com/files/BaoCao-Q3.docx", // URL public để server tải file
        "permissions": { "edit": false, "download": true, "print": true }
      },
      "documentType": "word",              // word | cell | slide | pdf
      "editorConfig": {
        "mode": "view",                    // "view" = chỉ xem, "edit" = chỉnh sửa
        "lang": "vi"
      },
      "token": "<JWT_TOKEN_KY_TU_BACKEND>" // backend trả về, đã ký toàn bộ config này
    };

    new DocsAPI.DocEditor("placeholder", config);
  </script>
</body>
</html>
```

### 5.3. Sinh JWT token phía Backend (ví dụ Node.js)

```javascript
const jwt = require("jsonwebtoken");

const JWT_SECRET = "doi_secret_nay_thanh_chuoi_bi_mat_manh"; // trùng với JWT_SECRET của container

function buildViewerConfig(fileUrl, fileName, fileType, docKey) {
  const payload = {
    document: {
      fileType: fileType,     // "docx", "xlsx", "pptx", "pdf"...
      key: docKey,            // đổi mỗi khi nội dung file thay đổi để tránh cache sai
      title: fileName,
      url: fileUrl,
      permissions: { edit: false, download: true, print: true }
    },
    documentType: mapDocumentType(fileType),
    editorConfig: { mode: "view", lang: "vi" }
  };

  const token = jwt.sign(payload, JWT_SECRET, { expiresIn: "1h" });
  return { ...payload, token };
}

function mapDocumentType(ext) {
  if (["doc", "docx", "odt", "rtf", "txt"].includes(ext)) return "word";
  if (["xls", "xlsx", "ods", "csv"].includes(ext)) return "cell";
  if (["ppt", "pptx", "odp"].includes(ext)) return "slide";
  if (["pdf"].includes(ext)) return "pdf";
  return "word";
}
```

> **Lưu ý quan trọng:** URL file (`document.url`) phải được **Document Server truy cập được**, nghĩa là container phải gọi HTTP tới URL đó thành công. Nếu file lưu nội bộ (mạng riêng), cần mở firewall cho phép Document Server gọi vào, hoặc dùng URL ký tạm thời (pre-signed URL nếu dùng S3/MinIO).

---

## 6. Chỉ dùng để "View" — Vô hiệu hoá chỉnh sửa & lưu

Nếu mục đích **chỉ để xem**, không cho sửa/lưu ngược lại:

- `editorConfig.mode = "view"`
- `document.permissions.edit = false`
- Không cấu hình `editorConfig.callbackUrl` (đây là URL để Document Server gọi về khi người dùng bấm Lưu — nếu không cấu hình, server sẽ không có nơi để lưu thay đổi)
- Có thể ẩn thêm thanh công cụ chỉnh sửa bằng `customization.toolbar = false` (tuỳ nhu cầu)

---

## 7. Bảo mật

1. **Luôn bật `JWT_ENABLED=true`** khi Document Server public ra internet — tránh việc bất kỳ ai cũng có thể ra lệnh cho server render file tuỳ ý.
2. **Dùng HTTPS** cho cả Document Server lẫn URL file nguồn.
3. **Giới hạn IP** cho phép gọi tới Document Server qua firewall/security group nếu chỉ nội bộ dùng.
4. **Secret JWT** nên lưu trong biến môi trường/secret manager, không hardcode trong code.
5. Cập nhật image Docker định kỳ để vá lỗi bảo mật: `docker pull onlyoffice/documentserver`.

---

## 8. Kiểm tra & Xử lý sự cố (Troubleshooting)

| Vấn đề | Nguyên nhân thường gặp | Cách xử lý |
| --- | --- | --- |
| Trang trắng, không hiện tài liệu | Sai `document.url`, container không tải được file | Kiểm tra container có gọi được URL: `docker exec -it onlyoffice-documentserver curl -I <url_file>` |
| Lỗi "Token is not correct" | Sai JWT secret hoặc payload ký không khớp cấu trúc | Đảm bảo secret backend = secret container, và cấu trúc `document`/`editorConfig` khi ký giống hệt lúc gửi cho frontend |
| Không kết nối realtime (đồng bộ) | Thiếu cấu hình WebSocket ở Nginx | Thêm `proxy_set_header Upgrade`/`Connection "upgrade"` như mục 4.2 |
| Container health check fail | Chưa đủ RAM, hoặc DB nội bộ (Postgres) lỗi | Kiểm tra log: `docker logs onlyoffice-documentserver` |
| File cache cũ dù đã cập nhật | `document.key` không đổi khi file thay đổi | Luôn sinh `key` mới (VD: hash nội dung file hoặc timestamp) mỗi khi file được cập nhật |

Xem log chi tiết:

```bash
docker logs -f onlyoffice-documentserver
```

---

## 9. Tóm tắt các bước triển khai

1. Cài Docker → chạy container `onlyoffice/documentserver` với `JWT_ENABLED=true`
2. Cấu hình Nginx reverse proxy + SSL (Let's Encrypt)
3. Backend sinh config + ký JWT token cho từng file cần view
4. Frontend nhúng `api.js` và khởi tạo `DocsAPI.DocEditor` với config trên
5. Đặt `mode: "view"` để chỉ xem, không cho sửa
6. Kiểm tra bảo mật: JWT, HTTPS, firewall

---

*Tài liệu này áp dụng cho OnlyOffice Document Server (Community Edition, tự host). Nếu cần review/comment/co-editing nâng cao (multi-user real-time), cân nhắc thêm cấu hình Redis/RabbitMQ cho cluster nhiều node.*
