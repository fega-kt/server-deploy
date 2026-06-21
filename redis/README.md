# Redis

Cache / session store, chạy trên cổng `6379` (chỉ bind `127.0.0.1`).  
Dữ liệu được persist qua AOF vào Docker volume `redis_data`.

## Chạy

```bash
cp .env.example .env
nano .env          # đổi REDIS_PASSWORD
docker compose up -d
```

> Đặt `REDIS_PASSWORD` giống nhau ở đây và trong `backend/.env`.

## Kiểm tra kết nối

```bash
docker exec zhizhu-redis redis-cli -a $(grep REDIS_PASSWORD .env | cut -d= -f2) ping
# Kết quả: PONG
```

## Logs

```bash
docker logs zhizhu-redis -f
docker logs zhizhu-redis -n 100
```
