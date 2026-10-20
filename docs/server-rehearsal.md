# Server rehearsal — Parts 5 and 6 on a real Linux host

Before touching a public server, the whole deployment was run on a local Linux
host (Debian-based, systemd, Apache 2.4.68, OpenJDK 21) using **the files in
this repository, unmodified**: `deploy/enterprise-risk-api.service` and
`deploy/enterprise-risk.conf`.

Two things could not be real on a machine with no public IP, and only these two
were substituted:

| Real deployment | Rehearsal stand-in | Why |
| --- | --- | --- |
| Let's Encrypt certificate for the Duck DNS host | Self-signed certificate for `risk.local` | The HTTP-01 challenge needs a public IP and port 80 open from the internet |
| Auth0 tenant as token issuer | Local RSA key + JWKS served on `127.0.0.1:9999` | No tenant existed yet; the validation code path is identical |

Everything else — the service account, the systemd unit, the Apache vhosts, the
reverse proxy, the SPA rewrite, the TLS vhost and the redirect certbot installs
— ran exactly as it will on the server. Local-test values were injected through
a systemd drop-in, so the committed unit keeps its placeholders.

## Setup output

```
=== Part 5: service account and application directory
-rw-r----- 1 riskapi riskapi 27102859 /opt/enterprise-risk-api/app.jar
=== Part 5: the repo's systemd unit, used verbatim
Created symlink '/etc/systemd/system/multi-user.target.wants/enterprise-risk-api.service'
active
=== Part 6: frontend bundle
/var/www/enterprise-risk-frontend/assets/index-Cs-3CJgU.js
/var/www/enterprise-risk-frontend/assets/index-x5HqZo5e.css
/var/www/enterprise-risk-frontend/index.html
=== apachectl configtest
Syntax OK
active
```

## Verification output

**1. Frontend over HTTPS**

```
HTTP 200
```

**2. HTTP redirects to HTTPS** — the rule certbot installs on the port 80 host

```
HTTP/1.1 301 Moved Permanently
Location: https://risk.local/
```

**3. SPA deep link falls back to `index.html`**

```
GET /some/client/route -> HTTP 200  type=text/html
```

**4. `/api/risk-status` with no token** — through the Apache proxy

```
HTTP/1.1 401
WWW-Authenticate: Bearer
```

**5. `/api/risk-status` with a valid token**

```
HTTP/1.1 200
{"status":"protected","control":"JWT validation and authenticated access","subject":"auth0|local-test-user"}
```

**6. Token minted for another audience** — this is audience validation doing its job

```
HTTP 401
WWW-Authenticate: Bearer error="invalid_token",
  error_description="An error occurred while attempting to decode the Jwt: The aud claim is not valid"
```

**7. Token from another issuer**

```
HTTP 401
WWW-Authenticate: Bearer error="invalid_token",
  error_description="An error occurred while attempting to decode the Jwt: The iss claim is not valid"
```

**8. Expired token**

```
HTTP 401
WWW-Authenticate: Bearer error="invalid_token",
  error_description="An error occurred while attempting to decode the Jwt: Jwt expired at 2026-..."
```

**9. Response hardening headers**

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
```

**10. Listening sockets — 8080 is loopback only, 80/443 are the public pair**

```
LISTEN  127.0.0.1:9999          (local JWKS, test only)
LISTEN  [::ffff:127.0.0.1]:8080 (the API)
LISTEN  *:80                    (Apache)
LISTEN  *:443                   (Apache)
```

**11. Certificate served by Apache** — self-signed here, Let's Encrypt on the server

```
subject=CN=risk.local
issuer=CN=risk.local
notBefore=Oct 20 00:50:15 2026 GMT
notAfter=Jan 18 00:50:15 2027 GMT
```

**12. systemd hardening actually applied**

```
✓ NoNewPrivileges=   Service processes cannot acquire new privileges
✓ ProtectSystem=     Service has strict read-only access to the OS file hierarchy
✓ PrivateTmp=        Service has no access to other software's temporary files
✓ ProtectHome=       Service has no access to home directories
→ Overall exposure level: 7.5 (systemd-analyze security)
```

`systemd-analyze` still calls the unit exposed because it does not use
`PrivateUsers`, `SystemCallFilter` or `RestrictNamespaces`. Those would be the
next hardening step; the four directives the workshop relies on are confirmed
in place.

**13. Audit trail — one line per call, caller identified, token never logged**

```
2026-10-19T19:54:07 enterprise-risk-api[148]: com.eci.risk.RiskController -
  risk-status served to subject=auth0|local-test-user audience=[https://enterprise-risk-api]
```

**14. Apache access log**

```
127.0.0.1 - - [19/Oct/2026:19:54:07 -0500] "GET /api/risk-status HTTP/1.1" 401 3316 "-" "curl/8.20.0"
127.0.0.1 - - [19/Oct/2026:19:54:07 -0500] "GET / HTTP/1.1" 200 3411 "-" "curl/8.20.0"
```

## What this proves, and what it does not

Proven: the unit file parses and runs, the vhosts pass `configtest`, the proxy
reaches the API, the SPA rewrite works, the redirect works, and the API accepts
**only** tokens with the right signature, issuer, audience and expiry.

Not proven, because it needs the public host: a trusted Let's Encrypt chain,
`certbot renew --dry-run`, Duck DNS resolution, and that port 8080 is closed
from the internet. Those are items 5, 6 and 7 of
[verification-checklist.md](verification-checklist.md), and `deploy/verify.sh`
runs them once the host exists.

## Reproducing it

The rehearsal used a throwaway RSA key to mint test tokens. That tooling is
deliberately **not** in this repository: a token-minting script sitting next to
a resource server is a liability, and anyone reproducing this should point the
API at their own Auth0 tenant instead.
