# Dev Tunnels

Giữ các Cloudflare Access TCP tunnel luôn sống để code local có thể connect
tới `redis`/`rabbitmq` trên server — 2 service này chỉ bind `127.0.0.1` nên
không public, phải qua tunnel + Access policy mới connect được.

## Yêu cầu

- Đã cài `cloudflared` (`cloudflared -v` để kiểm tra).
- Đã có Access Application cho từng hostname (`redis.zhizhu.online`,
  `rabbitmq-amqp.zhizhu.online`) phía Cloudflare Zero Trust, gắn policy cho
  email của bạn.

## Cài đặt 1 lần (khuyên dùng)

Double-click **`install.cmd`** — vậy là xong vĩnh viễn: script tự đăng ký
Task Scheduler (`ZhizhuDevTunnels`, chạy lúc login) và start tunnel ngay lập
tức. Từ giờ chỉ cần bật máy/login là có sẵn `localhost:6379` +
`localhost:5672`, không cần chạy gì thêm. Chạy lại `install.cmd` bất cứ lúc
nào cũng an toàn (idempotent — không tạo trùng task hay trùng tunnel).

## Cấu trúc thư mục

```text
dev-tunnels/
├── install.cmd       ← double-click để cài
├── uninstall.cmd     ← double-click để gỡ
├── scripts/          ← logic thật, không cần đụng vào
│   ├── install.ps1
│   ├── uninstall.ps1
│   ├── dev-tunnels.ps1
│   └── stop-tunnels.ps1
├── run/               (tự sinh lúc chạy, gitignored)
└── logs/              (tự sinh lúc chạy, gitignored)
```

## Chạy thủ công (không cần Task Scheduler)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev-tunnels.ps1
```

Lần đầu chạy, `cloudflared` sẽ tự mở browser để bạn login Access (email OTP
hoặc SSO) — sau đó token được cache, các lần sau không cần login lại (trừ
khi token hết hạn).

Script sẽ:

1. Dừng các tunnel đang chạy từ lần trước (tránh chạy trùng).
2. Với mỗi tunnel, tạo 1 file `.cmd` loop trong thư mục `run/` rồi chạy nó
   ẩn (`Start-Process -WindowStyle Hidden`) — process này **độc lập** với
   PowerShell đang gọi script, nên tắt terminal không làm tunnel chết.
3. Nếu `cloudflared` rớt kết nối, loop tự restart sau 5s.

Sau khi chạy xong, connect như bình thường:

```bash
redis-cli -a <REDIS_PASSWORD> -h 127.0.0.1 -p 6379 ping
```

## Dừng tunnel (không gỡ task)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stop-tunnels.ps1
```

Dùng khi muốn tạm dừng — task Scheduler vẫn còn, lần login sau tunnel lại
tự chạy tiếp.

## Gỡ hoàn toàn

Double-click **`uninstall.cmd`** — dừng tunnel đang chạy, gỡ task
`ZhizhuDevTunnels` khỏi Task Scheduler, xoá `run/` và `logs/`. Sau bước này
máy sẽ không còn tự chạy tunnel nữa (muốn dùng lại thì chạy `install.cmd`).

## Quản lý Task Scheduler thủ công

```powershell
Get-ScheduledTask -TaskName ZhizhuDevTunnels
Start-ScheduledTask -TaskName ZhizhuDevTunnels   # chạy ngay để test
Unregister-ScheduledTask -TaskName ZhizhuDevTunnels -Confirm:$false  # gỡ bỏ
```

## Thêm tunnel mới

Sửa mảng `$tunnels` trong `scripts\dev-tunnels.ps1`, thêm entry `Name`/
`Hostname`/`LocalPort`, rồi chạy lại `install.cmd` (hoặc restart task).

## Logs

```powershell
Get-Content .\logs\redis.log -Tail 20 -Wait
Get-Content .\logs\rabbitmq.log -Tail 20 -Wait
```

## Lưu ý bảo mật

- File `run/*.cmd` được tạo lúc chạy (chứa đường dẫn `cloudflared.exe` local,
  không chứa secret) — không cần gitignore riêng nhưng cũng không cần commit,
  đã thêm vào `.gitignore` của thư mục này.
- Đây là tunnel cho **dev cá nhân**, không phải hạ tầng production — không
  ảnh hưởng gì tới `docker-compose.yml`/`.env` của các service trên server.
