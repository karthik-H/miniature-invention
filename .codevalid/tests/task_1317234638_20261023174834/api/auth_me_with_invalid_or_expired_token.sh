#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

# Given
cv_step Given "a signed-in customer, plus a tampered token and an expired token for that customer" $LINENO
SUFFIX=$(cv_unique)
EMAIL="cv.badtok.${SUFFIX}@example.com"
PASSWORD="S3cure-pass-${SUFFIX}"
cv_register_user "$EMAIL" "$PASSWORD"
cv_login_user "$EMAIL" "$PASSWORD"
cv_prereq "build a tampered token (signature altered)" $LINENO
SIG=${CV_TOKEN##*.}
FIRST=${SIG:0:1}
if [ "$FIRST" = "A" ]; then NEWC="B"; else NEWC="A"; fi
TAMPERED="${CV_TOKEN%.*}.${NEWC}${SIG:1}"
cv_prereq "mint an expired token for the same customer" $LINENO
NOW=$(date +%s)
EXPIRED=$(cv_mint_jwt "$(jq -nc --arg s "$CV_USER_ID" --arg e "$EMAIL" --argjson iat $((NOW - 7200)) --argjson exp $((NOW - 3600)) '{sub:$s,email:$e,iat:$iat,exp:$exp}')") \
  || cv_fail "expected to mint an expired JWT (openssl) got failure" $LINENO
[ -n "$EXPIRED" ] || cv_fail "expected non-empty expired JWT got empty" $LINENO
cv_prereq "control: a same-secret token that is not expired is accepted (proves minting is valid)" $LINENO
FRESH=$(cv_mint_jwt "$(jq -nc --arg s "$CV_USER_ID" --arg e "$EMAIL" --argjson iat "$NOW" --argjson exp $((NOW + 3600)) '{sub:$s,email:$e,iat:$iat,exp:$exp}')") \
  || cv_fail "expected to mint a control JWT got failure" $LINENO
cv_http GET /auth/me -H "Authorization: Bearer $FRESH"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected control minted token to be accepted with 200 got $CV_HTTP_STATUS: $CV_HTTP_BODY (secret mismatch?)" $LINENO

# When
cv_step When "the customer calls GET /auth/me with a garbage, a tampered and an expired token" $LINENO
cv_http GET /auth/me -H "Authorization: Bearer not-a-real-token-${SUFFIX}"
GARBAGE_STATUS="$CV_HTTP_STATUS"; GARBAGE_BODY="$CV_HTTP_BODY"
cv_http GET /auth/me -H "Authorization: Bearer $TAMPERED"
TAMPER_STATUS="$CV_HTTP_STATUS"; TAMPER_BODY="$CV_HTTP_BODY"
cv_http GET /auth/me -H "Authorization: Bearer $EXPIRED"
EXP_STATUS="$CV_HTTP_STATUS"; EXP_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "every request fails with 401 and no user identity is returned" $LINENO
for pair in "garbage|$GARBAGE_STATUS|$GARBAGE_BODY" "tampered|$TAMPER_STATUS|$TAMPER_BODY" "expired|$EXP_STATUS|$EXP_BODY"; do
  KIND=${pair%%|*}; REST=${pair#*|}; ST=${REST%%|*}; BD=${REST#*|}
  [ "$ST" = "401" ] || cv_fail "expected 401 for $KIND token on GET /auth/me got $ST: $BD" $LINENO
  if printf '%s' "$BD" | jq -e 'type == "object" and has("user")' >/dev/null 2>&1; then
    cv_fail "expected no user field for $KIND token got: $BD" $LINENO
  fi
  case "$BD" in *"$EMAIL"*|*"$CV_USER_ID"*) cv_fail "expected no account data for $KIND token got: $BD" $LINENO ;; esac
done

# Cleanup
cv_step Cleanup "release data created by this test" $LINENO
cv_cleanup_note "user $EMAIL"

echo "CODEVALID_TEST_ASSERTION_OK:auth_me_with_invalid_or_expired_token"
