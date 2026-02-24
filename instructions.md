# 🚀 BUILD: Namma Ooru News — Tamil Hyperlocal AI Newsletter System

## YOUR ROLE
You are a senior full-stack DevOps engineer. Your task is to fully plan,
scaffold, and implement the Namma Ooru News infrastructure as defined in the
attached PRD. You will write complete, production-ready code — not stubs, not
placeholders, not TODOs. Every file must be deployable as-is.

---

## MCP TOOL USAGE (MANDATORY)

Before writing ANY code for a library, framework, or API, you MUST:

1. **Use Context7 MCP** to fetch up-to-date official documentation for:
   - n8n workflow JSON schema and HTTP node syntax
   - Listmonk REST API (v2) — campaign creation, subscriber management
   - Cloudflare Workers + D1 + R2 + Wrangler CLI syntax
   - PostgreSQL 16 SQL syntax (GENERATED ALWAYS AS, INET type)
   - Docker Compose v3.9+ syntax
   - Postfix main.cf and transport map syntax
   - OpenDKIM configuration
   - Hetzner Cloud API v1 (servers, primary_ips, actions)
   - Scrapling Python library (latest version)

2. **Use Exa MCP** to search for:
   - Real-world examples of Listmonk + Postfix multi-IP routing
   - n8n workflow examples for Hetzner API automation
   - Cloudflare D1 Workers real-world click tracking implementations
   - Postfix transport_maps per-sender IP routing examples
   - cloud-init Docker Compose bootstrap scripts for Hetzner CX33
   - PostgreSQL R2 backup with rclone to Cloudflare R2 examples

Always cite the doc/source you used before each code block.

---

## PROJECT OVERVIEW

**Project:** Namma Ooru News
**Goal:** Fully automated Tamil hyperlocal AI newsletter
**Stack:**
- Hetzner CX33 (ephemeral, 3hrs/day: 05:00–08:00 AM IST)
- Cloudflare (Workers, D1, R2, DNS, Email Routing)
- n8n (pipeline orchestration)
- Listmonk (campaign management)
- PostgreSQL 16 (data store)
- Postfix + OpenDKIM (SMTP delivery)
- Scrapling (Python AI content scraper microservice)
- Docker Compose (all services containerized)

**Constraints:**
- Cost: ₹135/month Day 1, scales to ₹605/month at 38 districts
- Zero manual intervention after setup
- Self-deletes server at 08:00 AM daily
- Click tracking must work 24/7 via Cloudflare (not VM)

---

## PHASE 1 — PLAN FIRST (Do not write code yet)

Before writing any code, produce a complete implementation plan:

1. **Directory & File Tree** — List every file you will create with its exact
   path and one-line purpose description. Minimum 40 files expected.

2. **Service Dependency Map** — Show which services depend on which
   (boot order, health checks).

3. **n8n Workflow List** — Name all 6 workflows you will build:
   - Main Pipeline Workflow
   - Volume Monitor Workflow
   - Auto-IP Purchase Workflow
   - District Load Balancer Workflow
   - D1 Click Sync Workflow
   - Telegram Alert Workflow

4. **Cloudflare Resource List** — All Workers, D1 databases, R2 buckets,
   DNS records, cron triggers.

5. **Environment Variables Master List** — Every secret/env var needed
   across all services.

Ask me to confirm the plan before proceeding to Phase 2.

---

## PHASE 2 — INFRASTRUCTURE (Write after plan confirmed)

### 2A. Docker Compose Stack
Write `docker-compose.yml` for:
- `postgres:16-alpine` with volume mount, healthcheck, init SQL
- `listmonk` (official image, latest) — config via app.toml
- `n8n` (official image) — with workflows auto-import on boot
- `postfix` (custom Dockerfile) — with OpenDKIM sidecar
- `scrapling-api` (custom Python FastAPI Dockerfile)

Use Context7 MCP to get exact Listmonk app.toml schema before writing it.

