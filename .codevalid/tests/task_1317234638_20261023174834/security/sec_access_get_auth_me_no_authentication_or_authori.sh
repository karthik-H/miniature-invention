#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_1317234638_20261023174834/api/_infra.sh

CAT="access"; SEV="serious"
TITLE="No authentication or authorization on catalog read endpoints"

cv_step Given "sign up and create a catalog product with a valid token" $LINENO
SUFFIX=$(cv_unique)
EMAIL="sec-cat-${SUFFIX}@example.com"
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" '{email:$e,password:"Passw0rd!123"}')"
if [ "$CV_HTTP_STATUS" != "201" ]; then echo "setup failed: register returned $CV_HTTP_STATUS"; exit 1; fi
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
SKU="SEC-${SUFFIX}"
cv_http POST /products "$(cv_product_payload "$SKU")" -H "Authorization: Bearer $TOKEN"
if [ "$CV_HTTP_STATUS" != "201" ]; then echo "setup failed: create product returned $CV_HTTP_STATUS"; exit 1; fi
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$PID" ] || { echo "setup failed: no product id"; exit 1; }

cv_step When "read the catalog without any Authorization header" $LINENO
cv_http GET /products
LIST_STATUS=$CV_HTTP_STATUS
LIST_HAS=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg s "$SKU" '[.products[]? | select(.sku == $s)] | length' 2>/dev/null || echo 0)
cv_http GET "/products/$PID"
ONE_STATUS=$CV_HTTP_STATUS

cv_step Then "decide whether anonymous catalog reads are allowed" $LINENO
EVID="anonymous GET /products=${LIST_STATUS} (seeded sku visible=${LIST_HAS}) GET /products/:id=${ONE_STATUS}"

cv_step Cleanup "in-memory store, nothing to delete" $LINENO
cv_cleanup_note "$EMAIL" "$SKU"

if [ "$LIST_STATUS" = "200" ] || [ "$ONE_STATUS" = "200" ]; then
  printf 'CV_SECURITY|vulnerable|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "$EVID"
else
  printf 'CV_SECURITY|secure|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "$EVID"
fi
exit 0
