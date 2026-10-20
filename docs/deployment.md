# Parts 4–6 — Server, Duck DNS, Apache and TLS

Everything below runs on a Linux server you control. Before you expose it:
change default credentials, create a non-root deployment user, and enable a
firewall. `deploy/server-bootstrap.sh` does the last two.

## Part 4 — Prepare the server and Duck DNS

1. Create a subdomain at [duckdns.org](https://www.duckdns.org), for example
   `team4-risk.duckdns.org`.

2. Install the updater so the record follows the server's public IP:

   ```bash
   sudo install -m 0750 deploy/duckdns-update.sh /usr/local/bin/duckdns-update
   printf 'DUCKDNS_SUBDOMAIN=team4-risk\nDUCKDNS_TOKEN=YOUR-TOKEN\n' | sudo tee /etc/duckdns.env
   sudo chmod 600 /etc/duckdns.env
   ( sudo crontab -l 2>/dev/null; echo '*/5 * * * * /usr/local/bin/duckdns-update >/dev/null 2>&1' ) | sudo crontab -
   sudo /usr/local/bin/duckdns-update   # should log OK
   ```

   The token is a credential: mode 600, root-owned, never in git.

3. Confirm the hostname resolves to the server:

   ```bash
   dig +short team4-risk.duckdns.org
   curl -s https://ifconfig.me   # run on the server; the two must match
   ```

4. At the cloud provider's security group **and** the host firewall, allow
   inbound TCP **80 and 443 only** (plus SSH from your own address). Port 8080
   is never public — that is the whole point of the reverse proxy.

5. Install the packages (the bootstrap script does this for you):

   ```bash
   sudo apt update
   sudo apt install -y apache2 certbot python3-certbot-apache openjdk-21-jre-headless ufw
   ```

6. Build on a trusted machine or CI runner, never on the public server:

   ```bash
   cd frontend && npm ci && npm run build
   cd ../backend && ./mvnw clean package
   ```

## Part 5 — Deploy the backend

```bash
sudo mkdir -p /opt/enterprise-risk-api
sudo useradd --system --no-create-home --shell /usr/sbin/nologin riskapi
sudo install -o riskapi -g riskapi -m 0640 target/enterprise-risk-api.jar /opt/enterprise-risk-api/app.jar

sudo cp deploy/enterprise-risk-api.service /etc/systemd/system/
sudo nano /etc/systemd/system/enterprise-risk-api.service   # set tenant + hostname
sudo systemctl daemon-reload
sudo systemctl enable --now enterprise-risk-api
```

Verify it is up and reachable **only** from the host itself:

```bash
curl http://127.0.0.1:8080/actuator/health        # {"status":"UP"}
curl http://YOUR-PUBLIC-IP:8080/actuator/health   # must fail or time out
journalctl -u enterprise-risk-api -n 50 --no-pager
```

The unit sets `SERVER_ADDRESS=127.0.0.1`, so even with the firewall off the
application still only listens on loopback. Two independent controls, one risk.

## Part 6 — Apache and HTTPS

```bash
sudo mkdir -p /var/www/enterprise-risk-frontend
sudo cp -r frontend/dist/* /var/www/enterprise-risk-frontend/
sudo chown -R www-data:www-data /var/www/enterprise-risk-frontend

sudo a2enmod ssl proxy proxy_http rewrite headers
sudo cp deploy/enterprise-risk.conf /etc/apache2/sites-available/
sudo nano /etc/apache2/sites-available/enterprise-risk.conf   # set ServerName
sudo a2ensite enterprise-risk.conf
sudo a2dissite 000-default.conf
sudo apachectl configtest        # expect: Syntax OK
sudo systemctl reload apache2
```

Request the certificate. Duck DNS must already resolve to this server, because
Let's Encrypt proves domain control by fetching a file over port 80:

```bash
sudo certbot --apache -d YOUR-SUBDOMAIN.duckdns.org
```

Certbot writes `enterprise-risk-le-ssl.conf` (its shape is in
`deploy/enterprise-risk-le-ssl.conf.example`) and turns the port 80 host into a
redirect. Confirm renewal works **before** you depend on it:

```bash
sudo certbot renew --dry-run
sudo systemctl list-timers | grep certbot
```

## Rebuild the frontend against the public origin

The bundle has the API URL compiled in, so it must be rebuilt once the hostname
exists:

```bash
# frontend/.env.local (or an env var in CI)
VITE_API_URL=https://YOUR-SUBDOMAIN.duckdns.org
```

```bash
npm run build
sudo rsync -a --delete frontend/dist/ /var/www/enterprise-risk-frontend/
```

`deploy/deploy.sh` does the build-and-ship in one command.

Finally, add the HTTPS address to the Auth0 SPA's **Allowed Callback URLs**,
**Allowed Logout URLs** and **Allowed Web Origins**. Until you do, Auth0 refuses
the redirect back from the login page.

## Why `/api/` goes through Apache

With `VITE_API_URL` set to the site's own origin, the browser's API call is
same-origin: no preflight, no third-party cookie questions, and the token only
ever travels inside the TLS tunnel. The CORS allow-list in the backend stays as
a second line of defence — for local development, and for anything that tries
to call the API from an origin we did not publish.

## Operating it

```bash
systemctl status enterprise-risk-api
journalctl -u enterprise-risk-api -f            # audit trail of API calls
sudo tail -f /var/log/apache2/enterprise-risk-access.log
sudo apt update && sudo apt upgrade             # or rely on unattended-upgrades
```
