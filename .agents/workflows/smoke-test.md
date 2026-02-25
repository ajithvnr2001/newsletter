---
description: End-to-end smoke test of the full newsletter system
---

# Smoke Test

Run a full end-to-end verification of the newsletter pipeline.

## Prerequisites
- Docker stack running (`/docker-stack` workflow)
- Cloudflare resources deployed (`/deploy-cloudflare` workflow)
- All workers reachable

## Steps

1. Test signup form (submit a test subscriber):
```bash
curl -X POST https://subscribe.nammaoorunews.com \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","district":"virudhunagar","name":"Test User"}'
```
Expected: `{"success":true,"message":"Welcome to Namma Ooru News..."}`

2. Verify D1 pending subscriber row:
```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/d1/database/${CLOUDFLARE_D1_DATABASE_ID}/query" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"sql":"SELECT id,email,district,is_synced,signed_up_at FROM pending_subscribers ORDER BY id DESC LIMIT 5"}'
```

3. Trigger subscriber-sync manually in n8n UI (or wait for 05:01 cron).

4. Verify subscriber in Listmonk:
```bash
curl -u "${LISTMONK_ADMIN_USER}:${LISTMONK_ADMIN_PASSWORD}" \
  http://localhost:9000/api/subscribers?query=test@example.com
```

5. Verify D1 row marked synced:
```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/d1/database/${CLOUDFLARE_D1_DATABASE_ID}/query" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"sql":"SELECT id,email,district,is_synced FROM pending_subscribers ORDER BY id DESC LIMIT 10"}'
```
Expected: `is_synced = 1` for the test row.

6. Trigger main pipeline:
```bash
curl -X POST "${N8N_WEBHOOK_URL}/webhook/main-pipeline" \
  -H "content-type: application/json" \
  -d '{"trigger":"manual-smoke"}'
```

7. Verify campaign metrics:
```bash
docker compose exec postgres psql -U listmonk -d listmonk -c \
  "SELECT district, campaign_id, created_at FROM campaign_metrics ORDER BY created_at DESC LIMIT 10;"
```

8. Test click tracking:
```bash
curl -i https://click.nammaoorunews.com/l/test-token
```
Expected: 410 for unknown token (or 302 redirect if using a real token).

9. Verify Scrapling API:
```bash
curl -X POST http://localhost:8000/scrape \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","district":"chennai"}'
```
