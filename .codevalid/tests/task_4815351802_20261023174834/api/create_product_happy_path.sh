#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_4815351802_20261023174834/api/_infra.sh

# Given
cv_step Given "a registered, signed-in user and a unique product payload" $LINENO
SUFFIX=$(cv_unique)
EMAIL="cv-product-${SUFFIX}@example.com"
PASSWORD="CvPass-${SUFFIX:0:10}"
cv_register_user "$EMAIL" "$PASSWORD"
TOKEN=$CV_TOKEN
SKU="CV-SKU-${SUFFIX}"
NAME="CodeValid Widget ${SUFFIX}"
DESC="A test widget created by CodeValid"
PRICE=1999
PAYLOAD=$(jq -nc --arg n "$NAME" --arg d "$DESC" --argjson p "$PRICE" --arg s "$SKU" \
  '{name:$n,description:$d,priceCents:$p,sku:$s}')

# When
cv_step When "the signed-in user POSTs /products with the product" $LINENO
cv_http POST /products "$PAYLOAD" -H "Authorization: Bearer $TOKEN"
CREATE_STATUS=$CV_HTTP_STATUS
CREATE_BODY=$CV_HTTP_BODY

# Then
cv_step Then "product is created (201) with the sent fields and appears in the catalog" $LINENO
[ "$CREATE_STATUS" = "201" ] || cv_fail "expected 201 from POST /products got $CREATE_STATUS" $LINENO
PID=$(printf '%s' "$CREATE_BODY" | jq -r '.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in response got none" $LINENO
GOT=$(printf '%s' "$CREATE_BODY" | jq -r '[.name,.description,(.priceCents|tostring),.sku]|join("|")')
WANT="${NAME}|${DESC}|${PRICE}|${SKU}"
[ "$GOT" = "$WANT" ] || cv_fail "expected created product fields '$WANT' got '$GOT'" $LINENO

cv_http GET /products "" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from GET /products got $CV_HTTP_STATUS" $LINENO
COUNT=$(printf '%s' "$CV_HTTP_BODY" | jq --arg id "$PID" --arg s "$SKU" '[.products[] | select(.id==$id and .sku==$s)] | length')
[ "$COUNT" = "1" ] || cv_fail "expected product $PID (sku $SKU) once in catalog got $COUNT" $LINENO

cv_http GET "/products/$PID" "" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from GET /products/$PID got $CV_HTTP_STATUS" $LINENO
GOT2=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.sku // empty')
[ "$GOT2" = "$SKU" ] || cv_fail "expected sku $SKU from GET /products/$PID got '$GOT2'" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: in-memory store has no delete endpoint; data uses unique values" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:create_product_happy_path"
