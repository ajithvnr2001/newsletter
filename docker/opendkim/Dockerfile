FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    opendkim \
    opendkim-tools \
    rsyslog \
  && rm -rf /var/lib/apt/lists/*

COPY docker/opendkim/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8891
ENTRYPOINT ["/entrypoint.sh"]
