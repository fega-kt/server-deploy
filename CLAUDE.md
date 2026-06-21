# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Docker Compose–based deployment layout for the Zhizhu platform. Each service lives in its own subdirectory with its own `docker-compose.yml` and `.env` file. Services are stitched together via a shared external Docker network (`zhizhu_net`). The `Infrastructure/` directory contains supporting services (currently Vault).

## Deployment target

All files are deployed to `/opt/zhizhu` on the production server. Each subdirectory maps directly to that path.

## One-time server setup

```bash
sudo mkdir -p /opt/zhizhu && sudo chown -R $USER:$USER /opt/zhizhu
docker network create zhizhu_net
```

## Per-service commands

Each service is managed independently from its own directory:

```bash
# Start
cd /opt/zhizhu/<service>   # redis | backend | web | Infrastructure
cp .env.example .env       # first time only — then edit .env
docker compose up -d

# Logs
docker logs zhizhu-backend -n 100
docker logs zhizhu-redis   -n 100
docker logs zhizhu-web     -n 100
docker logs vault          -n 100

# Restart / stop
docker compose restart
docker compose down
```

## Architecture

```
Internet → Cloudflare Tunnel (cloudflared)
               ├── api.zhizhu.online  → 127.0.0.1:3000  (backend)
               └── app.zhizhu.online  → 127.0.0.1:8080  (web)

Host (127.0.0.1 only)
  :3000  zhizhu-backend  ← reads env from backend/.env, connects to zhizhu-redis via Docker DNS
  :6379  zhizhu-redis    ← password-protected, AOF persistence on redis_data volume
  :8080  zhizhu-web      ← static/frontend image
  :8200  vault           ← HashiCorp Vault, data on vault_data volume

Docker network: zhizhu_net (external, shared by backend / redis / web)
Vault is NOT on zhizhu_net — it runs standalone on Infrastructure/docker-compose.yml
```

## Key conventions

- **All host ports bind to `127.0.0.1`** — nothing is exposed publicly; public traffic comes only through the Cloudflare tunnel.
- **Images are pulled from GHCR** (`ghcr.io/owner/repo:latest`, `ghcr.io/owner/web:latest`) — update `APP_IMAGE` / `WEB_IMAGE` in `.env` to pin a version.
- **Redis connects by container name** (`REDIS_HOST=zhizhu-redis`) because both containers share `zhizhu_net`. Using `localhost` or the host IP will not work.
- **Vault uses `server` mode** with a file storage backend (`/vault/file`). The config directory (`Infrastructure/config/`) must contain a valid `vault.hcl` before starting. `IPC_LOCK` capability is required (already set in the compose file).
- **Persistence across restarts** is handled by named Docker volumes (`redis_data`, `vault_data`) — these survive `docker compose down` but are removed by `docker compose down -v`.
