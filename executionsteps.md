# Namma Ooru News - Detailed Execution Steps

Date: 2026-02-25  
Scope: Production runbook aligned to PRD v21 (includes 24/7 subscription system).

## 1. Preflight (Operator Machine)

Run from repository root:

```bash
pwd
ls -la
```

Install required tools:
- Docker + Docker Compose plugin
- Node.js + `wrangler`
- `curl`
- optional: `jq`, `python3`, `bash`

Authenticate Cloudflare:

```bash
wrangler login
```

## 2. Deliverability Gate (Mandatory Before Send)

1. Check blacklist status for sending IP (`95.217.13.142`).
2. Fix listings if present (Spamhaus / Microsoft SNDS).
3. Verify PTR in Hetzner:

```bash
dig -x 95.217.13.142 +short
```

Expected:

```text
mail.nammaoorunews.com.
```

Do not send campaigns until this passes.

## 3. Phase A - Cloudflare D1 + R2 Provisioning

Create D1 and apply schema (now includes `pending_subscribers`):

```bash
wrangler d1 create namma-clicks
wrangler d1 execute namma-clicks --file cloudflare/d1/schema.sql --remote
```

Create required R2 buckets:

```bash
wrangler r2 bucket create namma-backups
wrangler r2 bucket create namma-bootstrap
```

Upload cloud-init bootstrap:

```bash
wrangler r2 object put namma-bootstrap/cloud-init/user-data.sh --file cloud-init/user-data.sh
```

## 4. Phase B - Deploy Cloudflare Workers

Deploy all workers:

```bash
(cd cloudflare/workers/click-tracker && wrangler deploy)
(cd cloudflare/workers/subscription-handler && wrangler deploy)
(cd cloudflare/workers/spawn-server && wrangler deploy)
(cd cloudflare/workers/backup-delete-check && wrangler deploy)
```

Configure routes in Cloudflare:
- `click.nammaoorunews.com/*` -> click-tracker
- `subscribe.nammaoorunews.com/*` -> subscription-handler
- `spawn.nammaoorunews.com/*` -> spawn-server
- `delete-check.nammaoorunews.com/*` -> backup-delete-check

Verification:

```bash
curl -i https://click.nammaoorunews.com/l/test-token
curl -i https://subscribe.nammaoorunews.com
curl -i https://spawn.nammaoorunews.com/health
```

Expected:
- click endpoint returns `410` for unknown token
- subscribe endpoint `GET` returns `405` (POST-only)
- spawn health returns `200`

## 5. Phase C - Deploy Cloudflare Pages Signup Form

Deploy static signup form from `cloudflare/pages/`:

```bash
wrangler pages project create nammaoorunews-pages --production-branch main
wrangler pages deploy cloudflare/pages --project-name nammaoorunews-pages
```

Map custom domain/path so `nammaoorunews.com/subscribe` serves `cloudflare/pages/subscribe/index.html`.

Browser verification:
1. Open `https://nammaoorunews.com/subscribe`
2. Submit sample data
3. Confirm successful response message
4. Confirm D1 row was inserted in `pending_subscribers`

D1 verification:

```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/d1/database/${CLOUDFLARE_D1_DATABASE_ID}/query" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"sql":"SELECT id,email,district,is_synced,signed_up_at FROM pending_subscribers ORDER BY id DESC LIMIT 5"}'
```

## 6. Phase D - Runtime Stack and Workflows

Bring up runtime services:

```bash
docker compose --env-file .env up -d --build
docker compose ps
docker compose logs --tail=100 postgres listmonk n8n postfix opendkim scrapling-api
```

Verify workflow import includes new file:

```bash
ls -1 n8n/workflows
```

Required workflow files include:
- `subscriber-sync.json` (new, 05:01)
- `d1-click-sync.json` (05:03)
- `main-pipeline.json`
- `volume-monitor.json`
- `auto-ip-purchase.json`
- `district-load-balancer.json`
- `backup-and-delete.json`
- `telegram-alerts.json`

If needed, import manually:

```bash
docker compose exec -T n8n sh -lc 'for f in /workflows/*.json; do n8n import:workflow --input "$f"; done'
```

## 7. Phase E - Subscriber Sync Verification (05:01 Path)

1. Insert a test subscriber through `https://nammaoorunews.com/subscribe`.
2. Trigger `subscriber-sync` manually from n8n UI (or wait for cron at 05:01).
3. Verify subscriber in Listmonk.
4. Verify D1 row marked synced:

```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/d1/database/${CLOUDFLARE_D1_DATABASE_ID}/query" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"sql":"SELECT id,email,district,is_synced FROM pending_subscribers ORDER BY id DESC LIMIT 10"}'
```

Expected:
- `is_synced = 1` for synced test row
- Telegram sync notification sent
- if Listmonk API fails, row should remain `is_synced = 0` for retry in next run

## 8. Phase F - Main Pipeline and Click Sync Verification

Trigger main pipeline:

```bash
curl -X POST "${N8N_WEBHOOK_URL}/webhook/main-pipeline" \
  -H "content-type: application/json" \
  -d '{"trigger":"manual-smoke"}'
```

Verify metrics:

```sql
SELECT district, campaign_id, created_at
FROM campaign_metrics
ORDER BY created_at DESC
LIMIT 10;
```

Verify click sync (after clicks exist):

```sql
SELECT district, ad_id, date, clicks, unique_clicks
FROM ad_performance
ORDER BY date DESC, clicks DESC
LIMIT 20;
```

## 9. Final Go-Live Gate

All must be true:
1. PTR fixed and blacklist clean
2. All four workers deployed and reachable
3. D1 schema applied with `pending_subscribers`
4. Cloudflare Pages `/subscribe` live
5. Test signup inserts pending row
6. `subscriber-sync` moves row to Listmonk and marks D1 synced
7. Main pipeline creates campaigns and metrics
8. Backup/delete automation verified

## 10. Validation Commands (Codebase Integrity)

Use what is available in your environment:

```bash
# Worker JS syntax
node --check cloudflare/workers/click-tracker/index.js
node --check cloudflare/workers/subscription-handler/index.js
node --check cloudflare/workers/spawn-server/index.js
node --check cloudflare/workers/backup-delete-check/index.js

# Workflow JSON (Linux/macOS)
jq empty n8n/workflows/*.json

# Workflow JSON (Windows PowerShell fallback)
powershell -Command "Get-ChildItem n8n/workflows/*.json | % { Get-Content -Raw $_ | ConvertFrom-Json > $null }; 'ok'"
```
