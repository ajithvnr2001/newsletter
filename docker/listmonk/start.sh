#!/usr/bin/env sh
set -eu

CONFIG_FILE="/tmp/listmonk-config.toml"

cat >"${CONFIG_FILE}" <<EOF
[app]
address = "0.0.0.0:9000"
admin_username = "${LISTMONK_ADMIN_USER}"
admin_password = "${LISTMONK_ADMIN_PASSWORD}"
site_name = "Namma Ooru News"
root_url = "${LISTMONK_PUBLIC_URL}"
from_email = "${LISTMONK_FROM_EMAIL}"
lang = "en"
upload_uri = "/uploads"

[db]
host = "postgres"
port = 5432
user = "${POSTGRES_USER}"
password = "${POSTGRES_PASSWORD}"
database = "${POSTGRES_DB}"
ssl_mode = "disable"
max_open = 25
max_idle = 25
max_lifetime = "300s"

[smtp]
enabled = true
host = "postfix"
port = 25
auth_user = ""
auth_pass = ""
tls_enabled = false
tls_skip_verify = true
max_conns = 10
idle_timeout = "30s"
wait_timeout = "5s"
EOF

./listmonk --install --yes --idempotent --config "${CONFIG_FILE}"
exec ./listmonk --config "${CONFIG_FILE}"
