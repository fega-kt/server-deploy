# OnlyOffice Document Server

## Deploy

### Yêu cầu

- Docker + Docker Compose, `jq` trên host
- Vault đang chạy và có secret tại `secret/onlyoffice`

### Cấu trúc secret trong Vault

```bash
vault kv put secret/onlyoffice \
  JWT_ENABLED=true \
  JWT_HEADER=Authorization \
  JWT_SECRET=$(openssl rand -hex 32)
```

### Lần đầu

```bash
cd /opt/zhizhu/onlyoffice
cp .vault.json.example .vault.json   # sửa "addr" thành địa chỉ Vault
bash up.sh
# → chọn login method (Token / Userpass / LDAP)
# → nhập credentials
# → docker compose pull && docker compose up -d
```

### Cách hoạt động

`up.sh` chỉ lấy Vault token rồi truyền vào container. Container tự fetch secrets từ Vault mỗi lần start thông qua `vault-init.sh` (entrypoint wrapper) — secrets không bao giờ ghi ra disk.

```text
up.sh  →  lấy VAULT_TOKEN  →  docker compose up
                                    │
                              vault-init.sh (trong container)
                                    │  fetch Vault bằng VAULT_TOKEN
                                    │  export JWT_SECRET... vào memory
                                    └─ exec OnlyOffice
```

### Restart / sau server reboot

```bash
docker compose up -d
```

Không cần chạy `up.sh` lại — `VAULT_TOKEN` đã được bake vào Docker container config từ lần deploy đầu, container tự dùng để fetch secrets từ Vault mỗi lần khởi động.

### Redeploy / cập nhật secrets

```bash
bash up.sh
```

### Kiểm tra

```bash
docker logs zhizhu-onlyoffice -n 50
curl http://localhost:8090/healthcheck   # kết quả mong đợi: true
```

### Ghi chú bảo mật

- Secrets (`JWT_SECRET`...) chỉ tồn tại trong memory container.
- `VAULT_TOKEN` lưu trong Docker container config — nếu bị lộ, revoke trong Vault là vô hiệu hóa ngay.

---

## Tích hợp

### Tổng quan

**OnlyOffice Document Server** là dịch vụ Docker cho phép xem/chỉnh sửa Word, Excel, PowerPoint, PDF... trên trình duyệt, tích hợp qua JavaScript.

```text
Người dùng (trình duyệt)
        │
        ▼
  Backend (sinh config + ký JWT)
        │
        ▼
  OnlyOffice Document Server
        │
        ▼
  Storage (URL file)
```

## Cấu hình Nginx Reverse Proxy + SSL

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
