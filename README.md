# Namma Ooru News

Production-oriented infrastructure for an automated Tamil hyperlocal newsletter platform.

## PRD v21 Alignment (Latest)

This repository now includes the new Section 6 subscription architecture from `nammaoornewsprdv21.txt`:
- 24/7 signup ingestion on Cloudflare Worker (`subscribe.nammaoorunews.com`).
- `pending_subscribers` table in Cloudflare D1.
- Cloudflare Pages signup form (`/subscribe`) with Tamil/English UX.
- `05:01` n8n subscriber sync workflow from D1 to Listmonk.

## Architecture Overview

Daily run (IST):
1. `04:55` - `spawn-server` Worker creates the Hetzner VM.
2. `05:00` - VM boots Docker stack (Postgres, n8n, Listmonk, Postfix, Scrapling API).
3. `05:01` - `subscriber-sync` workflow reads unsynced D1 `pending_subscribers` and adds them to Listmonk.
4. `05:03` - `d1-click-sync` workflow aggregates D1 click events into Postgres.
5. `05:05+` - main n8n pipeline generates district campaigns.
6. `06:30-07:30` - district sends start in waves.
7. `07:45+` - metrics/backup/delete checks run.

Always-on components:
- Cloudflare Workers (click + subscribe + spawn + delete-check).
- Cloudflare D1 (click storage + signup buffer).
- Cloudflare Pages (signup form hosting).

## Repository Layout

- `cloudflare/d1/schema.sql`
  - D1 schema for `click_links`, `click_events`, `pending_subscribers`.
- `cloudflare/workers/click-tracker`
  - Redirect + click event write path (`click.nammaoorunews.com`).
- `cloudflare/workers/subscription-handler`
  - 24/7 signup ingestion worker (`subscribe.nammaoorunews.com`).
- `cloudflare/workers/spawn-server`
  - Daily Hetzner VM spawn worker.
- `cloudflare/workers/backup-delete-check`
  - Fallback cleanup worker.
- `cloudflare/pages/subscribe/index.html`
  - Bilingual signup page for Cloudflare Pages deployment.
- `n8n/workflows/subscriber-sync.json`
  - `05:01` subscriber sync workflow.
- `n8n/workflows/d1-click-sync.json`
  - `05:03` click sync workflow.
- `n8n/workflows/main-pipeline.json`
  - Content pipeline and campaign lifecycle.

## Cloudflare Workers and Routes

- `click-tracker`
  - Route: `click.nammaoorunews.com/*`
  - Handles `/l/{token}` redirect + async click write to D1.
- `subscription-handler`
  - Route: `subscribe.nammaoorunews.com/*`
  - Validates request, deduplicates by `(email,district)`, inserts into `pending_subscribers`, and handles duplicate race collisions idempotently.
- `spawn-server`
  - Route: `spawn.nammaoorunews.com/*`
  - Cron: `25 23 * * *` (04:55 IST)
- `backup-delete-check`
  - Route: `delete-check.nammaoorunews.com/*`
  - Cron fallback deletion safety.

## n8n Workflows

- `subscriber-sync.json` (new)
  - Trigger: `05:01` daily.
  - Fetches D1 pending rows (`is_synced = 0`), adds to Listmonk, marks D1 rows synced only after successful API calls, sends Telegram summary.
- `d1-click-sync.json`
  - Trigger: `05:03` daily.
  - Aggregates click data from D1 into Postgres `ad_performance`.
- Existing workflows remain for main pipeline, scaling, balancing, backups, and alerts.

## Validation Snapshot

Latest workspace validation after PRD v21 changes:
- Workflow JSON parse (PowerShell `ConvertFrom-Json`): pass.
- Worker JavaScript syntax (`node --check`): pass (all workers including new subscription handler).
- `jq`, `bash`, and `python` commands: not executable in this workspace environment (tooling/runtime access limitation).

## Current Status

- Code artifacts for v21 Section 6 are now implemented.
- Production rollout is still pending operator execution:
  - Cloudflare deployment (Workers + Pages + D1 migration).
  - n8n import/activation.
  - Secrets and credential wiring.
  - Live send validation and deliverability gates.

## Related Documents

- `review&validations.md`
- `completionstatus.md`
- `executionsteps.md`
- `docs/DEPLOY.md`
