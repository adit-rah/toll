#!/bin/bash
# Starts the Worker on 127.0.0.1:8787 with a local D1 holding the App Review account, its friends and
# eight weeks of their events, then signs in as that account. Prints `API=…` and `TOKEN=…` lines for
# render.sh. The Worker keeps running in the background; its log is in $LOG.
set -euo pipefail
cd "$(dirname "$0")/../../api"
PORT=${PORT:-8787}
CODE=000000
ADMIN=render
LOG=${LOG:-/tmp/toll-render-api.log}
STATE=.wrangler/render

[ -d node_modules ] || npm ci --no-audit --no-fund >&2
rm -rf "$STATE"
# The seed prints the recompute call that turns its events into rollups (DEPLOY.md §7); keep its body.
RECOMPUTE=$(node scripts/seed-review.mjs | sed -n "s/.*-d '\(.*\)'$/\1/p")
d1() { npx wrangler d1 "$@" --local --persist-to "$STATE" >&2; }
d1 migrations apply toll
d1 execute toll --file seed/schools-launch.sql
d1 execute toll --file seed/review.sql

# Throwaway values for the secrets a deployed Worker gets from `wrangler secret put` (DEPLOY.md §4).
npx wrangler dev --ip 127.0.0.1 --port "$PORT" --persist-to "$STATE" \
  --var REVIEW_CODE:$CODE OTP_PEPPER:render CONTACTS_SALT:render ADMIN_TOKEN:$ADMIN \
  TOKEN_ENC_KEY:dGVzdC1rZXktdGVzdC1rZXktdGVzdC1rZXktdGVzdC0= >"$LOG" 2>&1 &
for _ in $(seq 60); do
  curl -sf "http://127.0.0.1:$PORT/health" >/dev/null && break
  sleep 1
done
curl -sf "http://127.0.0.1:$PORT/health" >/dev/null || { tail -40 "$LOG" >&2; exit 1; }

curl -sf -X POST "http://127.0.0.1:$PORT/v1/admin/recompute" -H "authorization: Bearer $ADMIN" \
  -H 'content-type: application/json' -d "$RECOMPUTE" >/dev/null

EMAIL=$(sed -n 's/.*"REVIEW_EMAIL": *"\([^"]*\)".*/\1/p' wrangler.jsonc | head -1)
post() { curl -sf -H 'content-type: application/json' "http://127.0.0.1:$PORT/v1/$1" -d "$2"; }
post auth/email/start "{\"email\":\"$EMAIL\"}" >/dev/null
TOKEN=$(post auth/email/verify "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"deviceId\":\"render\"}" |
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).token))')
echo "API=http://127.0.0.1:$PORT/v1"
echo "TOKEN=$TOKEN"
