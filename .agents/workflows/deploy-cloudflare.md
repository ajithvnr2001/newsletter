---
description: Deploy all Cloudflare resources (D1, R2, Workers, Pages)
---

# Deploy Cloudflare

Deploy the complete Cloudflare infrastructure: D1 database, R2 buckets, 4 Workers, and Pages signup form.

## Prerequisites
- `wrangler` installed (`npm install -g wrangler@latest`)
- Authenticated: `wrangler login`
- Update each `wrangler.toml` with actual `database_id` after Step 1

## Steps

1. Create D1 database and apply schema:
```bash
wrangler d1 create namma-clicks
wrangler d1 execute namma-clicks --file cloudflare/d1/schema.sql --remote
```

2. Create R2 buckets:
```bash
wrangler r2 bucket create namma-backups
wrangler r2 bucket create namma-bootstrap
```

3. Upload cloud-init bootstrap to R2:
```bash
wrangler r2 object put namma-bootstrap/cloud-init/user-data.sh --file cloud-init/user-data.sh
```

// turbo
4. Deploy click-tracker worker:
```bash
cd cloudflare/workers/click-tracker && wrangler deploy && cd ../../..
```

// turbo
5. Deploy subscription-handler worker:
```bash
cd cloudflare/workers/subscription-handler && wrangler deploy && cd ../../..
```

// turbo
6. Deploy spawn-server worker:
```bash
cd cloudflare/workers/spawn-server && wrangler deploy && cd ../../..
```

// turbo
7. Deploy backup-delete-check worker:
```bash
cd cloudflare/workers/backup-delete-check && wrangler deploy && cd ../../..
```

8. Set secrets for spawn-server:
```bash
wrangler secret put HETZNER_API_TOKEN --name namma-spawn-server
wrangler secret put TELEGRAM_BOT_TOKEN --name namma-spawn-server
wrangler secret put TELEGRAM_CHAT_ID --name namma-spawn-server
wrangler secret put SPAWN_WORKER_TOKEN --name namma-spawn-server
wrangler secret put ACTIVE_IPS --name namma-spawn-server
wrangler secret put PRIMARY_IP_IDS --name namma-spawn-server
wrangler secret put PRIMARY_IP_NAME_PREFIX --name namma-spawn-server
```

9. Set secrets for backup-delete-check:
```bash
wrangler secret put HETZNER_API_TOKEN --name namma-backup-delete-check
wrangler secret put TELEGRAM_BOT_TOKEN --name namma-backup-delete-check
wrangler secret put TELEGRAM_CHAT_ID --name namma-backup-delete-check
wrangler secret put DELETE_WORKER_TOKEN --name namma-backup-delete-check
```

10. Deploy Pages signup form:
```bash
wrangler pages project create nammaoorunews-pages --production-branch main
wrangler pages deploy cloudflare/pages --project-name nammaoorunews-pages
```

11. Verify all endpoints:
// turbo
```bash
curl -i https://click.nammaoorunews.com/l/test-token
```
Expected: 410 (unknown token)

// turbo
```bash
curl -i https://subscribe.nammaoorunews.com
```
Expected: 405 (POST-only)

// turbo
```bash
curl -i https://spawn.nammaoorunews.com/health
```
Expected: 200
