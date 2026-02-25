# Namma Ooru News

Production-oriented infrastructure for an automated Tamil hyperlocal newsletter platform.

This repository includes:
- Daily ephemeral compute orchestration on Hetzner.
- Newsletter data + ad-performance storage in PostgreSQL.
- 24/7 click tracking in Cloudflare D1 via Worker redirect service.
- n8n orchestration for scraping, rewriting, newsletter rendering, campaign dispatch, scaling, and backup.
- Postfix + OpenDKIM mail transport configuration.
- Backup and restore flows with Cloudflare R2.

## Current Status

Implementation state:
- Code artifacts are implemented for planned phases (infra, workers, workflows, DB schema, microservice, template, automation scripts, docs).
- Recent review fixes are applied and pushed (campaign attribution sync, dedup usage, backup script cwd hardening, primary IP resolution improvements).

Execution state:
- Live rollout is still environment-dependent and pending operator execution in production:
  - Real secrets.
  - Cloudflare resources and DNS.
  - Hetzner resource IDs.
  - Runtime verification in the target environment.

References:
- `completionstatus.md`
- `review&validations.md`
- `executionsteps.md`
- `docs/DEPLOY.md`

## Architecture Overview

Daily flow (high level):
1. Cloudflare `spawn-server` Worker cron triggers once daily at `23:25 UTC` (`04:55 AM IST`).
2. Worker creates a Hetzner VM and attaches configured primary IPs.
3. VM cloud-init script pulls this repo, starts Docker Compose stack, restores backups (if available), imports workflows, and triggers main n8n pipeline.
4. n8n runs content and campaign pipeline per district:
   - fetch RSS
   - deduplicate links
   - scrape and rewrite
   - persist article data
   - render email HTML
   - create/start Listmonk campaign
   - write campaign metrics
5. Clicks go to a Cloudflare Worker endpoint 24/7 and are written to D1.
6. D1 sync workflow moves click aggregates into PostgreSQL ad-performance tables.
7. Backup workflow uploads DB and workflow backups to R2.
8. Self-delete removes the ephemeral VM at the scheduled time.

Always-on components:
- Cloudflare Workers and D1 remain online even when VM is deleted.

## Core Stack

- Compute: Hetzner Cloud (`cx33` default).
- Edge and serverless: Cloudflare Workers.
- Click event store: Cloudflare D1.
- Backup/object store: Cloudflare R2.
- Workflow orchestration: n8n.
- Campaign management: Listmonk.
- Relational data store: PostgreSQL 16.
- SMTP layer: Postfix + OpenDKIM.
- Content pipeline service: FastAPI Scrapling microservice.
- Runtime composition: Docker Compose.

## Repository Layout

- `cloudflare/`
  - `d1/schema.sql`: D1 click-tracking schema.
  - `workers/click-tracker`: click redirect + event capture.
  - `workers/spawn-server`: daily VM create/attach IP worker.
  - `workers/backup-delete-check`: fallback deletion safety worker.
- `cloud-init/`
  - `user-data.sh`: VM bootstrap script executed on spawn.
- `docker/`
  - service Dockerfiles and runtime config/templates for Postfix/OpenDKIM/Listmonk/Scrapling.
- `n8n/workflows/`
  - importable workflow JSON exports.
- `postgres/init/`
  - `01-schema.sql`: primary PostgreSQL schema.
  - `02-seed.sql`: seed rows for districts and ads baseline.
- `scripts/`
  - operational shell scripts for warmup, backup, restore, postfix config generation, self-delete, workflow import.
- `templates/`
  - base newsletter HTML template.
- `docs/`
  - deployment and DNS operational runbooks.

## Services in Docker Compose

Defined in `docker-compose.yml`:
- `postgres`
  - PostgreSQL 16, persistent volume, schema/init mount.
- `listmonk`
  - depends on Postgres health.
- `n8n`
  - depends on Postgres health.
  - imports workflows at container startup.
- `opendkim`
  - DKIM key/signing service for Postfix.
- `postfix`
  - SMTP transport with dynamic sender/IP map support.
- `scrapling-api`
  - article scrape + rewrite + image upload service.

## Cloudflare Workers and Routes

- Click Tracker Worker
  - Route: `click.nammaoorunews.com/*`
  - Responsibility: `GET /l/{token}` redirect + async click event write to D1.
- Spawn Server Worker
  - Route: `spawn.nammaoorunews.com/*`
  - Cron: `25 23 * * *`
  - Responsibility: create VM, attach primary IPs, send Telegram result.
