# Repository Guidelines

## Project Structure & Module Organization
This repository is currently in a planning phase and contains two source-of-truth documents:
- `instructions.md`: implementation brief and delivery workflow.
- `nammaoornewsprd.txt`: full product and engineering PRD.

As implementation lands, keep infrastructure code organized by domain:
- `cloudflare/` (Workers, D1 schema, Wrangler config)
- `n8n/workflows/` (workflow JSON exports)
- `postgres/init/` (schema + seed SQL)
- `docker/` (service Dockerfiles/config)
- `scripts/` (automation and ops scripts)
- `docs/` (runbooks and DNS/ops notes)

## Build, Test, and Development Commands
No compiled app is committed yet; use lightweight validation while editing docs/specs:
- `rg --files` to inspect tracked file paths quickly.
- `wc -w AGENTS.md` to keep docs concise.
- `sed -n '1,120p' <file>` to review sections before committing.

When infra files are added, validate before PR:
- `docker compose config` (compose syntax and interpolation)
- `bash -n scripts/*.sh` (shell syntax checks)

## Coding Style & Naming Conventions
- Use Markdown with clear heading hierarchy and short sections.
- Prefer lowercase, hyphenated names for scripts/files (example: `self-delete.sh`, `click-tracker`).
- Use 2-space indentation in YAML and JSON; 4 spaces in Python; tab-free shell scripts.
- Keep environment variables uppercase snake case (example: `HETZNER_API_TOKEN`).

## Testing Guidelines
- Treat validation as mandatory for every changed artifact.
- For SQL, run idempotency/syntax checks in the target Postgres version before merge.
- For workflow/config changes, include a dry-run or validation command output in PR notes.
- Name tests by behavior (example: `test_click_event_sync.sql`, `test_transport_map_generation.sh`).

## Commit & Pull Request Guidelines
Git history is not available in this workspace snapshot, so follow Conventional Commits going forward:
- `feat: add D1 click event schema`
- `fix: correct postfix transport map generation`
- `docs: update DNS setup steps`

PRs should include:
- Clear summary and impacted paths.
- Linked issue/requirement section from the PRD.
- Evidence of validation commands run.
- Screenshots only when UI/dashboard output is changed.

## Security & Configuration Tips
- Never commit secrets, API tokens, private keys, or `.env` files.
- Use placeholder values in examples and document required secrets in `docs/`.
- Treat DNS, SMTP, and IP-routing changes as high-risk; require explicit reviewer sign-off.
