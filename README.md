# Secure Web System as an Enterprise Risk Control

A small web system where every layer exists to control one named risk: a React
single page application that authenticates its user with Auth0, a Spring Boot
API that trusts nothing but a valid JWT, and an Apache front door that is the
only thing the internet can reach, over TLS.

**Deployed URL:** `https://YOUR-SUBDOMAIN.duckdns.org` *(replace after Part 6 —
see [Filling in your own values](#filling-in-your-own-values))*

## Architecture

```
Browser
  │ login and access token
  ▼
Auth0 ───────────────► React frontend ── Bearer token ──► Spring Boot API
                                                        │
Internet ── Duck DNS ── Apache + TLS ──────────────────┘
```

The browser never talks to port 8080. Apache serves the static React bundle and
reverse-proxies `/api/` to `127.0.0.1:8080`, so the API has exactly one public
path and it is encrypted.

## Repository layout

| Path | What it is |
| --- | --- |
| [backend/](backend/) | Spring Boot 3.3 OAuth 2.0 resource server, Java 21, one protected endpoint |
| [frontend/](frontend/) | Vite + React 18 SPA using `@auth0/auth0-react` |
| [deploy/](deploy/) | systemd unit, Apache virtual host, Duck DNS updater, bootstrap / deploy / verify scripts |
| [docs/](docs/) | Auth0 setup walkthrough, risk-control table, verification checklist, screenshots |

## Authentication vs authorization in this system

- **Authentication** happens at Auth0 and answers *who is this*. The SPA holds
  no password and no client secret; it redirects to Auth0 and comes back with an
  access token.
- **Authorization** happens at the API and answers *may this caller do this*.
  Spring Security validates the token's signature, issuer and audience, and
  `/api/**` requires an authenticated principal. Anything not declared is
  denied, not merely unprotected.

## Run it locally

Prerequisites: Java 21+, Node 20+, and an Auth0 tenant configured as described in
[docs/auth0-setup.md](docs/auth0-setup.md).

### Backend

```bash
cd backend
export AUTH0_ISSUER_URI="https://YOUR_TENANT.us.auth0.com/"
export AUTH0_AUDIENCE="https://enterprise-risk-api"
./mvnw spring-boot:run
```

Confirm the control before you confirm the feature:

```bash
curl -i http://localhost:8080/api/risk-status   # expect HTTP/1.1 401
curl -s http://localhost:8080/actuator/health   # expect {"status":"UP"}
```

Run the tests, which assert the same behaviour:

```bash
./mvnw test
```

### Frontend

```bash
cd frontend
cp .env.example .env.local   # then fill in your own Auth0 values
npm install
npm run dev                  # http://localhost:5173
```

Log in with the test user, press **Call protected API**, and you should get:

```json
{
  "status": "protected",
  "subject": "auth0|...",
  "control": "JWT validation and authenticated access"
}
```

**Call without a token** hits the same endpoint with no `Authorization` header
and shows the 401 — that is the screenshot evidence for the first checklist item.

## Deploy

Full walkthrough in [docs/deployment.md](docs/deployment.md). The short version,
from a trusted development machine:

```bash
# once, on the server
sudo ./deploy/server-bootstrap.sh YOUR-SUBDOMAIN.duckdns.org
sudo cp deploy/enterprise-risk-api.service /etc/systemd/system/
sudo cp deploy/enterprise-risk.conf /etc/apache2/sites-available/
sudo a2ensite enterprise-risk.conf && sudo systemctl reload apache2

# every release, from your machine
./deploy/deploy.sh deployer@YOUR-SUBDOMAIN.duckdns.org YOUR-SUBDOMAIN.duckdns.org

# once DNS resolves to the server
sudo certbot --apache -d YOUR-SUBDOMAIN.duckdns.org
sudo certbot renew --dry-run
```

Then check the result:

```bash
./deploy/verify.sh YOUR-SUBDOMAIN.duckdns.org
```

## Filling in your own values

Four places carry the hostname and tenant. Nothing else needs editing:

1. `frontend/.env.local` — domain, client ID, audience, `VITE_API_URL`
2. `deploy/enterprise-risk-api.service` — issuer URI, audience, allowed origins
3. `deploy/enterprise-risk.conf` — `ServerName`
4. Auth0 → SPA settings — callback, logout and web origin URLs

`backend/src/main/resources/application.properties` reads everything from
environment variables, so the committed file stays generic.

## Risk controls

Each control and the evidence that it works: [docs/risk-controls.md](docs/risk-controls.md).

| Control | Risk reduced |
| --- | --- |
| Auth0 authentication | Impersonation and weak credential handling |
| JWT validation at the API | Unauthorized API access |
| Audience validation | Token reuse against another API |
| HTTPS with a valid certificate | Credential or token exposure in transit |
| Apache reverse proxy + firewall | Direct exposure of the application port |
| Central service logs | Delayed incident investigation |

## Deliverables

- [x] Source code for `frontend/` and `backend/`
- [x] README with the deployed HTTPS URL *(placeholder until you deploy)*
- [ ] Screenshot of a successful authenticated API call → `docs/screenshots/`
- [ ] Screenshot or command output showing the valid certificate → `docs/screenshots/`

See [docs/screenshots/README.md](docs/screenshots/README.md) for exactly what to capture.

## Security notes

- `.env.local`, server credentials, Auth0 secrets and Duck DNS tokens are
  git-ignored and must never be committed.
- An SPA uses the Auth0 **client ID** only. There is no client secret in this
  repository, and there must never be one in browser code.
- CORS allows exactly two origins: `http://localhost:5173` for development and
  the Duck DNS host for production. No wildcards.
- Access tokens are treated as sensitive: never displayed, never logged, never
  stored by hand. The API logs the token *subject*, not the token.
- The service runs as a non-login system account with `NoNewPrivileges`,
  `ProtectSystem=strict` and a loopback-only bind; `unattended-upgrades` keeps
  the OS patched.
