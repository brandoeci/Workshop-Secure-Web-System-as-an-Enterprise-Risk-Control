# Local verification run

Output captured on a development machine from the packaged JAR
(`backend/target/enterprise-risk-api.jar`), before any server deployment. It
covers every control that does not depend on Duck DNS, Apache or TLS; the
remaining items are in [verification-checklist.md](verification-checklist.md).

The JWKS URI below points at a public key set only so the application can start
without a real tenant; in every real run the issuer URI alone is enough, because
Auth0 publishes its JWKS under that issuer.

```bash
java -jar target/enterprise-risk-api.jar \
  --spring.security.oauth2.resourceserver.jwt.issuer-uri=https://test-tenant.us.auth0.com/ \
  --spring.security.oauth2.resourceserver.jwt.jwk-set-uri=https://www.googleapis.com/oauth2/v3/certs
```

## Tests

```
$ ./mvnw -B clean package
[INFO] Tests run: 4, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

| Test | Control proved |
| --- | --- |
| `anonymousRequestIsRejected` | `/api/**` denies callers with no token |
| `authenticatedRequestReturnsTheCallerSubject` | A valid token yields the caller's own `sub` |
| `healthEndpointIsPublic` | The liveness probe stays reachable |
| `undeclaredPathsAreDenied` | `anyRequest().denyAll()` really is the default |

## Running service

```
$ curl -s http://127.0.0.1:8080/actuator/health
{"status":"UP"}

$ curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/api/risk-status
401

$ curl -s -D - -o /dev/null -H 'Authorization: Bearer not-a-real-token' \
    http://127.0.0.1:8080/api/risk-status | grep -i www-authenticate
WWW-Authenticate: Bearer error="invalid_token",
  error_description="An error occurred while attempting to decode the Jwt: Malformed token",
  error_uri="https://tools.ietf.org/html/rfc6750#section-3.1"

$ curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/internal/secrets
401

$ curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/actuator/env
401
```

An undeclared path and a disabled actuator endpoint answer `401`, not `404`:
the filter chain stops the request before any handler lookup, so the API does
not even disclose which paths exist.

## Loopback-only bind

```
$ netstat -ano | grep LISTENING | grep :8080
  TCP    127.0.0.1:8080         0.0.0.0:0              LISTENING       41536
```

`127.0.0.1:8080`, not `0.0.0.0:8080`. The application port cannot be reached
from another host even before the firewall has an opinion about it.

## Frontend build

```
$ npm ci && npm run build
vite v5.4.11 building for production...
✓ 32 modules transformed.
dist/index.html                   0.40 kB
dist/assets/index-*.css           1.11 kB
dist/assets/index-*.js          193.94 kB │ gzip: 62.27 kB
✓ built in 869ms
```

The bundle contains the Auth0 domain, client ID and audience — identifiers, not
credentials. There is no client secret anywhere in `frontend/`.

## Still to be verified after deployment

The authenticated happy path needs a real Auth0 tenant and a test user, and the
TLS, redirect, certificate-renewal and public-port items need the Duck DNS host.
Run `./deploy/verify.sh YOUR-SUBDOMAIN.duckdns.org` once it is up.
