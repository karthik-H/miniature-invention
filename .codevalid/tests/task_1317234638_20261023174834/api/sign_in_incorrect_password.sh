#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

# Given
cv_step Given "a registered customer exists with a known password" $LINENO
SUFFIX=$(cv_unique)
EMAIL="cv.badpw.${SUFFIX}@example.com"
PASSWORD="S3cure-pass-${SUFFIX}"
WRONG_PASSWORD="Wrong-pass-${SUFFIX}"
SKU="cv-badpw-${SUFFIX}"
cv_register_user "$EMAIL" "$PASSWORD"

# When
cv_step When "the customer signs in with the registered email and an incorrect password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$WRONG_PASSWORD" '{email:$e,password:$p}')"
LOGIN_STATUS="$CV_HTTP_STATUS"
LOGIN_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the login is rejected, no token is issued and catalog changes stay inaccessible" $LINENO
[ "$LOGIN_STATUS" = "401" ] || cv_fail "expected 401 from POST /auth/login with wrong password got $LOGIN_STATUS: $LOGIN_BODY" $LINENO
TOKEN=$(printf '%s' "$LOGIN_BODY" | jq -r '.token // empty' 2>/dev/null || true)
[ -z "$TOKEN" ] || cv_fail "expected no token in rejected login response got: $LOGIN_BODY" $LINENO
if printf '%s' "$LOGIN_BODY" | jq -e 'has("user")' >/dev/null 2>&1; then
  cv_fail "expected no user in rejected login response got: $LOGIN_BODY" $LINENO
fi
ERR=$(printf '%s' "$LOGIN_BODY" | jq -r '.error // empty' 2>/dev/null || true)
[ -n "$ERR" ] || cv_fail "expected an error message in rejected login response got: $LOGIN_BODY" $LINENO
cv_http POST /products "$(cv_product_payload "$SKU")"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 for POST /products without a session after failed sign-in got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
cv_http GET /products 200
if printf '%s' "$CV_HTTP_BODY" | jq -e --arg s "$SKU" '.products[] | select(.sku == $s)' >/dev/null; then
  cv_fail "expected product $SKU to be absent from catalog after failed sign-in but it exists" $LINENO
fi

# Cleanup
cv_step Cleanup "release data created by this test" $LINENO
cv_cleanup_note "user $EMAIL"

echo "CODEVALID_TEST_ASSERTION_OK:sign_in_incorrect_password"
