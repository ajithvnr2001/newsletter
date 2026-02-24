# Phase 1 Implementation Plan

## 1) Directory and File Tree
- `cloud-init/user-data.sh`: bootstrap on ephemeral VM.
- `cloudflare/d1/schema.sql`: permanent click tracking schema.
- `cloudflare/workers/click-tracker/*`: 24/7 click redirect worker.
- `cloudflare/workers/spawn-server/*`: daily VM spawner worker.
- `cloudflare/workers/backup-delete-check/*`: fallback force-delete worker.
- `docker-compose.yml`: orchestrates Postgres, Listmonk, n8n, Postfix, OpenDKIM, Scrapling API.
- `docker/listmonk/app.toml`: Listmonk runtime config.
- `docker/postfix/*`: Postfix image, templates, and OpenDKIM settings.
- `docker/opendkim/*`: OpenDKIM sidecar image and entrypoint.
- `docker/scrapling/Dockerfile`: Scrapling API image.
- `postgres/init/01-schema.sql`: core relational schema.
- `postgres/init/02-seed.sql`: seed data for MVP districts/ads.
- `n8n/workflows/*.json`: workflow automation set.
- `scripts/*.sh`: warmup, backup, restore, self-delete, postfix config generation.
- `templates/newsletter.html`: responsive email template.
- `docs/dns-setup.md`: DNS and PTR setup.
- `docs/DEPLOY.md`: runbook from zero to live.

## 2) Service Dependency Map
1. Cloudflare `spawn-server` cron creates Hetzner VM.
2. VM cloud-init starts Docker Engine and Compose stack.
3. `postgres` healthy -> `listmonk` and `n8n` boot.
4. `opendkim` boots -> `postfix` boots.
5. `scrapling-api` serves scrape/AI rewrite endpoint.
6. n8n main workflow drives content -> listmonk -> postfix send.
7. Cloudflare click worker handles clicks 24/7 independent of VM lifecycle.

## 3) n8n Workflow Set
- Main Pipeline Workflow
- Volume Monitor Workflow
- Auto-IP Purchase Workflow
- District Load Balancer Workflow
- D1 Click Sync Workflow
- Telegram Alert Workflow
- Backup and Delete Workflow (operational add-on)

## 4) Cloudflare Resources
- Workers: `namma-click-tracker`, `namma-spawn-server`, `namma-backup-delete-check`.
- D1: `namma-clicks`.
- R2 buckets: `namma-backups`, `namma-bootstrap`.
- Worker routes: `click.nammaoorunews.com/*`, `spawn.nammaoorunews.com/*`, `delete-check.nammaoorunews.com/*`.
- Cron triggers: spawn at 23:25 UTC (04:55 AM IST), backup delete-check at 03:30 UTC.

## 5) Environment Variable Master List
See `.env.example` for full inventory. Categories:
- Core/domain/tz
- PostgreSQL
- Listmonk
- n8n
- Hetzner
- Cloudflare (D1/R2/DNS)
- Telegram alerts
- Scrapling/NVIDIA
- Runtime district/IP maps
