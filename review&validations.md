# Review and Validations Log

Date: 2026-02-25  
Scope: Consolidated record of code reviews and validation checks completed for this repository (including fixes pushed on 2026-02-24).

## 1. Review Summary

### Review Round A (Infrastructure + Workflow Audit)
Status: Completed

Findings and resolution:
- High: Spawn worker depended on static `ACTIVE_IPS` only.
  Resolution: `cloudflare/workers/spawn-server/index.js` now resolves primary IP IDs from configured IDs, IP literals, and Hetzner primary-IP name prefix.
- High: D1 click links were inserted with `campaign_id = 0` and not updated after campaign start.
  Resolution: `n8n/workflows/main-pipeline.json` now updates `click_links.campaign_id` in D1 immediately after `Start Campaign`.
- Medium: `scripts/backup_to_r2.sh` used `docker compose` without enforcing repo-root working directory.
  Resolution: script now resolves `SCRIPT_DIR`, `REPO_ROOT`, and executes from repo root before compose commands.
- Medium: LLM dedup node output was effectively ignored by extraction.
  Resolution: `Extract Unique Article URLs` now parses and uses LLM output when present, with RSS parsing fallback.

### Review Round B (Scale + Runtime State Audit)
Status: Completed

Findings and resolution:
- Scaling trigger should be subscriber-volume based, not district-bound IP mapping.
  Resolution: scaling query path updated to use subscriber-count signal in automation workflow.
- Runtime IP map state should come from n8n Variables API with env fallback.
  Resolution: workflows updated to fetch `DISTRICT_IP_MAP` via n8n API and fallback to env map / first active IP.
- Missing subscriber schema for load-balancer/scaling SQL.
  Resolution: `subscribers` table added in `postgres/init/01-schema.sql`.

### Review Round C (Pipeline Wiring Audit)
Status: Completed

Findings and resolution:
- Main pipeline order and token/link handling needed campaign attribution continuity.
  Resolution: token generation now carries `clickTokens` and post-campaign D1 backfill step is wired into flow.
- Workflow graph integrity rechecked after node additions.
  Resolution: connection-reference integrity check passed.

## 2. Validation Commands Executed

All commands below were executed and passed unless marked otherwise.

### JSON / Workflow Validation
- `jq empty n8n/workflows/*.json`
  Result: Pass

### Shell Script / Entrypoint Syntax
- `bash -n scripts/*.sh cloud-init/user-data.sh docker/postfix/entrypoint.sh docker/opendkim/entrypoint.sh docker/listmonk/start.sh`
  Result: Pass

### Python Syntax Validation
- `python3 -m py_compile scrapling-api/main.py scrapling-api/rewriter.py`
  Result: Pass

### JavaScript Syntax Validation
- `node --check cloudflare/workers/spawn-server/index.js`
  Result: Pass
- `node --check cloudflare/workers/click-tracker/index.js`
  Result: Pass
- `node --check cloudflare/workers/backup-delete-check/index.js`
  Result: Pass

### Workflow Connection Integrity
- Custom node-graph integrity check for `n8n/workflows/main-pipeline.json`
  Result: Pass (`main-pipeline connection references: ok`)

### Prior Validation Record (Earlier Audit)
- `bash -n` on scripts/entrypoints
  Result: Pass
- `jq empty` on workflows
  Result: Pass
- `python3 -m py_compile` on Scrapling API
  Result: Pass
- `docker compose config`
  Result: Not executed in this workspace (Docker CLI unavailable)

## 3. Commits Pushed (Main Branch)

- `667f3385cd816600c4b6f1c16950de0836a63736`  
  Message: `feat: sync newsletter infrastructure implementation`
- `fd70472f095ca061856f1e540c507849aa25243f`  
  Message: `docs: update README with implementation and runbook details`
- `2a7b1a828cfa5d42453f021cb1867faf5d76a63a`  
  Message: `feat: update subscriber-based scaling and runtime IP variable flow`
- `3181f347a0a76fd421951738dc2cc6195d35b332`  
  Message: `fix: finalize workflow execution fixes and campaign attribution`

## 4. Current State

- Code implementation status: Complete for planned repository artifacts.
- Execution status: Pending live environment rollout (secrets, cloud resources, DNS, and production run sequence).
- Latest code-review findings: Addressed and committed.
