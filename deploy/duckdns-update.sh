#!/usr/bin/env bash
# Keeps the Duck DNS record pointing at this server's public IP.
#
# Install:
#   sudo install -m 0750 -o root -g root duckdns-update.sh /usr/local/bin/duckdns-update
#   printf 'DUCKDNS_SUBDOMAIN=YOUR-SUBDOMAIN\nDUCKDNS_TOKEN=YOUR-TOKEN\n' | sudo tee /etc/duckdns.env
#   sudo chmod 600 /etc/duckdns.env
#   ( crontab -l 2>/dev/null; echo '*/5 * * * * /usr/local/bin/duckdns-update >/dev/null 2>&1' ) | sudo crontab -
#
# The token is a credential: it lives in /etc/duckdns.env (mode 600), never in git.
set -euo pipefail

ENV_FILE=${DUCKDNS_ENV_FILE:-/etc/duckdns.env}
[[ -r "$ENV_FILE" ]] || { echo "missing $ENV_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"

: "${DUCKDNS_SUBDOMAIN:?set DUCKDNS_SUBDOMAIN in $ENV_FILE}"
: "${DUCKDNS_TOKEN:?set DUCKDNS_TOKEN in $ENV_FILE}"

LOG=/var/log/duckdns.log

# Empty ip= lets Duck DNS use the source address of this request.
response=$(curl -fsS \
  "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=")

printf '%s duckdns: %s\n' "$(date --iso-8601=seconds)" "$response" >> "$LOG"
[[ "$response" == "OK" ]] || { echo "duckdns update failed: $response" >&2; exit 1; }