### 2B. Cloud-Init Bootstrap Script
Write `cloud-init/user-data.sh`:
- Installs Docker, Docker Compose, rclone, wrangler
- Clones GitHub repo
- Restores PostgreSQL from Cloudflare R2 (rclone copy)
- Imports n8n workflows from R2
- Starts Docker Compose stack
- Runs `generate_postfix_config.sh`
- Triggers n8n main pipeline webhook
- Schedules self-delete cron at 08:00 AM IST

### 2C. Cloudflare Worker Spawner
Write `cloudflare/workers/spawn-server/index.js`:
- Cron trigger: `0 23 * * *` (04:55 AM IST = 23:25 UTC previous day)
- Calls Hetzner API to create CX33
- Attaches all IPs from `ACTIVE_IPS` secret
- Injects cloud-init script from R2
- Sends Telegram alert on success/failure

Use Exa MCP to find real Hetzner API server creation + IP attachment examples.

### 2D. Self-Delete Script
Write `scripts/self_delete.sh`:
- Gets own server ID from Hetzner metadata API
- Calls `DELETE /v1/servers/{id}` via Hetzner API
- Sends Telegram alert
- Includes fallback: Cloudflare Worker backup delete check at 09:00 AM

---

## PHASE 3 — CLICK TRACKING SYSTEM (24/7 Cloudflare)

### 3A. D1 Schema
Write `cloudflare/d1/schema.sql` with exact tables:
- `click_links` (token, campaign_id, ad_id, district, destination_url, created_at)
- `click_events` (id, token, subscriber_id, clicked_at, user_agent, ip_address, is_synced)
- All indexes as specified in PRD Section 5.2.1

### 3B. Click Tracker Worker
Write `cloudflare/workers/click-tracker/index.js`:
- Handles GET `/l/{token}?sid={subscriber_id}`
- Looks up token in D1 click_links
- Logs click to D1 click_events (non-blocking with ctx.waitUntil)
- Redirects to destination_url (302)
- Returns 410 for expired/unknown tokens
- Handles 24/7 — VM being offline is irrelevant

Use Context7 MCP to get latest Cloudflare D1 + Workers API docs before writing.

### 3C. Wrangler Config
Write `cloudflare/workers/click-tracker/wrangler.toml`:
- Route: `click.nammaoorunews.com/*`
- D1 binding: `DB`
- Compatibility date: latest

### 3D. D1 Sync n8n Workflow
Write `n8n/workflows/d1-click-sync.json`:
- Runs at 05:03 AM during boot
- HTTP GET Cloudflare D1 REST API: pull unsynced click_events
- INSERT into PostgreSQL ad_performance table
- UPDATE D1 is_synced = 1 for processed records
- DELETE D1 events older than 30 days

---

## PHASE 4 — DATABASE

### 4A. PostgreSQL Init SQL
Write `postgres/init/01-schema.sql` with ALL tables from PRD Section 4.1:
- `articles` (with CHECK constraint for 5 MVP districts)
- `ads` (with district + position CHECK constraints)
- `ad_performance` (with CTR GENERATED ALWAYS AS column)
- `campaign_metrics`
- `ip_scaling_history`
- ALL indexes as specified

### 4B. Seed Data
Write `postgres/init/02-seed.sql`:
- 5 district Listmonk lists (Chennai, Coimbatore, Madurai, Trichy, Virudhunagar)
- Sample ad for Virudhunagar (VND Silk Sarees, Tamil HTML)
- 1 placeholder ad for "all" districts

---

## PHASE 5 — EMAIL INFRASTRUCTURE

### 5A. Postfix Dynamic Config Generator
Write `scripts/generate_postfix_config.sh`:
- Fetches DISTRICT_IP_MAP from n8n variables API
- Dynamically generates `/etc/postfix/transport` with per-district IP routing
- Generates `/etc/postfix/sender_dependent_default_transport_maps`
- Calls `postmap` and `postfix reload`
- Example routing:
  ```
  sender:chennai@nammaoorunews.com  smtp:[95.217.13.142]:25
  sender:virudhunagar@nammaoorunews.com  smtp:[95.217.13.200]:25
  ```

Use Exa MCP to find Postfix sender_dependent_default_transport_maps examples.

