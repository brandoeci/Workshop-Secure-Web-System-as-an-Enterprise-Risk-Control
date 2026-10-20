#!/usr/bin/env bash
# Builds both halves on a trusted machine and ships them over SSH.
#
#   ./deploy.sh deployer@team4-risk.duckdns.org team4-risk.duckdns.org
#
# Nothing secret is uploaded: the JAR reads its Auth0 settings from the
# systemd unit on the server, and the frontend bundle only contains the
# public domain, client ID and audience.
set -euo pipefail

SSH_TARGET=${1:?usage: deploy.sh user@host DOMAIN}
DOMAIN=${2:?usage: deploy.sh user@host DOMAIN}
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

echo "==> Building the backend"
(cd "$REPO_ROOT/backend" && ./mvnw -B clean package)

echo "==> Building the frontend for https://${DOMAIN}"
(
  cd "$REPO_ROOT/frontend"
  npm ci
  VITE_API_URL="https://${DOMAIN}" npm run build
)

echo "==> Uploading"
scp "$REPO_ROOT"/backend/target/enterprise-risk-api.jar "$SSH_TARGET:/tmp/app.jar"
rsync -av --delete "$REPO_ROOT/frontend/dist/" "$SSH_TARGET:/tmp/enterprise-risk-frontend/"

echo "==> Installing on the server"
ssh "$SSH_TARGET" "sudo bash -s" <<'REMOTE'
set -euo pipefail
install -o riskapi -g riskapi -m 0640 /tmp/app.jar /opt/enterprise-risk-api/app.jar
rm -f /tmp/app.jar
rsync -a --delete --chown=www-data:www-data /tmp/enterprise-risk-frontend/ /var/www/enterprise-risk-frontend/
rm -rf /tmp/enterprise-risk-frontend
systemctl restart enterprise-risk-api
systemctl reload apache2
sleep 3
curl -fsS http://127.0.0.1:8080/actuator/health && echo
REMOTE

echo "==> Done: https://${DOMAIN}"
