#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

# Given
cv_step Given "a registered customer exists and catalog changes are rejected without sign-in" $LINENO
SUFFIX=$(cv_unique)
EMAIL="cv.signin.${SUFFIX}@example.com"
PASSWORD="S3cure-pass-${SUFFIX}"
SKU_BEFORE="cv-pre-${SUFFIX}"
SKU_AFTER="cv-post-${SUFFIX}"
cv_register_user "$EMAIL" "$PASSWORD"
cv_prereq "attempt catalog change before sign-in (no bearer token)" $LINENO
cv_http POST /products "$(cv_product_payload "$SKU_BEFORE")"
if [ "$CV_HTTP_STATUS" != "401" ]; then
  cv_fail "expected 401 for POST /products without sign-in got $CV_HTTP_STATUS" $LINENO
fi

# When
cv_step When "the customer signs in with the registered email and correct password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')" 200
LOGIN_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "an authenticated session is returned and catalog changes are now allowed" $LINENO
TOKEN=$(printf '%s' "$LOGIN_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected non-empty token in login response got: $LOGIN_BODY" $LINENO
[ "$(printf '%s' "$TOKEN" | awk -F. '{print NF}')" = "3" ] || cv_fail "expected JWT with 3 segments got: $TOKEN" $LINENO
GOT_EMAIL=$(printf '%s' "$LOGIN_BODY" | jq -r '.user.email // empty')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got $GOT_EMAIL" $LINENO
GOT_ID=$(printf '%s' "$LOGIN_BODY" | jq -r '.user.id // empty')
[ "$GOT_ID" = "$CV_USER_ID" ] || cv_fail "expected user.id $CV_USER_ID got $GOT_ID" $LINENO
if printf '%s' "$LOGIN_BODY" | jq -e '.user | has("passwordHash")' >/dev/null; then
  cv_fail "expected login response user without passwordHash got: $LOGIN_BODY" $LINENO
fi
cv_http POST /products "$(cv_product_payload "$SKU_AFTER")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 for POST /products after sign-in got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
GOT_SKU=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.sku // empty')
[ "$GOT_SKU" = "$SKU_AFTER" ] || cv_fail "expected created product sku $SKU_AFTER got $GOT_SKU" $LINENO
cv_http GET /products 200
if printf '%s' "$CV_HTTP_BODY" | jq -e --arg s "$SKU_BEFORE" '.products[] | select(.sku == $s)' >/dev/null; then
  cv_fail "expected product $SKU_BEFORE (attempted before sign-in) to be absent from catalog but it exists" $LINENO
fi

# Cleanup
cv_step Cleanup "release data created by this test" $LINENO
cv_cleanup_note "user $EMAIL, product $SKU_AFTER"

echo "CODEVALID_TEST_ASSERTION_OK:successful_customer_sign_in"
