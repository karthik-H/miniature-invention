#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

# Given
cv_step Given "a registered customer signs in with the correct email and password" $LINENO
SUFFIX=$(cv_unique)
EMAIL="cv.me.${SUFFIX}@example.com"
PASSWORD="S3cure-pass-${SUFFIX}"
cv_register_user "$EMAIL" "$PASSWORD"
cv_login_user "$EMAIL" "$PASSWORD"

# When
cv_step When "the customer calls GET /auth/me with the sign-in token" $LINENO
cv_http GET /auth/me -H "Authorization: Bearer $CV_TOKEN"

# Then
cv_step Then "the response is 200 with the signed-in customer's identity" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from GET /auth/me got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
GOT_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ "$GOT_ID" = "$CV_USER_ID" ] || cv_fail "expected user.id $CV_USER_ID got '$GOT_ID'" $LINENO
GOT_EMAIL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email // empty')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got '$GOT_EMAIL'" $LINENO
GOT_CREATED=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.createdAt // empty')
[ -n "$GOT_CREATED" ] || cv_fail "expected non-empty user.createdAt got: $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "release data created by this test" $LINENO
cv_cleanup_note "user $EMAIL"

echo "CODEVALID_TEST_ASSERTION_OK:get_current_customer_after_sign_in"
