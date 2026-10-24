#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2689379213_20261023174834/api/_infra.sh

# Given
cv_step Given "the catalog holds zero products (fresh in-memory store, no products created)" $LINENO
# Products live only in the app's in-memory store and there is no delete endpoint,
# so an empty catalog exists only on a freshly started stack. Verify it, or stop.
cv_prereq "confirm the catalog is currently empty" $LINENO
cv_http GET /products 200
PRE_COUNT=$(printf '%s' "$CV_HTTP_BODY" | jq -r '(.items // .products // []) | length' 2>/dev/null || echo invalid)
[ "$PRE_COUNT" = "0" ] || cv_fail "expected an empty catalog to start from (needs a fresh stack) got $PRE_COUNT products" $LINENO

# When
cv_step When "anonymous client requests GET /products" $LINENO
cv_http GET /products

# Then
cv_step Then "response is 200 JSON with an empty product list" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected HTTP 200 got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e . >/dev/null 2>&1 || cv_fail "expected JSON body got $CV_HTTP_BODY" $LINENO
TYPE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.items | type')
[ "$TYPE" = "array" ] || cv_fail "expected .items to be an array got $TYPE" $LINENO
LEN=$(printf '%s' "$CV_HTTP_BODY" | jq '.items | length')
[ "$LEN" = "0" ] || cv_fail "expected empty .items list got $LEN products" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
[ -z "$ERR" ] || cv_fail "expected no error field for an empty catalog got $ERR" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "no data created"

echo "CODEVALID_TEST_ASSERTION_OK:browse_catalog_when_empty"
