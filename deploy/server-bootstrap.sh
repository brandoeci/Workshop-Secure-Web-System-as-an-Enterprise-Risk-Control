#!/usr/bin/env bash
# Prepares a fresh Ubuntu server for the workshop. Run it as a sudo-capable
# non-root user, BEFORE exposing the host to the internet.
#
#   sudo ./server-bootstrap.sh team4-risk.duckdns.org
set -euo pipefail

DOMAIN=${1:?usage: server-bootstrap.sh YOUR-SUBDOMAIN.duckdns.org}

if [[ $EUID -ne 0 ]]; then
  echo "run with sudo" >&2
  exit 1
fi

echo "==> Packages"
apt update
apt install -y apache2 certbot python3-certbot-apache openjdk-21-jre-headless ufw curl

echo "==> Firewall: only SSH, HTTP and HTTPS are public. 8080 stays private."
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw status verbose

echo "==> Service account and application directory"
id -u riskapi >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin riskapi
install -d -o riskapi -g riskapi -m 0750 /opt/enterprise-risk-api
install -d -o www-data -g www-data -m 0755 /var/www/enterprise-risk-frontend

echo "==> Apache modules"
a2enmod ssl proxy proxy_http rewrite headers
# Drop the default site so the workshop vhost is the one that answers.
a2dissite 000-default.conf >/dev/null 2>&1 || true

echo "==> Unattended security updates"
apt install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

cat <<NEXT

Server ready. Next:
  1. Point ${DOMAIN} at this host's public IP (see duckdns-update.sh).
  2. Run deploy.sh from your development machine to upload the build.
  3. sudo certbot --apache -d ${DOMAIN}
NEXT
