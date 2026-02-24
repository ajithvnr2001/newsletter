#!/usr/bin/env bash
set -euo pipefail

N8N_API_URL="${N8N_API_URL:-http://n8n:5678/api/v1}"
N8N_API_KEY="${N8N_API_KEY:-}"
DOMAIN="${DOMAIN:-nammaoorunews.com}"
MAP_JSON=""

if [[ -n "$N8N_API_KEY" ]]; then
  MAP_JSON="$(curl -fsS -H "X-N8N-API-KEY: ${N8N_API_KEY}" "${N8N_API_URL}/variables/DISTRICT_IP_MAP" | jq -r '.data.value // empty' || true)"
fi

if [[ -z "$MAP_JSON" ]]; then
  MAP_JSON="${DISTRICT_IP_MAP:-{}}"
fi

if [[ "$MAP_JSON" == "{}" || -z "$MAP_JSON" ]]; then
  echo "[postfix-config] DISTRICT_IP_MAP is empty; refusing to update Postfix maps"
  exit 1
fi

transport_file="/etc/postfix/transport"
sender_map_file="/etc/postfix/sender_dependent_default_transport_maps"

: > "$transport_file"
: > "$sender_map_file"

for district in $(echo "$MAP_JSON" | jq -r 'keys[]'); do
  ip=$(echo "$MAP_JSON" | jq -r --arg district "$district" '.[$district]')
  sender="${district}@${DOMAIN}"
  echo "sender:${sender} smtp:[${ip}]:25" >> "$transport_file"
  echo "${sender} smtp:[${ip}]:25" >> "$sender_map_file"
done

postmap "$transport_file"
postmap "$sender_map_file"
postfix reload

echo "[postfix-config] updated transport maps from DISTRICT_IP_MAP"
