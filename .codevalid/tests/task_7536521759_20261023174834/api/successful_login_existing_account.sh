#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_7536521759_20261023174834/api/_infra.sh

# Given
cv_step Given "an account registered while the service is running" $LINENO
EMAIL=$(cv_unique_email "login_existing")
PASSWORD="LoginPass456!"
cv_register_user "$EMAIL" "$PASSWORD"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected register HTTP 201 got $CV_HTTP_STATUS" $LINENO
USER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$USER_ID" ] || cv_fail "expected registered user.id got empty" $LINENO

# When
cv_step When "POST /auth/login with the registered email and password" $LINENO
cv_login_user "$EMAIL" "$PASSWORD"

# Then
cv_step Then "200 with a token for the same account" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected HTTP 200 got $CV_HTTP_STATUS" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected non-empty token got '$TOKEN'" $LINENO
PARTS=$(printf '%s' "$TOKEN" | awk -F. '{print NF}')
[ "$PARTS" = "3" ] || cv_fail "expected JWT with 3 parts got $PARTS" $LINENO
LOGIN_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ "$LOGIN_ID" = "$USER_ID" ] || cv_fail "expected user.id $USER_ID got '$LOGIN_ID'" $LINENO
LOGIN_EMAIL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email // empty')
[ "$LOGIN_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got '$LOGIN_EMAIL'" $LINENO
cv_prereq "the token establishes a session accepted by a protected route" $LINENO
SKU="login-$(date +%s%N)"
PBODY=$(jq -nc --arg s "$SKU" '{name:"Login check",description:"",priceCents:100,sku:$s}')
cv_http POST /products "$PBODY" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected token accepted by POST /products (201) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: users/products live in the app's in-memory store with no delete endpoint; values are unique" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:successful_login_existing_account"
