FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    gettext-base \
    jq \
    opendkim \
    opendkim-tools \
    postfix \
    rsyslog \
  && rm -rf /var/lib/apt/lists/*

COPY docker/postfix/main.cf.template /etc/postfix/main.cf.template
COPY docker/postfix/master.cf.template /etc/postfix/master.cf.template
COPY docker/postfix/opendkim.conf /etc/opendkim.conf
COPY docker/postfix/KeyTable.template /etc/opendkim/KeyTable.template
COPY docker/postfix/SigningTable.template /etc/opendkim/SigningTable.template
COPY docker/postfix/TrustedHosts /etc/opendkim/TrustedHosts
COPY docker/postfix/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 25
ENTRYPOINT ["/entrypoint.sh"]