- Backup Delete Check Worker
  - Route: `delete-check.nammaoorunews.com/*`
  - Cron: `30 3 * * *`
  - Responsibility: safety cleanup of leftover ephemeral servers.

## Data Model Summary

PostgreSQL (`postgres/init/01-schema.sql`):
- `articles`
  - rewritten article content by district.
- `ads`
  - active ad inventory with district and position targeting.
- `ad_performance`
  - impressions/clicks/unique clicks and derived CTR.
- `subscribers`
  - subscriber state and district mapping (scaling signal source).
- `campaign_metrics`
  - send metrics by campaign and district.
- `ip_scaling_history`
  - audit of IP auto-scaling decisions.
- `warmup_state`
  - warmup phase and send-volume control state.

Cloudflare D1 (`cloudflare/d1/schema.sql`):
- `click_links`
  - token -> destination/campaign/ad metadata map.
- `click_events`
  - click activity rows, sync status flag for transfer to Postgres metrics.

## n8n Workflows (Purpose and Trigger)

- `main-pipeline.json`
  - Trigger: webhook.
  - Handles district queue, article generation, token creation, D1 token insert, campaign create/start, D1 campaign backfill, campaign metric log.
- `volume-monitor.json`
  - Trigger: cron (`07:48`).
  - Uses subscriber count and active IP count to decide if scaling is needed.
- `auto-ip-purchase.json`
  - Trigger: workflow call.
  - Creates/attaches primary IP path, updates PTR/SPF/DKIM, updates n8n variables, logs scaling history, and rebalances districts.
- `district-load-balancer.json`
  - Trigger: workflow call.
  - Distributes districts across active IPs using subscriber-weighted logic and updates `DISTRICT_IP_MAP`.
- `d1-click-sync.json`
  - Trigger: cron (`05:03`).
  - Reads unsynced D1 clicks, upserts Postgres `ad_performance`, marks D1 events synced, removes old synced events.
- `backup-and-delete.json`
  - Trigger: cron.
  - Executes backup then self-delete sequence with failure alerts.
- `telegram-alerts.json`
  - Trigger: workflow call.
  - Simple message formatting and Telegram send.

## Scripts (Operational)

- `scripts/backup_to_r2.sh`
  - Dumps PostgreSQL, exports workflows, copies backups to R2, verifies uploaded objects exist.
- `scripts/restore_from_r2.sh`
  - Pulls most recent backup from R2 and restores SQL dump.
- `scripts/warmup_controller.sh`
  - Computes open/bounce rates and adjusts warmup phase + daily max sends.
- `scripts/generate_postfix_config.sh`
  - Builds Postfix transport maps from `DISTRICT_IP_MAP` (prefers n8n Variables API, falls back to env map).
- `scripts/self_delete.sh`
  - Reads Hetzner metadata instance id and deletes current server, with Telegram notification and optional fallback worker trigger.
- `scripts/import_n8n_workflows.sh`
  - Imports all JSON workflows into n8n on container start.

## Prerequisites

Operator machine:
- Docker + Docker Compose plugin.
- `curl`, `jq`, `psql` client, `rclone`.
- `node` + `wrangler` for Cloudflare provisioning.

Cloud prerequisites:
- Hetzner project with API token, network/firewall/SSH resources.
- Cloudflare account with Worker, D1, R2 access.
- Domain DNS control and mail record management.

## Configuration

Copy env template:

```bash
cp .env.example .env
```

Populate all required values before runtime.

### Key Environment Groups

Core/domain:
- `TZ`
- `DOMAIN`
- `MAIL_HOSTNAME`
- `CLICK_DOMAIN`
- `CDN_DOMAIN`

PostgreSQL and Listmonk:
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `LISTMONK_ADMIN_USER`
- `LISTMONK_ADMIN_PASSWORD`
- `LISTMONK_API_USER`
- `LISTMONK_API_TOKEN`
- `LISTMONK_FROM_EMAIL`

n8n:
- `N8N_HOST`
- `N8N_PROTOCOL`
- `N8N_WEBHOOK_URL`
- `N8N_API_URL`
- `N8N_API_KEY`
- `N8N_ENCRYPTION_KEY`

Hetzner:
- `HETZNER_API_TOKEN`
- `HETZNER_SSH_KEY_IDS`
- `HETZNER_FIREWALL_ID`
- `HETZNER_NETWORK_ID`
- `HETZNER_SERVER_TYPE`
- `HETZNER_LOCATION`
- `HETZNER_IMAGE`
- `ACTIVE_IPS`
- `PRIMARY_IP_IDS`

