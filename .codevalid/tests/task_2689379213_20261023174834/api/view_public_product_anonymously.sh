#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2689379213_20261023174834/api/_infra.sh

# Given
cv_step Given "a product exists in the public catalog" $LINENO
SFX=$(cv_suffix)
cv_register_user "seller_${SFX}@example.com" "Passw0rd!${SFX}" $LINENO
cv_create_product "$CV_TOKEN" "Lamp ${SFX}" "Desk lamp with warm light" 3499 "SKU-L-${SFX}" $LINENO
P_ID=$CV_PRODUCT_ID; P_JSON=$CV_PRODUCT_JSON

# When
cv_step When "anonymous visitor requests GET /products/{id} without any Authorization header" $LINENO
cv_http GET "/products/${P_ID}"

# Then
cv_step Then "response is 200 with the full product details" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected HTTP 200 got $CV_HTTP_STATUS" $LINENO
for f in id name description priceCents sku createdAt; do
  EXP=$(printf '%s' "$P_JSON" | jq -c ".$f")
  GOT=$(printf '%s' "$CV_HTTP_BODY" | jq -c ".$f" 2>/dev/null || echo invalid)
  [ "$EXP" = "$GOT" ] || cv_fail "expected $f=$EXP got $GOT" $LINENO
done
NAME=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.name')
[ "$NAME" = "Lamp ${SFX}" ] || cv_fail "expected name 'Lamp ${SFX}' got '$NAME'" $LINENO
PRICE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.priceCents')
[ "$PRICE" = "3499" ] || cv_fail "expected priceCents 3499 got $PRICE" $LINENO

# Cleanup
cv_step Cleanup "no delete endpoint exists; data lives in the app's in-memory store and is reset with the stack" $LINENO
echo "created product $P_ID with suffix ${SFX}; nothing to remove via API"

echo "CODEVALID_TEST_ASSERTION_OK:view_public_product_anonymously"
