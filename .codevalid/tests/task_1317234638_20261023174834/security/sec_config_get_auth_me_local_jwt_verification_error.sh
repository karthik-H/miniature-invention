#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

CAT="config"; SEV="warning"
TITLE="Local JWT verification errors in GET_auth_me are not caught"

cv_step Given "check the app is reachable" $LINENO
cv_http GET /health
if [ "$CV_HTTP_STATUS" != "200" ]; then echo "app unreachable: /health returned $CV_HTTP_STATUS"; exit 1; fi

cv_step When "send GET /auth/me with malformed and tampered tokens" $LINENO
BAD=0; EVID=""
TAMPERED=$(cv_mint_jwt '{"sub":"nobody","email":"x@example.com"}' "wrong-secret")
NOSIG=$(printf '%s' '{"alg":"none","typ":"JWT"}' | _cv_b64url).$(printf '%s' '{"sub":"x"}' | _cv_b64url).
declare -a TOKENS=( "not-a-jwt" "a.b.c" "$TAMPERED" "$NOSIG" "%%%%" )
i=0
for t in "${TOKENS[@]}"; do
  i=$((i + 1))
  cv_http GET /auth/me -H "Authorization: Bearer $t"
  EVID="${EVID}t${i}=${CV_HTTP_STATUS} "
  if [ "$CV_HTTP_STATUS" != "401" ]; then BAD=1; fi
  if printf '%s' "$CV_HTTP_BODY" | grep -Eqi 'stack|at [A-Za-z].*\(|JsonWebTokenError|jwt malformed|invalid signature'; then
    BAD=1; EVID="${EVID}(leak) "
  fi
done

cv_step Then "decide whether errors were mapped to generic 401" $LINENO

cv_step Cleanup "nothing created" $LINENO

if [ "$BAD" = "1" ]; then
  printf 'CV_SECURITY|vulnerable|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "non-401 or leaky response to bad tokens: ${EVID}"
else
  printf 'CV_SECURITY|secure|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "all bad tokens got generic 401 JSON: ${EVID}"
fi
exit 0
