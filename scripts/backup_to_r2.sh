#!/usr/bin/env bash
set -euo pipefail

BACKUP_DATE="$(date +%F)"
BACKUP_DIR="/tmp/namma-backups"
mkdir -p "$BACKUP_DIR"

export PGPASSWORD="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"

pg_dump -h "${PGHOST:-postgres}" -p "${PGPORT:-5432}" -U "${POSTGRES_USER:-listmonk}" "${POSTGRES_DB:-listmonk}" | gzip > "${BACKUP_DIR}/listmonk-${BACKUP_DATE}.sql.gz"

if command -v n8n >/dev/null 2>&1; then
  n8n export:workflow --backup --output "${BACKUP_DIR}/n8n-workflows-${BACKUP_DATE}.json"
else
  docker compose exec -T n8n n8n export:workflow --backup --output "/tmp/n8n-workflows-${BACKUP_DATE}.json"
  docker compose cp "n8n:/tmp/n8n-workflows-${BACKUP_DATE}.json" "${BACKUP_DIR}/n8n-workflows-${BACKUP_DATE}.json"
fi

psql -h "${PGHOST:-postgres}" -p "${PGPORT:-5432}" -U "${POSTGRES_USER:-listmonk}" "${POSTGRES_DB:-listmonk}" -c "\copy (SELECT * FROM campaign_metrics WHERE created_at::date = CURRENT_DATE) TO '${BACKUP_DIR}/campaign-metrics-${BACKUP_DATE}.csv' WITH CSV HEADER"
psql -h "${PGHOST:-postgres}" -p "${PGPORT:-5432}" -U "${POSTGRES_USER:-listmonk}" "${POSTGRES_DB:-listmonk}" -c "\copy (SELECT * FROM ad_performance WHERE date = CURRENT_DATE) TO '${BACKUP_DIR}/ad-performance-${BACKUP_DATE}.csv' WITH CSV HEADER"

rclone copy "$BACKUP_DIR" "r2:${CLOUDFLARE_R2_BUCKET}/daily/${BACKUP_DATE}" --retries 3 --retries-sleep 5s
rclone copy "${BACKUP_DIR}/n8n-workflows-${BACKUP_DATE}.json" "r2:${CLOUDFLARE_R2_BUCKET}/workflows/" --retries 3 --retries-sleep 5s

# Verification step required before self-delete.
rclone lsf "r2:${CLOUDFLARE_R2_BUCKET}/daily/${BACKUP_DATE}" | grep -q "listmonk-${BACKUP_DATE}.sql.gz"
rclone lsf "r2:${CLOUDFLARE_R2_BUCKET}/daily/${BACKUP_DATE}" | grep -q "n8n-workflows-${BACKUP_DATE}.json"
rclone lsf "r2:${CLOUDFLARE_R2_BUCKET}/daily/${BACKUP_DATE}" | grep -q "campaign-metrics-${BACKUP_DATE}.csv"
rclone lsf "r2:${CLOUDFLARE_R2_BUCKET}/daily/${BACKUP_DATE}" | grep -q "ad-performance-${BACKUP_DATE}.csv"

echo "[backup] uploaded daily backups to R2 path daily/${BACKUP_DATE}"
