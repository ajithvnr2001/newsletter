#!/usr/bin/env bash
set -euo pipefail

PGHOST="${PGHOST:-postgres}"
PGPORT="${PGPORT:-5432}"
PGDATABASE="${POSTGRES_DB:-listmonk}"
PGUSER="${POSTGRES_USER:-listmonk}"
PGPASSWORD="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
N8N_WEBHOOK_URL="${N8N_WEBHOOK_URL:?N8N_WEBHOOK_URL is required}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

export PGPASSWORD

send_telegram() {
  local msg="$1"
  [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]] && return 0
  curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "content-type: application/json" \
    -d "$(jq -nc --arg chat "$TELEGRAM_CHAT_ID" --arg text "$msg" '{chat_id:$chat,text:$text}')" >/dev/null
}

phase="$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -Atc "SELECT current_phase FROM warmup_state WHERE id = 1")"
open_rate="$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -Atc "SELECT COALESCE(ROUND((SUM(opened_count)::numeric / NULLIF(SUM(delivered_count),0))*100, 2), 0) FROM campaign_metrics WHERE created_at::date = CURRENT_DATE - INTERVAL '1 day'")"
bounce_rate="$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -Atc "SELECT COALESCE(ROUND((SUM(bounced_count)::numeric / NULLIF(SUM(sent_count),0))*100, 2), 0) FROM campaign_metrics WHERE created_at::date = CURRENT_DATE - INTERVAL '1 day'")"

case "$phase" in
  1) max_sends=150 ;;
  2) max_sends=350 ;;
  3) max_sends=700 ;;
  4) max_sends=1100 ;;
  5) max_sends=1750 ;;
  *) max_sends=2500 ;;
esac

if awk "BEGIN {exit !($bounce_rate < 2 && $open_rate > 25)}"; then
  next_phase="$((phase + 1))"
else
  next_phase="$phase"
fi

psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "
UPDATE warmup_state
SET current_phase = ${next_phase},
    max_sends_today = ${max_sends},
    open_rate = ${open_rate},
    bounce_rate = ${bounce_rate},
    updated_at = CURRENT_TIMESTAMP
WHERE id = 1;
" >/dev/null

curl -fsS -X POST "$N8N_WEBHOOK_URL/webhook/main-pipeline" \
  -H "content-type: application/json" \
  -d "$(jq -nc --argjson max "$max_sends" '{max_sends:$max}')" >/dev/null

send_telegram "🔥 Warmup phase ${next_phase}: max_sends=${max_sends}, open_rate=${open_rate}%, bounce_rate=${bounce_rate}%"
