---
description: Validate all code artifacts (JS syntax, JSON parse, shell syntax)
---

# Validate Codebase

Run syntax and integrity checks on all code files.

## Steps

// turbo
1. Check Worker JavaScript syntax:
```bash
node --check cloudflare/workers/click-tracker/index.js
node --check cloudflare/workers/subscription-handler/index.js
node --check cloudflare/workers/spawn-server/index.js
node --check cloudflare/workers/backup-delete-check/index.js
```

// turbo
2. Validate n8n workflow JSON (PowerShell):
```powershell
Get-ChildItem n8n/workflows/*.json | ForEach-Object { Get-Content -Raw $_ | ConvertFrom-Json > $null }; Write-Host 'All workflows valid'
```

3. Validate n8n workflow JSON (bash, if available):
```bash
jq empty n8n/workflows/*.json && echo 'ok'
```

4. Shell script syntax check (bash, if available):
```bash
bash -n scripts/generate_postfix_config.sh
bash -n scripts/self_delete.sh
bash -n scripts/warmup_controller.sh
bash -n scripts/backup_to_r2.sh
bash -n scripts/restore_from_r2.sh
bash -n scripts/import_n8n_workflows.sh
bash -n cloud-init/user-data.sh
bash -n docker/opendkim/entrypoint.sh
bash -n docker/postfix/entrypoint.sh
bash -n docker/listmonk/start.sh
```

// turbo
5. Docker Compose config validation:
```bash
docker compose config --quiet && echo 'compose valid'
```

// turbo
6. List all tracked files:
```bash
git ls-files | wc -l
```
