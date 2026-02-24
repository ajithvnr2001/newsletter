#!/usr/bin/env sh
set -eu

if [ ! -d /workflows ]; then
  echo "[n8n-import] /workflows not mounted, skipping import"
  exit 0
fi

found=0
for file in /workflows/*.json; do
  if [ -f "$file" ]; then
    found=1
    echo "[n8n-import] importing $file"
    n8n import:workflow --input "$file" || true
  fi
done

if [ "$found" -eq 0 ]; then
  echo "[n8n-import] no workflow JSON files found"
fi