Cloudflare:
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_D1_DATABASE_ID`
- `CLOUDFLARE_D1_DATABASE_NAME`
- `CLOUDFLARE_SPF_RECORD_ID`
- `CLOUDFLARE_R2_BUCKET`
- `CLOUDFLARE_R2_ENDPOINT`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`

AI + scraping:
- `NVIDIA_API_KEYS`
- `NVIDIA_MODEL`
- `SCRAPLING_CONCURRENCY`
- `SCRAPLING_TIMEOUT_SECONDS`
- `SCRAPLING_IMAGE_MAX_WIDTH`
- `SCRAPLING_API_URL`
- `R2_PUBLIC_BASE_URL`

Routing/runtime state:
- `ACTIVE_DISTRICTS`
- `DISTRICT_IP_MAP` (fallback map; runtime source of truth is n8n Variables API)

Operational:
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `SELF_DELETE_WORKER_URL`
- `SELF_DELETE_WORKER_TOKEN`
- `SPAWN_WORKER_TOKEN`

## Local Bring-Up

Start stack:

```bash
docker compose --env-file .env up -d --build
```

Check health:

```bash
docker compose ps
docker compose logs --tail=80 postgres listmonk n8n postfix opendkim scrapling-api
curl -fsS http://localhost:8000/health
```

Manual main pipeline trigger:

```bash
curl -X POST "${N8N_WEBHOOK_URL}/webhook/main-pipeline" \
  -H "content-type: application/json" \
  -d '{"trigger":"manual-smoke"}'
```

## Deployment

Primary runbooks:
- `docs/DEPLOY.md` (high-level phase checklist)
- `executionsteps.md` (detailed command sequence)

Critical gate before mail send:
- PTR for primary send IP must resolve correctly.
- Blacklist status must be clean.

PTR verify example:

```bash
dig -x 95.217.13.142 +short
```

Expected:

```text
mail.nammaoorunews.com.
```

## Validation Commands

Workflow JSON:

```bash
jq empty n8n/workflows/*.json
```

Shell syntax:

```bash
bash -n scripts/*.sh cloud-init/user-data.sh docker/postfix/entrypoint.sh docker/opendkim/entrypoint.sh docker/listmonk/start.sh
```

Python syntax:

```bash
python3 -m py_compile scrapling-api/main.py scrapling-api/rewriter.py
```

Worker JavaScript syntax:

```bash
node --check cloudflare/workers/click-tracker/index.js
node --check cloudflare/workers/spawn-server/index.js
node --check cloudflare/workers/backup-delete-check/index.js
```

Compose config (when Docker CLI available):

```bash
docker compose --env-file .env config
```

## Operational Checks

Recent campaigns:

```sql
SELECT district, campaign_id, created_at
FROM campaign_metrics
ORDER BY created_at DESC
LIMIT 10;
```

Recent ad-performance:

```sql
SELECT district, ad_id, date, clicks, unique_clicks, ctr
FROM ad_performance
ORDER BY date DESC, clicks DESC
LIMIT 20;
```

Warmup state:

```sql
SELECT *
FROM warmup_state
WHERE id = 1;
```

## Troubleshooting

`click` links return `410`:
- Token may be missing/expired in D1.
- Verify `click_links` insert and campaign-id backfill path in main pipeline.

No campaign metrics inserted:
- Verify main workflow reaches `Start Campaign`, `Resolve Sending IP`, and `Log Campaign Metrics`.
- Confirm Postgres connection credentials in n8n.

No scraping output:
- Check `scrapling-api` logs.
- Verify `NVIDIA_API_KEYS` and network egress.

Postfix routing not updated:
- Check `scripts/generate_postfix_config.sh` output.
- Confirm `DISTRICT_IP_MAP` exists in n8n Variables API or fallback env JSON.

Backup upload failures:
- Verify R2 credentials and endpoint.
- Confirm `rclone` config exists in runtime environment.

Self-delete not running:
- Verify Hetzner metadata endpoint access.
- Check fallback `delete-check` worker auth token and route.

## Security and Safety Notes

- Do not commit secrets, tokens, private keys, or `.env`.
- Keep `.env.example` placeholder-only.
- Treat DNS/SPF/DKIM/DMARC/PTR changes as high-risk and verify before send.
- Enforce least-privilege API tokens for Cloudflare and Hetzner.

## Related Docs

- `completionstatus.md`
- `review&validations.md`
- `executionsteps.md`
- `docs/DEPLOY.md`
- `docs/dns-setup.md`
- `docs/PHASE1_PLAN.md`
