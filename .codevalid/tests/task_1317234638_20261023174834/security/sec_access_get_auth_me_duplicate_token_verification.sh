#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

CAT="access"; SEV="critical"
TITLE="Duplicate token verification in GET /auth/me bypasses requireAuth validation"

cv_step Given "register a customer to obtain a valid JWT" $LINENO
SUFFIX=$(cv_unique)
EMAIL="sec-dup-${SUFFIX}@example.com"
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" '{email:$e,password:"Passw0rd!123"}')"
if [ "$CV_HTTP_STATUS" != "201" ]; then echo "setup failed: register returned $CV_HTTP_STATUS"; exit 1; fi
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || { echo "setup failed: no token"; exit 1; }

cv_step When "call GET /auth/me with malformed Authorization headers that requireAuth should reject" $LINENO
EVIDENCE=""
BYPASS=0
declare -a HEADERS=(
  "$TOKEN"
  "Basic $TOKEN"
  "Bearer $TOKEN extra"
  "Bearer$TOKEN"
  "Bearer $TOKEN $TOKEN"
  "Token $TOKEN"
)
i=0
for h in "${HEADERS[@]}"; do
  i=$((i + 1))
  cv_http GET /auth/me -H "Authorization: $h"
  EVIDENCE="${EVIDENCE}h${i}=${CV_HTTP_STATUS} "
  if [ "$CV_HTTP_STATUS" = "200" ] && printf '%s' "$CV_HTTP_BODY" | jq -e '.user != null' >/dev/null 2>&1; then
    BYPASS=1
  fi
done

cv_step Then "decide whether any malformed header reached the handler" $LINENO
cv_http GET /auth/me -H "Authorization: Bearer $TOKEN"
EVIDENCE="${EVIDENCE}well-formed=${CV_HTTP_STATUS}"

cv_step Cleanup "in-memory store, nothing to delete" $LINENO
cv_cleanup_note "$EMAIL"

if [ "$BYPASS" = "1" ]; then
  printf 'CV_SECURITY|vulnerable|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "malformed Authorization header returned 200 with user: ${EVIDENCE}"
else
  printf 'CV_SECURITY|secure|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "all malformed headers rejected before handler: ${EVIDENCE}"
fi
exit 0
