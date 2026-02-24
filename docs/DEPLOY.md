# Deployment Guide (Zero to Live)

⚠️ WARNING: Complete Phase 0 and Phase 1 before sending any email. PTR or blacklist failures will kill delivery.

## Phase 0: IP Blacklist Check
1. Check current IP at https://mxtoolbox.com/blacklists.aspx.
2. Query `95.217.13.142`.
3. If listed:
   - Spamhaus: https://check.spamhaus.org/
   - Microsoft: https://sender.office.com/
4. Verification: save screenshot + timestamp in deployment notes.

## Phase 1: Hetzner PTR Fix (Mandatory)
1. Hetzner Cloud -> Primary IPs -> `95.217.13.142` -> Edit Reverse DNS.
2. Set PTR: `mail.nammaoorunews.com`.
3. Verify from terminal:
```bash
dig -x 95.217.13.142 +short
```
Expected:
```text
mail.nammaoorunews.com.
```

## Phase 2: Cloudflare Setup (D1, R2, Workers, DNS)
1. Create D1:
```bash
wrangler d1 create namma-clicks
wrangler d1 execute namma-clicks --file cloudflare/d1/schema.sql --remote
```
2. Create R2 buckets:
```bash
wrangler r2 bucket create namma-backups
wrangler r2 bucket create namma-bootstrap
```
3. Upload cloud-init bootstrap:
```bash
wrangler r2 object put namma-bootstrap/cloud-init/user-data.sh --file cloud-init/user-data.sh
```
4. Deploy workers:
```bash
cd cloudflare/workers/click-tracker && wrangler deploy
cd ../spawn-server && wrangler deploy
cd ../backup-delete-check && wrangler deploy
```
5. DNS records in Cloudflare:
   - `click` CNAME/route -> click-tracker worker route.
   - `spawn` CNAME/route -> spawn worker route.
   - `delete-check` CNAME/route -> backup-delete-check worker route.
6. Verification:
```bash
curl -i https://click.nammaoorunews.com/l/test-token
curl -i https://spawn.nammaoorunews.com/health
```

## Phase 3: GitHub/Runtime Secrets
Set all keys from `.env.example` in your secure secret manager. Required minimum:
- Hetzner: `HETZNER_API_TOKEN`, network/firewall/ssh IDs.
- Cloudflare: account/zone/token/D1 IDs and SPF record ID.
- R2: access key + secret key.
- Telegram bot + chat ID.
- NVIDIA API keys.
- n8n API key.

## Phase 4: First Manual Spawn + Full Cycle Test
1. Start local stack:
```bash
cp .env.example .env
docker compose --env-file .env up -d --build
```
2. Trigger spawn worker manually:
```bash
curl -X POST "https://spawn.nammaoorunews.com" \
  -H "Authorization: Bearer ${SPAWN_WORKER_TOKEN}"
```
3. Verify timeline:
   - VM created at Hetzner.
   - Cloud-init pulls repo + starts compose.
   - n8n receives `main-pipeline` webhook.
   - Listmonk campaign created in draft.
   - `campaign_metrics` row inserted.
4. Verification SQL:
```sql
SELECT district, campaign_id, created_at
FROM campaign_metrics
ORDER BY created_at DESC
LIMIT 10;
```

## Phase 5: Warmup Week 1 Checklist
1. Day 1: send to 50-100 recipients (single district).
2. Day 2-3: cap ~150-200.
3. Day 4-7: cap ~350-700.
4. Require:
   - bounce rate < 2%
   - open rate > 25%
5. Run warmup controller daily:
```bash
bash scripts/warmup_controller.sh
```
6. Track inbox reputation in Google Postmaster and pause growth if reputation drops.

## API Verification Calls
Use these direct checks during rollout:
```bash
# Hetzner API connectivity
curl -H "Authorization: Bearer ${HETZNER_API_TOKEN}" https://api.hetzner.cloud/v1/servers

# Cloudflare D1 query (read)
curl -X POST "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/d1/database/${CLOUDFLARE_D1_DATABASE_ID}/query" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"sql":"SELECT COUNT(*) AS click_events FROM click_events"}'
```

## Go-Live Gate
Do not go live until all are true:
- PTR is correct.
- Blacklist check is clean.
- D1 click tracker returns expected statuses.
- Backup to R2 verifies objects.
- Self-delete and backup delete-check both work.
