#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2689379213_20261023174834/api/_infra.sh

# Given
cv_step Given "a product exists and a separate signed-in shopper holds a valid token" $LINENO
SFX=$(cv_suffix)
cv_register_user "seller_${SFX}@example.com" "Passw0rd!${SFX}" $LINENO
SELLER_TOKEN=$CV_TOKEN
cv_create_product "$SELLER_TOKEN" "Gadget ${SFX}" "A gadget" 4250 "SKU-G-${SFX}" $LINENO
P_ID=$CV_PRODUCT_ID; P_JSON=$CV_PRODUCT_JSON
cv_register_user "shopper_${SFX}@example.com" "Passw0rd!${SFX}" $LINENO
SHOPPER_TOKEN=$CV_TOKEN

# When
cv_step When "shopper calls GET /products with a Bearer token, then the same call is made anonymously" $LINENO
cv_http GET /products "" -H "Authorization: Bearer $SHOPPER_TOKEN"
AUTH_STATUS=$CV_HTTP_STATUS; AUTH_BODY=$CV_HTTP_BODY
cv_prereq "anonymous baseline request for comparison" $LINENO
cv_http GET /products
ANON_STATUS=$CV_HTTP_STATUS; ANON_BODY=$CV_HTTP_BODY

# Then
cv_step Then "authenticated response is 200 and contains the same public catalog as the anonymous one" $LINENO
[ "$AUTH_STATUS" = "200" ] || cv_fail "expected HTTP 200 for authenticated GET /products got $AUTH_STATUS" $LINENO
[ "$ANON_STATUS" = "200" ] || cv_fail "expected HTTP 200 for anonymous GET /products got $ANON_STATUS" $LINENO
TYPE=$(printf '%s' "$AUTH_BODY" | jq -r '.items | type' 2>/dev/null || echo invalid)
[ "$TYPE" = "array" ] || cv_fail "expected .items to be an array got $TYPE" $LINENO
GOT=$(printf '%s' "$AUTH_BODY" | jq -c --arg id "$P_ID" '[.items[] | select(.id==$id)][0] // null')
SAME=$(jq -n --argjson a "$GOT" --argjson b "$P_JSON" \
  '$a != null and (($a|{id,name,description,priceCents,sku,createdAt}) == ($b|{id,name,description,priceCents,sku,createdAt}))')
[ "$SAME" = "true" ] || cv_fail "expected authenticated catalog to contain product $P_JSON got $GOT" $LINENO
AUTH_SORTED=$(printf '%s' "$AUTH_BODY" | jq -cS '.items | sort_by(.id)')
ANON_SORTED=$(printf '%s' "$ANON_BODY" | jq -cS '.items | sort_by(.id)')
[ "$AUTH_SORTED" = "$ANON_SORTED" ] || cv_fail "expected authenticated catalog to equal anonymous catalog got differing payloads" $LINENO
KEYS=$(printf '%s' "$AUTH_BODY" | jq -c 'keys')
[ "$KEYS" = '["items"]' ] || cv_fail "expected only an items key (no personalization) got $KEYS" $LINENO

# Cleanup
cv_step Cleanup "no delete endpoint exists; data lives in the app's in-memory store and is reset with the stack" $LINENO
echo "created product $P_ID and users with suffix ${SFX}; nothing to remove via API"

echo "CODEVALID_TEST_ASSERTION_OK:browse_catalog_while_authenticated"
