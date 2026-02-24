# Namma Ooru News - Detailed Execution Steps

Date: 2026-02-24

This runbook is the exact execution order to take the repository from code-complete to live operation.

## 1. Preflight (Local Machine)

Run from repository root:

```bash
pwd
ls -la
```

Install required CLIs on your operator machine:

```bash
# Ubuntu/Debian example
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin jq curl postgresql-client rclone

# Node + Wrangler
sudo apt-get install -y nodejs npm
sudo npm install -g wrangler@latest
```

Authenticate Cloudflare:

```bash
wrangler login
```

## 2. Phase 0 - Deliverability Blockers (Must Do First)

1. Check blacklist:
   - Open `https://mxtoolbox.com/blacklists.aspx`
   - Check `95.217.13.142`
2. If listed, delist before continuing:
   - Spamhaus: `https://check.spamhaus.org/`
   - Microsoft: `https://sender.office.com/`

Gate: continue only after clean/delisting confirmation.

## 3. Phase 1 - PTR Fix at Hetzner

1. Hetzner Cloud -> Primary IPs -> `95.217.13.142` -> Edit Reverse DNS
2. Set `mail.nammaoorunews.com`
3. Verify:

```bash
dig -x 95.217.13.142 +short
```

Expected:

```text
mail.nammaoorunews.com.
```

## 4. Phase 2 - Repository Configuration

Create runtime env file:

```bash
cp .env.example .env
```

Edit `.env` and set all real values:
- Hetzner tokens/IDs
- Cloudflare account/zone/token and D1 ID
- R2 keys and endpoint
- Telegram bot/chat
- NVIDIA API keys
- n8n credentials

Sanity check env values:

```bash
rg -n 'replace-me|change-me|your-org|<accountid>' .env
```

Expected: no matches.

## 5. Phase 3 - Cloudflare Resources

Create D1 and apply schema:

```bash
wrangler d1 create namma-clicks
wrangler d1 execute namma-clicks --file cloudflare/d1/schema.sql --remote
```

Create R2 buckets:

```bash
wrangler r2 bucket create namma-backups
wrangler r2 bucket create namma-bootstrap
```

Upload bootstrap script:

```bash
wrangler r2 object put namma-bootstrap/cloud-init/user-data.sh --file cloud-init/user-data.sh
```

Deploy Workers:

```bash
(cd cloudflare/workers/click-tracker && wrangler deploy)
(cd cloudflare/workers/spawn-server && wrangler deploy)
(cd cloudflare/workers/backup-delete-check && wrangler deploy)
```

Verification:

```bash
curl -i https://click.nammaoorunews.com/l/test-token
curl -i https://spawn.nammaoorunews.com/health
```

Expected:
- Click test returns `410` for unknown token (valid behavior)
- Spawn health returns `200`

## 6. Phase 4 - Local Stack Validation

Bring up stack locally:

```bash
docker compose --env-file .env up -d --build
```

Check service status:

```bash
docker compose ps
docker compose logs --tail=80 postgres listmonk n8n postfix opendkim scrapling-api
```

Check DB schema loaded:

```bash
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt"
```

## 7. Phase 5 - n8n Workflow Import Verification

Confirm workflow files exist:

```bash
ls -1 n8n/workflows
```

Expected files:
- `main-pipeline.json`
- `volume-monitor.json`
- `auto-ip-purchase.json`
- `district-load-balancer.json`
- `d1-click-sync.json`
- `backup-and-delete.json`
- `telegram-alerts.json`

If needed, import manually:

```bash
docker compose exec -T n8n sh -lc 'for f in /workflows/*.json; do n8n import:workflow --input "$f"; done'
```

## 8. Phase 6 - Database and API Spot Checks

Check seeded data:

```bash
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT district, list_name FROM district_lists ORDER BY district;"
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT district, position, advertiser_name FROM ads ORDER BY district, position;"
```

Check Scrapling API health:

```bash
curl -sS http://localhost:8000/health
```

Expected: `{\"ok\":true}`

## 9. Phase 7 - Manual End-to-End Trigger

Trigger main pipeline webhook:

```bash
curl -X POST "${N8N_WEBHOOK_URL}/webhook/main-pipeline" \
  -H "content-type: application/json" \
  -d '{"trigger":"manual-smoke"}'
```

Confirm campaign metrics insert:

```bash
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT district,campaign_id,created_at FROM campaign_metrics ORDER BY created_at DESC LIMIT 10;"
```

## 10. Phase 8 - Backup and Restore Validation

Run backup:

```bash
bash scripts/backup_to_r2.sh
```

Verify object upload:

```bash
rclone lsf "r2:${CLOUDFLARE_R2_BUCKET}/daily/$(date +%F)"
```

Run restore dry check:

```bash
bash scripts/restore_from_r2.sh
```

## 11. Phase 9 - Warmup Execution

Run warmup controller:

```bash
bash scripts/warmup_controller.sh
```

Check warmup state:

```bash
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM warmup_state WHERE id=1;"
```

## 12. Phase 10 - Production Automation Verification

Manual spawn worker trigger:

```bash
curl -X POST "https://spawn.nammaoorunews.com" \
  -H "Authorization: Bearer ${SPAWN_WORKER_TOKEN}"
```

Verify Hetzner server exists:

```bash
curl -H "Authorization: Bearer ${HETZNER_API_TOKEN}" https://api.hetzner.cloud/v1/servers | jq '.servers | length'
```

Verify fallback delete worker:

```bash
curl -X POST "https://delete-check.nammaoorunews.com/force-delete" \
  -H "Authorization: Bearer ${SELF_DELETE_WORKER_TOKEN}"
```

## 13. Final Go-Live Gate

All must be true:
1. PTR resolves correctly.
2. IP blacklist clean.
3. Workers deployed and reachable.
4. D1 schema applied and writable.
5. Local stack healthy.
6. n8n workflows imported.
7. Pipeline run inserts campaign metrics.
8. R2 backup verified.
9. Warmup state updates correctly.
10. Spawn/delete automation works.

## 14. Quick Re-Validation Commands

```bash
bash -n scripts/*.sh cloud-init/user-data.sh docker/postfix/entrypoint.sh docker/opendkim/entrypoint.sh docker/listmonk/start.sh
for f in n8n/workflows/*.json; do jq empty "$f"; done
python3 -m py_compile scrapling-api/main.py scrapling-api/rewriter.py
```
