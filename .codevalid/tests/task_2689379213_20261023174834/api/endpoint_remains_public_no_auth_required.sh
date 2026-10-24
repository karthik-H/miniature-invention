#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2689379213_20261023174834/api/_infra.sh

# Given
cv_step Given "a public product exists" $LINENO
SFX=$(cv_suffix)
cv_register_user "seller_${SFX}@example.com" "Passw0rd!${SFX}" $LINENO
cv_create_product "$CV_TOKEN" "Open item ${SFX}" "Anyone can view" 2500 "SKU-O-${SFX}" $LINENO
P_ID=$CV_PRODUCT_ID; P_JSON=$CV_PRODUCT_JSON

# When
cv_step When "visitor requests GET /products/{id} with no Authorization header, then with a garbage bearer token" $LINENO
cv_http GET "/products/${P_ID}"
ANON_STATUS=$CV_HTTP_STATUS; ANON_BODY=$CV_HTTP_BODY
cv_prereq "repeat with an invalid bearer token" $LINENO
cv_http GET "/products/${P_ID}" "" -H "Authorization: Bearer not-a-real-token"
BAD_STATUS=$CV_HTTP_STATUS; BAD_BODY=$CV_HTTP_BODY

# Then
cv_step Then "both requests return 200 with the product (never 401/403)" $LINENO
[ "$ANON_STATUS" = "200" ] || cv_fail "expected HTTP 200 anonymously got $ANON_STATUS" $LINENO
[ "$BAD_STATUS" = "200" ] || cv_fail "expected HTTP 200 with an invalid bearer token (public endpoint) got $BAD_STATUS" $LINENO
for B in "$ANON_BODY" "$BAD_BODY"; do
  SAME=$(jq -n --argjson a "$B" --argjson b "$P_JSON" '($a|{id,name,description,priceCents,sku,createdAt}) == ($b|{id,name,description,priceCents,sku,createdAt})')
  [ "$SAME" = "true" ] || cv_fail "expected product $P_JSON got $B" $LINENO
done

# Cleanup
cv_step Cleanup "no delete endpoint exists; data lives in the app's in-memory store and is reset with the stack" $LINENO
echo "created product $P_ID with suffix ${SFX}; nothing to remove via API"

echo "CODEVALID_TEST_ASSERTION_OK:endpoint_remains_public_no_auth_required"
