#!/usr/bin/env bash
set -euo pipefail

# cloud-init bootstrap for ephemeral CX33. Runs on every 05:00 AM spawn.

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  jq \
  nodejs \
  npm \
  unzip \
  docker.io \
  docker-compose-plugin \
  postgresql-client \
  rclone

systemctl enable docker
systemctl start docker

if ! command -v wrangler >/dev/null 2>&1; then
  npm install -g wrangler@latest
fi

mkdir -p /opt/namma
cd /opt/namma

if [[ ! -d namma-ooru-news ]]; then
  git clone "${GIT_REPO_URL:-https://github.com/your-org/namma-ooru-news.git}" namma-ooru-news
fi

cd namma-ooru-news
git fetch --all
git checkout "${GIT_BRANCH:-main}"
git pull --ff-only origin "${GIT_BRANCH:-main}"

cp .env.example .env

get_env_value() {
  local key="$1"
  sed -n "s/^${key}=//p" .env | head -n 1
}

R2_ACCESS_KEY_ID="$(get_env_value R2_ACCESS_KEY_ID)"
R2_SECRET_ACCESS_KEY="$(get_env_value R2_SECRET_ACCESS_KEY)"
CLOUDFLARE_R2_ENDPOINT="$(get_env_value CLOUDFLARE_R2_ENDPOINT)"
CLOUDFLARE_R2_BUCKET="$(get_env_value CLOUDFLARE_R2_BUCKET)"
POSTGRES_USER="$(get_env_value POSTGRES_USER)"
POSTGRES_DB="$(get_env_value POSTGRES_DB)"
POSTGRES_PORT="$(get_env_value POSTGRES_PORT)"
N8N_WEBHOOK_URL="$(get_env_value N8N_WEBHOOK_URL)"
SELF_DELETE_WORKER_URL="$(get_env_value SELF_DELETE_WORKER_URL)"
SELF_DELETE_WORKER_TOKEN="$(get_env_value SELF_DELETE_WORKER_TOKEN)"

mkdir -p /root/.config/rclone
if [[ -n "${R2_ACCESS_KEY_ID:-}" && -n "${R2_SECRET_ACCESS_KEY:-}" && -n "${CLOUDFLARE_R2_ENDPOINT:-}" ]]; then
  cat > /root/.config/rclone/rclone.conf <<RCLONECFG
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
endpoint = ${CLOUDFLARE_R2_ENDPOINT}
acl = private
RCLONECFG
fi

# Start full stack.
docker compose --env-file .env up -d --build

# Wait for PostgreSQL readiness first, then restore if backups exist.
for i in $(seq 1 60); do
  if pg_isready -h 127.0.0.1 -p "${POSTGRES_PORT:-5432}" -U "${POSTGRES_USER:-listmonk}" -d "${POSTGRES_DB:-listmonk}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if [[ -n "${R2_ACCESS_KEY_ID:-}" ]]; then
  PGHOST=127.0.0.1 ./scripts/restore_from_r2.sh || true
fi

# Import n8n workflows from R2 snapshot if available.
if [[ -n "${R2_ACCESS_KEY_ID:-}" ]]; then
  mkdir -p ./n8n/workflows
  rclone copy "r2:${CLOUDFLARE_R2_BUCKET}/workflows" "./n8n/workflows" || true
  docker compose exec -T n8n /bin/sh -lc 'for f in /workflows/*.json; do [ -f "$f" ] && n8n import:workflow --input "$f" || true; done' || true
fi

# Wait for n8n before webhook trigger.
for i in $(seq 1 60); do
  if curl -fsS "http://localhost:5678/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Regenerate postfix routing maps from current DISTRICT_IP_MAP.
docker compose exec -T postfix /bin/bash /opt/namma/scripts/generate_postfix_config.sh || true

# Trigger main workflow webhook after services come up.
if [[ -n "${N8N_WEBHOOK_URL:-}" ]]; then
  curl -fsS -X POST "${N8N_WEBHOOK_URL}/webhook/main-pipeline" \
    -H "content-type: application/json" \
    -d '{"trigger":"cloud-init"}' || true
fi

# Schedule self-delete at 08:00 AM IST daily.
(crontab -l 2>/dev/null; echo "0 8 * * * /opt/namma/namma-ooru-news/scripts/self_delete.sh >> /var/log/namma-self-delete.log 2>&1") | crontab -

# Safety backup check trigger at 09:00 AM IST.
(crontab -l 2>/dev/null; echo "0 9 * * * curl -fsS -X POST ${SELF_DELETE_WORKER_URL} -H 'Authorization: Bearer ${SELF_DELETE_WORKER_TOKEN}' >/dev/null 2>&1") | crontab -
