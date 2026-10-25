#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2689379213_20261023174834/api/_infra.sh

# Given
cv_step Given "two products exist in the catalog (created by a registered seller)" $LINENO
SFX=$(cv_suffix)
cv_register_user "seller_${SFX}@example.com" "Passw0rd!${SFX}" $LINENO
SELLER_TOKEN=$CV_TOKEN
cv_create_product "$SELLER_TOKEN" "Widget A ${SFX}" "First widget" 1999 "SKU-A-${SFX}" $LINENO
P1_ID=$CV_PRODUCT_ID; P1_JSON=$CV_PRODUCT_JSON
cv_create_product "$SELLER_TOKEN" "Widget B ${SFX}" "Second widget" 0 "SKU-B-${SFX}" $LINENO
P2_ID=$CV_PRODUCT_ID; P2_JSON=$CV_PRODUCT_JSON

# When
cv_step When "anonymous client requests GET /products without any Authorization header" $LINENO
cv_http GET /products

# Then
cv_step Then "response is 200 with an items array containing both products with full details" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected HTTP 200 got $CV_HTTP_STATUS" $LINENO
TYPE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.items | type' 2>/dev/null || echo invalid)
[ "$TYPE" = "array" ] || cv_fail "expected .items to be an array got $TYPE" $LINENO
for pair in "$P1_ID|$P1_JSON" "$P2_ID|$P2_JSON"; do
  PID=${pair%%|*}; PJSON=${pair#*|}
  GOT=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg id "$PID" '[.items[] | select(.id==$id)]')
  CNT=$(printf '%s' "$GOT" | jq 'length')
  [ "$CNT" = "1" ] || cv_fail "expected product $PID exactly once in catalog got $CNT" $LINENO
  SAME=$(jq -n --argjson a "$(printf '%s' "$GOT" | jq '.[0]')" --argjson b "$PJSON" \
    '($a|{id,name,description,priceCents,sku,createdAt}) == ($b|{id,name,description,priceCents,sku,createdAt})')
  [ "$SAME" = "true" ] || cv_fail "expected catalog entry for $PID to match created product $PJSON got $GOT" $LINENO
done
LEAK=$(printf '%s' "$CV_HTTP_BODY" | jq '[.. | objects | select(has("passwordHash"))] | length')
[ "$LEAK" = "0" ] || cv_fail "expected no passwordHash fields in public catalog got $LEAK" $LINENO

# Cleanup
cv_step Cleanup "no delete endpoint exists; data lives in the app's in-memory store and is reset with the stack" $LINENO
echo "created products $P1_ID $P2_ID use unique suffix ${SFX}; nothing to remove via API"

echo "CODEVALID_TEST_ASSERTION_OK:browse_full_public_catalog_success"
