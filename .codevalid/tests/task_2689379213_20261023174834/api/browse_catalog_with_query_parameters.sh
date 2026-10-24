#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2689379213_20261023174834/api/_infra.sh

# Given
cv_step Given "at least three products exist in the public catalog" $LINENO
SFX=$(cv_suffix)
cv_register_user "seller_${SFX}@example.com" "Passw0rd!${SFX}" $LINENO
TOKEN=$CV_TOKEN
IDS=()
for n in 1 2 3; do
  cv_create_product "$TOKEN" "Paged ${n} ${SFX}" "Paged item ${n}" $((100 * n)) "SKU-Q${n}-${SFX}" $LINENO
  IDS+=("$CV_PRODUCT_ID")
done
cv_prereq "baseline full catalog" $LINENO
cv_http GET /products 200
TOTAL=$(printf '%s' "$CV_HTTP_BODY" | jq '.items | length')
[ "$TOTAL" -ge 3 ] || cv_fail "expected at least 3 products in baseline catalog got $TOTAL" $LINENO
ALL_IDS=$(printf '%s' "$CV_HTTP_BODY" | jq -c '[.items[].id]')

# When
cv_step When "anonymous client requests GET /products?page=1&limit=2" $LINENO
cv_http GET "/products?page=1&limit=2"

# Then
cv_step Then "response is 200 and returns a subset of at most 2 catalog products" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected HTTP 200 got $CV_HTTP_STATUS" $LINENO
TYPE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.items | type' 2>/dev/null || echo invalid)
[ "$TYPE" = "array" ] || cv_fail "expected .items to be an array got $TYPE" $LINENO
LEN=$(printf '%s' "$CV_HTTP_BODY" | jq '.items | length')
[ "$LEN" -ge 1 ] || cv_fail "expected at least 1 product on page 1 got $LEN" $LINENO
[ "$LEN" -le 2 ] || cv_fail "expected limit=2 to return at most 2 products got $LEN (catalog has $TOTAL)" $LINENO
FOREIGN=$(printf '%s' "$CV_HTTP_BODY" | jq --argjson all "$ALL_IDS" '[.items[].id | select(. as $i | $all | index($i) | not)] | length')
[ "$FOREIGN" = "0" ] || cv_fail "expected every returned product to belong to the public catalog got $FOREIGN unknown ids" $LINENO

# Cleanup
cv_step Cleanup "no delete endpoint exists; products live in the app's in-memory store, reset with the stack" $LINENO
echo "created products ${IDS[*]} with suffix ${SFX}; nothing removable via API"

echo "CODEVALID_TEST_ASSERTION_OK:browse_catalog_with_query_parameters"
