#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2689379213_20261023174834/api/_infra.sh

# Given
cv_step Given "a well-formed product id that matches no product" $LINENO
MISSING_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || printf '00000000-0000-4000-8000-%012d' "$(( $(date +%s) % 1000000000000 ))")
cv_prereq "confirm $MISSING_ID is absent from the catalog" $LINENO
cv_http GET /products 200
HIT=$(printf '%s' "$CV_HTTP_BODY" | jq --arg id "$MISSING_ID" '[.products[] | select(.id==$id)] | length')
[ "$HIT" = "0" ] || cv_fail "expected id $MISSING_ID to be unused got $HIT matches" $LINENO

# When
cv_step When "anonymous visitor requests GET /products/{missing id}" $LINENO
cv_http GET "/products/${MISSING_ID}"

# Then
cv_step Then "response is 404 with an error message and no auth challenge" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected HTTP 404 got $CV_HTTP_STATUS" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty' 2>/dev/null || true)
[ -n "$ERR" ] || cv_fail "expected an error message in body got $CV_HTTP_BODY" $LINENO
HASID=$(printf '%s' "$CV_HTTP_BODY" | jq 'has("id") or has("sku")')
[ "$HASID" = "false" ] || cv_fail "expected no product fields in 404 body got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "no data created"

echo "CODEVALID_TEST_ASSERTION_OK:nonexistent_product_id_returns_not_found"
