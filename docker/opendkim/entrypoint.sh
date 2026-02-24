#!/usr/bin/env bash
set -euo pipefail

mkdir -p /etc/opendkim /etc/opendkim/keys

if [[ -f /etc/opendkim/KeyTable.template ]]; then
  envsubst < /etc/opendkim/KeyTable.template > /etc/opendkim/KeyTable
fi

if [[ -f /etc/opendkim/SigningTable.template ]]; then
  envsubst < /etc/opendkim/SigningTable.template > /etc/opendkim/SigningTable
fi

exec opendkim -f -x /etc/opendkim.conf
