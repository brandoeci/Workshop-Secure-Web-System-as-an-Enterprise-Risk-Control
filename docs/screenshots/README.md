# Screenshots (deliverables)

Two images are required by the workshop. Drop them in this folder with these
exact names so the links in the root README resolve:

| File | What it must show |
| --- | --- |
| `authenticated-api-call.png` | The frontend after pressing **Call protected API**, with the JSON response visible and the signed-in user's name on screen. The address bar must show the `https://...duckdns.org` host. |
| `valid-certificate.png` | The browser's certificate panel (click the lock) showing the Let's Encrypt issuer, the Duck DNS common name and the validity dates — or a terminal with the `openssl s_client` output from the verification checklist. |

Optional but good evidence:

| File | What it shows |
| --- | --- |
| `unauthenticated-401.png` | **Call without a token** returning HTTP 401 — the control working. |
| `verify-script.png` | The output of `./deploy/verify.sh YOUR-SUBDOMAIN.duckdns.org`. |
| `journal-audit.png` | `journalctl -u enterprise-risk-api` showing one request per line with its caller subject. |

**Before you screenshot anything:** make sure no access token is visible. Close
the browser devtools Network tab, and do not capture the Auth0 dashboard with
secrets on screen. A token in a screenshot is a leaked credential.
