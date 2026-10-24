#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2689379213_20261023174834/api/_infra.sh

# Given
cv_step Given "a registered seller has created a product" $LINENO
SFX=$(cv_suffix)
EMAIL="seller_${SFX}@example.com"
PASS="Passw0rd!${SFX}"
cv_register_user "$EMAIL" "$PASS" $LINENO
TOKEN=$CV_TOKEN; USER_ID=$CV_USER_ID
cv_create_product "$TOKEN" "Private check ${SFX}" "Public description" 999 "SKU-P-${SFX}" $LINENO
P_ID=$CV_PRODUCT_ID

# When
cv_step When "anonymous client requests GET /products" $LINENO
cv_http GET /products

# Then
cv_step Then "response is 200 and contains only public product fields, no user or secret data" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected HTTP 200 got $CV_HTTP_STATUS" $LINENO
KEYS=$(printf '%s' "$CV_HTTP_BODY" | jq -c 'keys' 2>/dev/null || echo invalid)
[ "$KEYS" = '["products"]' ] || cv_fail "expected top-level keys [\"products\"] got $KEYS" $LINENO
FOUND=$(printf '%s' "$CV_HTTP_BODY" | jq --arg id "$P_ID" '[.products[] | select(.id==$id)] | length')
[ "$FOUND" = "1" ] || cv_fail "expected created product $P_ID in catalog got $FOUND" $LINENO
EXTRA=$(printf '%s' "$CV_HTTP_BODY" | jq -c '[.products[] | keys[] | select(IN("id","name","description","priceCents","sku","createdAt")|not)] | unique')
[ "$EXTRA" = "[]" ] || cv_fail "expected only public product fields got extra keys $EXTRA" $LINENO
SENS=$(printf '%s' "$CV_HTTP_BODY" | jq -c '[.. | objects | keys[] | select(test("password|hash|token|email|user|owner|secret";"i"))] | unique')
[ "$SENS" = "[]" ] || cv_fail "expected no sensitive keys got $SENS" $LINENO
for secret in "$EMAIL" "$USER_ID" "$TOKEN" "$PASS"; do
  if printf '%s' "$CV_HTTP_BODY" | grep -qF -- "$secret"; then
    cv_fail "expected catalog not to contain seller-private value '$secret' got it in body" $LINENO
  fi
done

# Cleanup
cv_step Cleanup "no delete endpoint exists; data lives in the app's in-memory store and is reset with the stack" $LINENO
echo "created product $P_ID and user $USER_ID; nothing to remove via API"

echo "CODEVALID_TEST_ASSERTION_OK:no_private_data_from_public_catalog"
