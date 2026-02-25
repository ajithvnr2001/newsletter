---
description: Build and run the full Docker Compose stack locally
---

# Docker Stack

Build and start all 6 services: PostgreSQL, Listmonk, n8n, Postfix, OpenDKIM, Scrapling API.

## Prerequisites
- Docker + Docker Compose installed
- `.env` file created with all required variables (see walkthrough)

## Steps

1. Create `.env` from example if not done:
```bash
cp .env.example .env
# Edit .env with your values
```

2. Build and start all services:
```bash
docker compose --env-file .env up -d --build
```

// turbo
3. Check service status:
```bash
docker compose ps
```

// turbo
4. Check logs for errors:
```bash
docker compose logs --tail=50 postgres listmonk n8n postfix opendkim scrapling-api
```

// turbo
5. Verify PostgreSQL health:
```bash
docker compose exec postgres pg_isready -U listmonk -d listmonk
```

// turbo
6. Verify Listmonk:
```bash
curl -s http://localhost:9000 | head -5
```

// turbo
7. Verify n8n:
```bash
curl -s http://localhost:5678/healthz
```

// turbo
8. Verify Scrapling API:
```bash
curl -s http://localhost:8000/health
```

9. Import n8n workflows (auto on boot, manual fallback):
```bash
docker compose exec -T n8n sh -lc 'for f in /workflows/*.json; do n8n import:workflow --input "$f"; done'
```

## Stop Stack
```bash
docker compose down
```

## Reset (destroy volumes):
```bash
docker compose down -v
```
