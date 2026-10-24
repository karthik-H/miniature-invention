#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

# Given
cv_step Given "a registered customer signs in and holds a valid token" $LINENO
SUFFIX=$(cv_unique)
EMAIL="cv.create.${SUFFIX}@example.com"
PASSWORD="S3cure-pass-${SUFFIX}"
SKU="cv-sku-${SUFFIX}"
cv_register_user "$EMAIL" "$PASSWORD"
cv_prereq "sign in via POST /auth/login" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from POST /auth/login got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected token from login got: $CV_HTTP_BODY" $LINENO
PAYLOAD=$(jq -nc --arg s "$SKU" '{name:("Widget " + $s), description:"A catalog widget", priceCents:2599, sku:$s}')

# When
cv_step When "the signed-in customer creates a new product via POST /products" $LINENO
cv_http POST /products "$PAYLOAD" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the product is created with the submitted fields and is retrievable" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from POST /products got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
BODY="$CV_HTTP_BODY"
PID=$(printf '%s' "$BODY" | jq -r '.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in response got: $BODY" $LINENO
[ "$(printf '%s' "$BODY" | jq -r '.sku')" = "$SKU" ] || cv_fail "expected sku $SKU got $(printf '%s' "$BODY" | jq -r '.sku')" $LINENO
[ "$(printf '%s' "$BODY" | jq -r '.name')" = "Widget $SKU" ] || cv_fail "expected name 'Widget $SKU' got $(printf '%s' "$BODY" | jq -r '.name')" $LINENO
[ "$(printf '%s' "$BODY" | jq -r '.description')" = "A catalog widget" ] || cv_fail "expected description 'A catalog widget' got $(printf '%s' "$BODY" | jq -r '.description')" $LINENO
[ "$(printf '%s' "$BODY" | jq -r '.priceCents')" = "2599" ] || cv_fail "expected priceCents 2599 got $(printf '%s' "$BODY" | jq -r '.priceCents')" $LINENO
[ -n "$(printf '%s' "$BODY" | jq -r '.createdAt // empty')" ] || cv_fail "expected createdAt in response got: $BODY" $LINENO
cv_http GET "/products/$PID" 200
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.sku')" = "$SKU" ] || cv_fail "expected GET /products/$PID sku $SKU got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "release data created by this test" $LINENO
cv_cleanup_note "user $EMAIL, product $PID"

echo "CODEVALID_TEST_ASSERTION_OK:customer_signs_in_and_creates_product"
