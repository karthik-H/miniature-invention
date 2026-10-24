#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

# The test container cannot restart the app process. A restart clears the in-memory user store
# while previously issued JWTs keep a valid signature, so the post-restart state is reproduced by a
# validly signed token (same app secret, same claims shape) whose subject is not in the store.

# Given
cv_step Given "a customer signs in, /auth/me confirms identity, and an old token for a cleared account exists" $LINENO
SUFFIX=$(cv_unique)
EMAIL="cv.restart.${SUFFIX}@example.com"
PASSWORD="S3cure-pass-${SUFFIX}"
cv_register_user "$EMAIL" "$PASSWORD"
cv_login_user "$EMAIL" "$PASSWORD"
cv_http GET /auth/me 200 -H "Authorization: Bearer $CV_TOKEN"
PRE_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ "$PRE_ID" = "$CV_USER_ID" ] || cv_fail "expected pre-restart /auth/me user.id $CV_USER_ID got '$PRE_ID'" $LINENO
cv_prereq "mint a token as issued before restart for an account no longer in memory" $LINENO
GONE_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || printf '00000000-0000-4000-8000-%012d' "$((SUFFIX % 1000000000000))")
GONE_EMAIL="cv.gone.${SUFFIX}@example.com"
NOW=$(date +%s)
OLD_TOKEN=$(cv_mint_jwt "$(jq -nc --arg s "$GONE_ID" --arg e "$GONE_EMAIL" --argjson iat "$NOW" --argjson exp $((NOW + 3600)) '{sub:$s,email:$e,iat:$iat,exp:$exp}')") \
  || cv_fail "expected to mint the pre-restart JWT (openssl) got failure" $LINENO
cv_prereq "control: a minted token for the live customer is accepted (proves the signature is valid)" $LINENO
CTRL=$(cv_mint_jwt "$(jq -nc --arg s "$CV_USER_ID" --arg e "$EMAIL" --argjson iat "$NOW" --argjson exp $((NOW + 3600)) '{sub:$s,email:$e,iat:$iat,exp:$exp}')") \
  || cv_fail "expected to mint control JWT got failure" $LINENO
cv_http GET /auth/me 200 -H "Authorization: Bearer $CTRL"

# When
cv_step When "GET /auth/me is called with the old token after account state was cleared" $LINENO
cv_http GET /auth/me -H "Authorization: Bearer $OLD_TOKEN"

# Then
cv_step Then "the request is rejected with 401 and no previous identity is returned" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 for old token after restart got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
if printf '%s' "$CV_HTTP_BODY" | jq -e 'type == "object" and has("user")' >/dev/null 2>&1; then
  cv_fail "expected no user field after restart got: $CV_HTTP_BODY" $LINENO
fi
case "$CV_HTTP_BODY" in *"$GONE_EMAIL"*|*"$GONE_ID"*) cv_fail "expected no previous identity in response got: $CV_HTTP_BODY" $LINENO ;; esac

# Cleanup
cv_step Cleanup "release data created by this test" $LINENO
cv_cleanup_note "user $EMAIL"

echo "CODEVALID_TEST_ASSERTION_OK:auth_me_after_service_restart_requires_re_sign_in"
