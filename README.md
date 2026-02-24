# Namma Ooru News

Production-ready infrastructure for an automated Tamil hyperlocal newsletter platform.

## Status
- Code implementation is complete for the planned phases (infra, workflows, click tracking, database, email stack, scrape API, warmup, docs).
- Remaining work is runtime execution: real secrets, cloud resource provisioning, and live verification.

See:
- `completionstatus.md`
- `executionsteps.md`
- `docs/DEPLOY.md`

## Stack
- Hetzner CX33 (ephemeral daily runtime)
- Cloudflare Workers + D1 + R2
- n8n workflows
- Listmonk
- PostgreSQL 16
- Postfix + OpenDKIM
- Scrapling FastAPI microservice
- Docker Compose

## Repository Layout
- `cloudflare/`: Workers and D1 schema
- `cloud-init/`: VM bootstrap script
- `docker/`: service images and templates
- `n8n/workflows/`: importable workflow JSON files
- `postgres/init/`: schema and seed SQL
- `scripts/`: backup/restore, warmup, postfix config, self-delete
- `templates/`: newsletter HTML template
- `docs/`: deployment and DNS runbooks

## Quick Start (Local)
1. Create env file:
```bash
cp .env.example .env
```
2. Fill all required values in `.env`.
3. Start stack:
```bash
docker compose --env-file .env up -d --build
```
4. Validate:
```bash
docker compose ps
docker compose logs --tail=80 postgres listmonk n8n postfix opendkim scrapling-api
```

## Static Validation Commands
```bash
bash -n scripts/*.sh docker/postfix/entrypoint.sh docker/opendkim/entrypoint.sh cloud-init/user-data.sh
for f in n8n/workflows/*.json; do jq empty "$f"; done
python3 -m py_compile scrapling-api/main.py scrapling-api/rewriter.py
```

## Critical Operational Notes
- Do not send email before PTR and blacklist checks are complete.
- Click tracking runs 24/7 via Cloudflare Worker (`click.nammaoorunews.com`), independent of VM uptime.
- Spawn worker cron is configured for `23:25 UTC` (04:55 AM IST target).

## Deployment
Use the full runbooks:
- `docs/DEPLOY.md` (high-level)
- `executionsteps.md` (detailed execution order)

