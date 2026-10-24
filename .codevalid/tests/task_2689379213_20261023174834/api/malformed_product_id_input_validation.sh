#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2689379213_20261023174834/api/_infra.sh

# Given
cv_step Given "a malformed product id (product ids are UUIDs; this is not one)" $LINENO
BAD_ID="not-a-uuid-$(date +%s)"
echo "malformed id: $BAD_ID"

# When
cv_step When "anonymous visitor requests GET /products/{malformed id}" $LINENO
cv_http GET "/products/${BAD_ID}"

# Then
cv_step Then "response is a 400 validation error with a JSON error message, no auth challenge" $LINENO
case "$CV_HTTP_STATUS" in 401|403) cv_fail "expected no auth challenge for public endpoint got $CV_HTTP_STATUS" $LINENO ;; esac
case "$CV_HTTP_STATUS" in 400|422) ;; *) cv_fail "expected HTTP 400 (or 422) validation error for malformed id got $CV_HTTP_STATUS" $LINENO ;; esac
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty' 2>/dev/null || true)
[ -n "$ERR" ] || cv_fail "expected an error message in JSON body got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "no data created"

echo "CODEVALID_TEST_ASSERTION_OK:malformed_product_id_input_validation"
