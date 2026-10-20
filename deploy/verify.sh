#!/usr/bin/env bash
# Runs the Part 7 checks that can be automated and prints the evidence.
#
#   ./verify.sh team4-risk.duckdns.org
set -uo pipefail

DOMAIN=${1:?usage: verify.sh YOUR-SUBDOMAIN.duckdns.org}
pass=0 fail=0
check() { if [[ $1 -eq 0 ]]; then echo "  PASS  $2"; ((pass++)); else echo "  FAIL  $2"; ((fail++)); fi; }

echo "== 1. Unauthenticated request to /api/risk-status returns 401"
code=$(curl -s -o /dev/null -w '%{http_code}' "https://${DOMAIN}/api/risk-status")
echo "  HTTP $code"
[[ "$code" == "401" ]]; check $? "anonymous access denied"

echo "== 2. Request with a junk token is rejected"
code=$(curl -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer not-a-real-token' \
  "https://${DOMAIN}/api/risk-status")
echo "  HTTP $code"
[[ "$code" == "401" ]]; check $? "invalid JWT denied"

echo "== 3. The site answers over HTTPS"
code=$(curl -s -o /dev/null -w '%{http_code}' "https://${DOMAIN}/")
echo "  HTTP $code"
[[ "$code" == "200" ]]; check $? "frontend served over TLS"

echo "== 4. HTTP redirects to HTTPS"
location=$(curl -s -o /dev/null -D - "http://${DOMAIN}/" | grep -i '^location:' | tr -d '\r')
echo "  ${location:-<no redirect>}"
grep -qi 'https://' <<<"${location:-}"; check $? "port 80 redirects to 443"

echo "== 5. Certificate is valid and trusted"
curl -sS -o /dev/null "https://${DOMAIN}/" ; check $? "chain verified by curl"
echo | openssl s_client -connect "${DOMAIN}:443" -servername "${DOMAIN}" 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates

echo "== 6. Port 8080 is not reachable from outside"
timeout 8 bash -c "</dev/tcp/${DOMAIN}/8080" 2>/dev/null
if [[ $? -ne 0 ]]; then check 0 "8080 closed to the public"; else check 1 "8080 is OPEN - fix the firewall"; fi

echo
echo "passed: $pass   failed: $fail"
echo "Still to confirm by hand: a logged-in user can call /api/risk-status from the"
echo "frontend, and 'sudo certbot renew --dry-run' succeeds on the server."
[[ $fail -eq 0 ]]
