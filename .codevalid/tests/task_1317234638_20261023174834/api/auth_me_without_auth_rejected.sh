#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

# Given
cv_step Given "a registered customer exists but the client has not signed in" $LINENO
SUFFIX=$(cv_unique)
EMAIL="cv.noauth.${SUFFIX}@example.com"
PASSWORD="S3cure-pass-${SUFFIX}"
cv_register_user "$EMAIL" "$PASSWORD"

# When
cv_step When "the client calls GET /auth/me without any Authorization header" $LINENO
cv_http GET /auth/me
NOAUTH_STATUS="$CV_HTTP_STATUS"
NOAUTH_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the request is rejected with 401 and no account information is revealed" $LINENO
[ "$NOAUTH_STATUS" = "401" ] || cv_fail "expected 401 from GET /auth/me without auth got $NOAUTH_STATUS: $NOAUTH_BODY" $LINENO
if printf '%s' "$NOAUTH_BODY" | jq -e 'type == "object" and has("user")' >/dev/null 2>&1; then
  cv_fail "expected no user field in unauthenticated response got: $NOAUTH_BODY" $LINENO
fi
case "$NOAUTH_BODY" in *"$EMAIL"*|*"$CV_USER_ID"*) cv_fail "expected no account data in response got: $NOAUTH_BODY" $LINENO ;; esac
ERR=$(printf '%s' "$NOAUTH_BODY" | jq -r '.error // empty' 2>/dev/null || true)
[ -n "$ERR" ] || cv_fail "expected an error message in 401 body got: $NOAUTH_BODY" $LINENO
cv_prereq "non-Bearer Authorization scheme is also rejected" $LINENO
cv_http GET /auth/me -H "Authorization: Basic $(printf '%s:%s' "$EMAIL" "$PASSWORD" | base64 -w0)"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 for Basic auth on GET /auth/me got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
case "$CV_HTTP_BODY" in *"$EMAIL"*|*"$CV_USER_ID"*) cv_fail "expected no account data in response got: $CV_HTTP_BODY" $LINENO ;; esac

# Cleanup
cv_step Cleanup "release data created by this test" $LINENO
cv_cleanup_note "user $EMAIL"

echo "CODEVALID_TEST_ASSERTION_OK:auth_me_without_auth_rejected"