### 5B. Postfix Dockerfile
Write `docker/postfix/Dockerfile`:
- Based on debian:bookworm-slim
- Installs postfix, opendkim, opendkim-tools
- Copies main.cf, master.cf, opendkim.conf templates
- Entrypoint dynamically replaces HOSTNAME, DOMAIN env vars

### 5C. OpenDKIM Config
Write `docker/postfix/opendkim.conf`:
- Multi-key support (mail1–mail10 selectors)
- KeyTable pointing to /etc/opendkim/keys/

### 5D. DNS Records Reference
Write `docs/dns-setup.md` with all Cloudflare DNS records:
- SPF TXT record (Day 1 format + auto-scaled format)
- DKIM TXT records (mail._domainkey format)
- DMARC TXT records (3 phases: none → quarantine → reject)
- MX records
- PTR record setup steps in Hetzner console

---

## PHASE 6 — SCRAPLING MICROSERVICE

### 6A. FastAPI Service
Write `scrapling-api/main.py`:
- POST `/scrape` — takes `{url, district}`, returns
  `{title, body_text, image_url, publisher}`
- Uses Scrapling (use Context7 MCP for latest Scrapling API)
- Downloads article image, resizes to max 800px wide
- Uploads to Cloudflare R2 via boto3 S3-compatible API
- Returns CDN URL: `https://cdn.nammaoorunews.com/{uuid}.jpg`
- Rate limiting: max 5 concurrent scrapes

### 6B. NVIDIA AI Rewriter
Write `scrapling-api/rewriter.py`:
- Round-robin between NVIDIA API keys (from env NVIDIA_API_KEYS CSV)
- POST to `https://integrate.api.nvidia.com/v1/chat/completions`
- System prompt: Tamil hyperlocal news rewriter
- Rewrites article in Tamil, returns `{ai_title, ai_summary}`
- ai_summary: max 150 Tamil words
- ai_title: max 10 Tamil words, engaging, no clickbait

### 6C. Scrapling Dockerfile
Write `docker/scrapling/Dockerfile`:
- Python 3.11-slim base
- Installs scrapling, fastapi, uvicorn, boto3, pillow, httpx
- Playwright browser install (for JS-heavy sites)

---

## PHASE 7 — n8n WORKFLOWS

Write ALL 6 workflows as importable JSON files in `n8n/workflows/`:

### 7A. `main-pipeline.json`
Full district pipeline:
1. Trigger (webhook from cloud-init)
2. For-each district loop (Chennai, Coimbatore, Madurai, Trichy, Virudhunagar)
3. Google News RSS fetch (Tamil + district name query)
4. LLM deduplication (call NVIDIA API to deduplicate headlines)
5. For-each article: POST to scrapling-api `/scrape`
6. INSERT article to PostgreSQL
7. Query active ads for district
8. Generate link tokens for all URLs (INSERT to D1 click_links)
9. Build HTML newsletter template (inline styles, Tamil fonts)
10. Listmonk API: POST /api/campaigns (status=draft)
11. Wait for scheduled time, PATCH campaign to status=running
12. Log to campaign_metrics

### 7B. `volume-monitor.json`
- Runs at 07:48 AM
- SQL: `SELECT SUM(sent_count) FROM campaign_metrics WHERE created_at::date = CURRENT_DATE`
- Calculate IPs needed: `CEIL(total / 2000)`
- If more IPs needed: trigger auto-ip-purchase workflow
- Send Telegram summary

### 7C. `auto-ip-purchase.json`
- POST Hetzner API `/v1/primary_ips`
- Set PTR via `/v1/primary_ips/{id}/actions/change_dns_ptr`
- Update Cloudflare SPF TXT record via CF API
- Add new DKIM TXT record (from pre-generated DKIM_PUBLIC_IP{n} n8n variable)
- Update n8n `ACTIVE_IPS` variable
- INSERT to `ip_scaling_history` table
- Send Telegram alert with new IP + cost

