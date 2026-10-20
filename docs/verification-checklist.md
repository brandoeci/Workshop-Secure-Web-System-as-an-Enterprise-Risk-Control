# Part 7 — Verification checklist

Run `./deploy/verify.sh YOUR-SUBDOMAIN.duckdns.org` for the automated items,
then tick the two that need a browser and a shell on the server.

| # | Check | How to prove it | Automated? |
| --- | --- | --- | --- |
| 1 | Unauthenticated requests to `/api/risk-status` return 401 | `curl -i https://HOST/api/risk-status` | yes — check 1 |
| 2 | A logged-in user can call `/api/risk-status` from the frontend | Press **Call protected API**; screenshot the JSON | no |
| 3 | The backend validates the JWT issuer and audience | `curl -i -H 'Authorization: Bearer junk' https://HOST/api/risk-status` → 401; the `issuer-uri` and `audiences` properties | yes — check 2 |
| 4 | The application is available at `https://HOST` | `curl -I https://HOST/` → 200 | yes — check 3 |
| 5 | The browser shows a valid certificate and the HTTPS lock | Click the lock, screenshot the certificate; `openssl s_client` prints issuer and dates | partly — check 5 |
| 6 | Port 8080 is not reachable from the public internet | `nc -vz HOST 8080` or `curl --max-time 5 http://HOST:8080/actuator/health` → refused or timeout | yes — check 6 |
| 7 | `sudo certbot renew --dry-run` succeeds | Run it on the server; keep the output | no — needs server access |

## Expected output, item by item

**1 — anonymous request denied**

```
$ curl -i https://team4-risk.duckdns.org/api/risk-status
HTTP/1.1 401
WWW-Authenticate: Bearer
```

**2 — authenticated request**

```json
{
  "status": "protected",
  "subject": "auth0|6712...",
  "control": "JWT validation and authenticated access"
}
```

**3 — forged token denied**

```
$ curl -i -H 'Authorization: Bearer not-a-real-token' https://team4-risk.duckdns.org/api/risk-status
HTTP/1.1 401
WWW-Authenticate: Bearer error="invalid_token", error_description="An error occurred while attempting to decode the Jwt: Malformed token"
```

**5 — certificate**

```
$ echo | openssl s_client -connect team4-risk.duckdns.org:443 \
    -servername team4-risk.duckdns.org 2>/dev/null | openssl x509 -noout -issuer -subject -dates
issuer=C = US, O = Let's Encrypt, CN = R11
subject=CN = team4-risk.duckdns.org
notBefore=...
notAfter=...
```

**6 — application port closed**

```
$ nc -vz team4-risk.duckdns.org 8080
nc: connect to team4-risk.duckdns.org port 8080 (tcp) failed: Connection timed out
```

**7 — renewal**

```
$ sudo certbot renew --dry-run
Congratulations, all simulated renewals succeeded
```

## If something fails

| Failing item | Look at |
| --- | --- |
| 1 or 3 returns 200 | The security filter chain was not applied, or a permissive `permitAll()` crept in. Re-read [SecurityConfig.java](../backend/src/main/java/com/eci/risk/SecurityConfig.java). |
| 2 returns 401 | Issuer trailing slash, audience mismatch, or the backend was not restarted. See [auth0-setup.md](auth0-setup.md#troubleshooting). |
| 2 fails with a CORS error | `APP_CORS_ALLOWED_ORIGINS` does not include the exact origin the browser is on. |
| 4 times out | Duck DNS is not pointing at the host, or ports 80/443 are closed at the provider. |
| 5 shows a self-signed or expired certificate | `certbot --apache` did not complete; check `/var/log/letsencrypt/letsencrypt.log`. |
| 6 answers | The firewall allows 8080, or the service is bound to `0.0.0.0`. Fix both. |
| 7 fails | Port 80 is closed, so the HTTP-01 challenge cannot reach the server. |
