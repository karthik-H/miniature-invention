#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_7536521759_20261023174834/api/_infra.sh

# Given
cv_step Given "a unique email address and a valid 8-72 character password" $LINENO
EMAIL=$(cv_unique_email "register_basic")
PASSWORD="ValidPass123!"
cv_prereq "confirm the app is reachable" $LINENO
cv_http GET /health 200

# When
cv_step When "POST /auth/register with the unique email and valid password" $LINENO
cv_register_user "$EMAIL" "$PASSWORD"

# Then
cv_step Then "201 with a token and a user carrying a usable id and the registered email" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected HTTP 201 got $CV_HTTP_STATUS" $LINENO
USER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$USER_ID" ] || cv_fail "expected non-empty user.id got '$USER_ID'" $LINENO
RESP_EMAIL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email // empty')
[ "$RESP_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got '$RESP_EMAIL'" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected non-empty token got '$TOKEN'" $LINENO
HAS_HASH=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user | (has("passwordHash") or has("password"))')
[ "$HAS_HASH" = "false" ] || cv_fail "expected no password/passwordHash in user got present" $LINENO
cv_prereq "the new account can log in with the same credentials" $LINENO
cv_login_user "$EMAIL" "$PASSWORD"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected login HTTP 200 for registered account got $CV_HTTP_STATUS" $LINENO
LOGIN_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ "$LOGIN_ID" = "$USER_ID" ] || cv_fail "expected login user.id $USER_ID got '$LOGIN_ID'" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: users live in the app's in-memory store with no delete endpoint; email is unique" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:register_success_basic"
