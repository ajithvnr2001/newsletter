#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-nammaoorunews.com}"
MAIL_HOSTNAME="${MAIL_HOSTNAME:-mail.nammaoorunews.com}"

if [[ -f /etc/postfix/main.cf.template ]]; then
  export DOMAIN MAIL_HOSTNAME
  envsubst '${DOMAIN} ${MAIL_HOSTNAME}' < /etc/postfix/main.cf.template > /etc/postfix/main.cf
fi

if [[ -f /etc/postfix/master.cf.template ]]; then
  cp /etc/postfix/master.cf.template /etc/postfix/master.cf
fi

if [[ ! -f /etc/postfix/transport ]]; then
  touch /etc/postfix/transport
fi
if [[ ! -f /etc/postfix/sender_dependent_default_transport_maps ]]; then
  touch /etc/postfix/sender_dependent_default_transport_maps
fi

postmap /etc/postfix/transport || true
postmap /etc/postfix/sender_dependent_default_transport_maps || true

if [[ -x /opt/namma/scripts/generate_postfix_config.sh ]]; then
  /opt/namma/scripts/generate_postfix_config.sh || true
fi

postconf -e "myhostname = ${MAIL_HOSTNAME}"
postconf -e "mydomain = ${DOMAIN}"
postconf -e "myorigin = ${DOMAIN}"
postconf -e "sender_dependent_default_transport_maps = hash:/etc/postfix/sender_dependent_default_transport_maps"
postconf -e "transport_maps = hash:/etc/postfix/transport"

exec postfix start-fg
