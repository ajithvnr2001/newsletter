#!/usr/bin/env bash
set -euo pipefail

LATEST_OBJECT="$(rclone lsf "r2:${CLOUDFLARE_R2_BUCKET}/daily" | tail -n 1)"

if [[ -z "$LATEST_OBJECT" ]]; then
  echo "[restore] no backup found, skipping"
  exit 0
fi

tmp_dir="/tmp/namma-restore"
mkdir -p "$tmp_dir"
rclone copy "r2:${CLOUDFLARE_R2_BUCKET}/daily/${LATEST_OBJECT}" "$tmp_dir"

latest_dump="$(ls -1 "$tmp_dir"/*.sql.gz | head -n 1 || true)"
if [[ -n "$latest_dump" ]]; then
  gunzip -c "$latest_dump" | psql -h "${PGHOST:-postgres}" -p "${PGPORT:-5432}" -U "${POSTGRES_USER:-listmonk}" "${POSTGRES_DB:-listmonk}"
fi

echo "[restore] restore completed from $LATEST_OBJECT"
