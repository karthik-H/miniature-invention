#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

CAT="auth"; SEV="serious"
TITLE="Missing account lockout or rate limiting on POST /auth/login"

cv_step Given "register a known customer account" $LINENO
SUFFIX=$(cv_unique)
EMAIL="sec-lock-${SUFFIX}@example.com"
PASS="Passw0rd!123"
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,password:$p}')"
if [ "$CV_HTTP_STATUS" != "201" ]; then echo "setup failed: register returned $CV_HTTP_STATUS"; exit 1; fi

cv_step When "send 25 wrong-password login attempts for the same email" $LINENO
N401=0; N429=0; NOTHER=0; FIRST_MS=0; LAST_MS=0
for i in $(seq 1 25); do
  cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "wrong-guess-$i-$SUFFIX" '{email:$e,password:$p}')"
  case "$CV_HTTP_STATUS" in
    401) N401=$((N401 + 1)) ;;
    429|423|403) N429=$((N429 + 1)) ;;
    *) NOTHER=$((NOTHER + 1)) ;;
  esac
  [ "$i" = "1" ] && FIRST_MS=$CV_HTTP_MS
  LAST_MS=$CV_HTTP_MS
done

cv_step Then "check for throttling or lockout signals" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,password:$p}')"
CORRECT=$CV_HTTP_STATUS

cv_step Cleanup "in-memory store, nothing to delete" $LINENO
cv_cleanup_note "$EMAIL"

EVID="25 wrong attempts: 401=${N401} throttled=${N429} other=${NOTHER}; first=${FIRST_MS}ms last=${LAST_MS}ms; correct password after=${CORRECT}"
if [ "$N429" -gt 0 ] || [ "$LAST_MS" -gt $((FIRST_MS + 1000)) ]; then
  printf 'CV_SECURITY|secure|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "$EVID"
else
  printf 'CV_SECURITY|vulnerable|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "$EVID"
fi
exit 0
