# Risk-control reflection

Each row is a control that exists in this repository, the risk it reduces, and
the artefact that proves it works. "Evidence" means something you can run or
show, not an assertion.

| Control | Risk reduced | Evidence | Where it lives |
| --- | --- | --- | --- |
| Auth0 authentication | Impersonation and weak credential handling — the app stores no passwords, so it cannot leak any | Auth0 Universal Login flow; the API echoes back the authenticated `sub` | [frontend/src/main.jsx](../frontend/src/main.jsx) |
| JWT validation at the API | Unauthorized API access | `401` with no token and `401` with a forged token (`verify.sh` checks 1 and 2); `anonymousRequestIsRejected` test | [SecurityConfig.java](../backend/src/main/java/com/eci/risk/SecurityConfig.java) |
| Issuer validation | Tokens minted by any other identity provider | `issuer-uri` pins the tenant, and the signature is checked against that tenant's published JWKS | [application.properties](../backend/src/main/resources/application.properties) |
| Audience validation | Token reuse against another API — a token issued for a different audience cannot be replayed here | `jwt.audiences=https://enterprise-risk-api` | [application.properties](../backend/src/main/resources/application.properties) |
| Deny by default | Forgotten endpoints silently exposed | `anyRequest().denyAll()`; `undeclaredPathsAreDenied` test | [SecurityConfig.java](../backend/src/main/java/com/eci/risk/SecurityConfig.java) |
| Explicit CORS allow-list | A hostile page calling the API with a victim's token | Two exact origins, `GET` only, no wildcard | [SecurityConfig.java](../backend/src/main/java/com/eci/risk/SecurityConfig.java) |
| HTTPS with a valid certificate | Credential or token exposure in transit | Browser certificate details; `openssl s_client` output (`verify.sh` check 5) | [enterprise-risk.conf](../deploy/enterprise-risk.conf) + certbot |
| HTTP to HTTPS redirect | A first request travelling in cleartext | `verify.sh` check 4 | certbot's rewrite on the port 80 host |
| Certificate auto-renewal | Outage, and the habit of clicking through browser warnings | `sudo certbot renew --dry-run`; the certbot systemd timer | certbot |
| Apache reverse proxy | Direct exposure of the application port | Only 80 and 443 answer publicly; `verify.sh` check 6 | [enterprise-risk.conf](../deploy/enterprise-risk.conf) |
| Loopback bind plus firewall | The same risk defended twice, so one misconfiguration is not enough | `SERVER_ADDRESS=127.0.0.1`; `ufw status verbose` | [service unit](../deploy/enterprise-risk-api.service), [server-bootstrap.sh](../deploy/server-bootstrap.sh) |
| Least-privilege service account | A compromised process writing anywhere on the host | `riskapi` has no shell and no home; `ProtectSystem=strict`, `NoNewPrivileges` | [service unit](../deploy/enterprise-risk-api.service) |
| Minimal actuator surface | Configuration and heap disclosure | Only `/actuator/health` is exposed, with `show-details=never` | [application.properties](../backend/src/main/resources/application.properties) |
| Central service logs | Delayed incident investigation | `journalctl -u enterprise-risk-api` shows caller subject and timestamp per request | [RiskController.java](../backend/src/main/java/com/eci/risk/RiskController.java) |
| Secrets kept out of git | Credential leak through the repository | `.gitignore` covers `.env.local`, keys and tokens; the SPA ships only a client ID | [.gitignore](../.gitignore) |
| OS patching | Known, already-fixed vulnerabilities | `unattended-upgrades` enabled by the bootstrap script | [server-bootstrap.sh](../deploy/server-bootstrap.sh) |

## Authentication, authorization, and which layer owns what

| Question | Answered by | Where |
| --- | --- | --- |
| Who is this person? | Auth0, against its user database | Universal Login, outside our code |
| Is this token genuine, ours, and unexpired? | Spring Security's JWT decoder | Backend, every request |
| May this caller reach this path? | The authorization rules | `SecurityConfig` |
| Can anyone read the token in transit? | TLS | Apache + Let's Encrypt |
| Who called what, and when? | The service journal | `journalctl` |

The frontend answers none of these. It is a client that holds a token and shows
a result; it is not a security boundary, and nothing in this system trusts it.

## What this system still does not control

Saying so is part of the exercise. The workshop scope stops before:

- **Permission enforcement.** `read:risk` is requested and granted, but the API
  only requires *authentication*, not that specific scope. Enforcing it means a
  `JwtAuthenticationConverter` mapping the `scope` claim to authorities, plus
  `.hasAuthority("SCOPE_read:risk")` on the endpoint.
- **Rate limiting and abuse control.** A valid token can call the endpoint as
  often as it likes.
- **Log retention and alerting.** The journal is local and rotates. Nothing
  ships it off the host, and nothing alerts on anomalies.
- **Token theft on the client.** Tokens live in the SPA's memory, which is the
  right place for them, but an XSS bug in the page would still reach them. A
  strict Content-Security-Policy is the next control to add.
- **Backup and recovery.** There is no state to lose here, which is why it is
  cheap to ignore — and why that stops being true the moment a database appears.
