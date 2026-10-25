#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

# Given
cv_step Given "a registered customer who has signed in" $LINENO
SUFFIX=$(cv_unique)
EMAIL="cv.privacy.${SUFFIX}@example.com"
PASSWORD="Pr1vate-pass-${SUFFIX}"
cv_register_user "$EMAIL" "$PASSWORD"
cv_login_user "$EMAIL" "$PASSWORD"

# When
cv_step When "the customer calls GET /auth/me" $LINENO
cv_http GET /auth/me 200 -H "Authorization: Bearer $CV_TOKEN"
BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the identity is returned without any password or hash data" $LINENO
GOT_EMAIL=$(printf '%s' "$BODY" | jq -r '.user.email // empty')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got '$GOT_EMAIL'" $LINENO
SENSITIVE=$(printf '%s' "$BODY" | jq -r '[paths | map(tostring) | join(".") | select(test("pass|hash|salt|secret"; "i"))] | join(",")')
[ -z "$SENSITIVE" ] || cv_fail "expected no password/hash/secret fields in response got fields: $SENSITIVE" $LINENO
case "$BODY" in *"$PASSWORD"*) cv_fail "expected plaintext password absent from response but it was present" $LINENO ;; esac
if printf '%s' "$BODY" | grep -Eq '\$2[aby]\$[0-9]{2}\$'; then
  cv_fail "expected no bcrypt hash in response got: $BODY" $LINENO
fi
KEYS=$(printf '%s' "$BODY" | jq -r '.user | keys | sort | join(",")')
[ "$KEYS" = "createdAt,email,id" ] || cv_fail "expected user keys createdAt,email,id only got $KEYS" $LINENO

# Cleanup
cv_step Cleanup "release data created by this test" $LINENO
cv_cleanup_note "user $EMAIL"

echo "CODEVALID_TEST_ASSERTION_OK:auth_me_response_preserves_password_privacy"
