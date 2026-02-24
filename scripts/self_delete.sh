#!/usr/bin/env bash
set -euo pipefail

HETZNER_API_TOKEN="${HETZNER_API_TOKEN:?HETZNER_API_TOKEN is required}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
SELF_DELETE_WORKER_URL="${SELF_DELETE_WORKER_URL:-}"
SELF_DELETE_WORKER_TOKEN="${SELF_DELETE_WORKER_TOKEN:-}"

send_telegram() {
  local msg="$1"
  [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]] && return 0
  curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "content-type: application/json" \
    -d "$(jq -nc --arg chat "$TELEGRAM_CHAT_ID" --arg text "$msg" '{chat_id:$chat,text:$text}')" >/dev/null
}

SERVER_ID="$(
  curl -fsS --connect-timeout 3 --max-time 5 http://169.254.169.254/hetzner/v1/metadata \
  | jq -r '.instance_id // ."instance-id" // empty'
)"

if [[ -z "$SERVER_ID" || "$SERVER_ID" == "null" ]]; then
  send_telegram "❌ self_delete.sh failed: could not read instance ID from Hetzner metadata"
  exit 1
fi

curl -fsS -X DELETE "https://api.hetzner.cloud/v1/servers/${SERVER_ID}" \
  -H "Authorization: Bearer ${HETZNER_API_TOKEN}" >/dev/null

send_telegram "✅ Self-delete complete for server ${SERVER_ID}"

if [[ -n "$SELF_DELETE_WORKER_URL" ]]; then
  curl -fsS -X POST "$SELF_DELETE_WORKER_URL" \
    -H "Authorization: Bearer ${SELF_DELETE_WORKER_TOKEN}" >/dev/null || true
fi