### 7D. `district-load-balancer.json`
- Query subscriber counts per district
- Greedy bin-packing: assign districts to IPs (heaviest first → IP with lowest load)
- Update n8n `DISTRICT_IP_MAP` variable as JSON
- Trigger `generate_postfix_config.sh` via SSH node

### 7E. `backup-and-delete.json`
- 07:50 AM: pg_dump → gzip → rclone copy to R2
- Export n8n workflows → R2
- Export campaign_metrics CSV → R2
- Verify R2 upload (HEAD request)
- If failed: Telegram alert, ABORT delete
- If success: DELETE articles > 30 days
- 08:00 AM: Run self_delete.sh

### 7F. `telegram-alerts.json`
- Sub-workflow called by all other workflows
- Formats message with emoji, district, counts
- POST to Telegram Bot API

Use Context7 MCP to get n8n workflow JSON schema for HTTP Request node,
PostgreSQL node, Code node before writing all workflows.

---

## PHASE 8 — NEWSLETTER HTML TEMPLATE

Write `templates/newsletter.html`:
- Responsive email HTML (max-width 600px, inline CSS)
- Tamil Google Font (Noto Sans Tamil)
- Header: district name in Tamil + English, date
- {{ARTICLES_BLOCK}} — injected article cards (image, title, summary, source link)
- {{MID_AD}} — mid-banner ad injection point
- {{FOOTER_AD}} — footer ad injection point
- Article card: 80px thumbnail (R2 CDN), Tamil ai_title, ai_summary (2-3 lines)
- ALL links replaced with: `https://click.nammaoorunews.com/l/{token}?sid={{subscriber_id}}`
- Unsubscribe footer: Listmonk `{{unsubscribe_url}}`
- Dark orange accent color (#f97316) — matches Virudhunagar identity

---

## PHASE 9 — IP WARMUP AUTOMATION

Write `scripts/warmup_controller.sh`:
- Reads current warmup phase from PostgreSQL `warmup_state` table
- Calculates today's max send limit per warmup schedule:
  Days 1-2: 150, Days 3-4: 350, Days 5-7: 700,
  Days 8-10: 1100, Days 11-14: 1750, Weeks 3-4: 2500
- Passes max_sends to n8n pipeline via webhook parameter
- Listmonk campaign is rate-limited via this max_sends value
- Auto-progresses warmup phase if bounce_rate < 2% AND open_rate > 25%
- Sends Telegram: current phase, today's limit, metrics

---

## PHASE 10 — DEPLOYMENT DOCS

Write `docs/DEPLOY.md`:
- Complete step-by-step from zero to live
- Phase 0: IP blacklist check (mxtoolbox)
- Phase 1: Hetzner PTR record fix (exact console steps)
- Phase 2: Cloudflare setup (D1, R2, Workers, DNS records)
- Phase 3: GitHub repo setup + secrets
- Phase 4: First manual CX33 spawn + test
- Phase 5: Warmup week 1 checklist
- All CLI commands, exact API calls, verification steps

---

## OUTPUT FORMAT RULES

1. **One file per code block** — Label each block with full path:
   `// FILE: docker-compose.yml`

2. **No placeholder comments** — If a value needs to be set by user,
   use `${ENV_VAR_NAME}` format, not `# TODO: fill this in`

3. **After each phase** — Output a ✅ checklist of what was created
   and ask if you should proceed to the next phase

4. **MCP usage log** — Before each section, show:
   `[Context7: fetched n8n HTTP node docs v1.x]`
   `[Exa: found Postfix sender_dependent example from mail-archive.com]`

5. **Critical warnings** — Any PRD-flagged critical item (PTR, blacklist,
   warmup) must appear as a ⚠️ WARNING block in relevant files

---

## STARTING INSTRUCTION

Begin with **Phase 1 only** — produce the complete directory tree and
implementation plan. Do NOT write any code yet. After I confirm the plan,
proceed phase by phase.

Use Context7 MCP now to fetch docs for: n8n, Listmonk, Cloudflare Workers D1.
Use Exa MCP now to search for: "Listmonk Postfix multi-IP routing production"
and "Cloudflare D1 Workers click tracking redirect".

Present findings summary before showing the plan.
```