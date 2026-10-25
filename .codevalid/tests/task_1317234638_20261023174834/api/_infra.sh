#!/usr/bin/env bash
# Shared helpers for this feature's API tests. Sourced first by every script.
export BASE_URL="${BASE_URL:-http://app:6713}"

# --- CodeValid diagnosis markers (parsed by the test runner; do not edit) ---
# cv_step  <Given|When|Then|Cleanup> "<what this section does>" $LINENO
# cv_prereq "<setup being done>" $LINENO
# cv_http  <METHOD> <url|/path> [json-body] [expected-status] [extra curl args, e.g. -H "Authorization: Bearer $T"]
#          performs the request (relative paths go to $BASE_URL), prints REQUEST_*/RESPONSE_*
#          and CV_HTTP|METHOD|url|status|ms, sets CV_HTTP_STATUS CV_HTTP_BODY CV_HTTP_MS
#          CV_HTTP_BODY_FILE CV_HTTP_HEADERS_FILE. Call it directly, never inside $(...).
#          A 3-digit expected-status (with or without a body) is asserted: a different status
#          fails the test via cv_fail. Omit it to assert on $CV_HTTP_STATUS yourself.
# cv_http  <METHOD> <url> <http_status>          (legacy: marker only, right after your own curl)
# cv_fail  "<expected X got Y>" $LINENO           (prints marker, exits 1)
cv_step() { printf 'CV_STEP|%s|%s|line=%s\n' "${1:-}" "${2:-}" "${3:-}"; }
cv_prereq() { printf 'CV_PREREQ|%s|line=%s\n' "${1:-}" "${2:-}"; }
cv_fail() { printf 'CV_ASSERT_FAIL|%s|line=%s\n' "${1:-}" "${2:-}"; exit 1; }
_cv_is_int() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
_cv_now_ms() {
  _cv_n=${EPOCHREALTIME:-}
  if [ -n "$_cv_n" ]; then _cv_secs_to_ms "$_cv_n"; return 0; fi
  _cv_n=$(date +%s%3N 2>/dev/null || true)
  _cv_is_int "$_cv_n" || _cv_n=$(( $(date +%s) * 1000 ))
  printf '%s' "$_cv_n"
}
_cv_ms_file() { printf '%s/.cv_last_ms.%s' "${TMPDIR:-/tmp}" "$$"; }
curl() {
  _cv_t0=$(_cv_now_ms)
  _cv_rc=0
  command curl "$@" || _cv_rc=$?
  _cv_t1=$(_cv_now_ms)
  printf '%s' "$((_cv_t1 - _cv_t0))" > "$(_cv_ms_file)" 2>/dev/null || :
  return $_cv_rc
}
# psql without a connection falls back to a local socket seed-test does not have; when
# DATABASE_URL is set and the call names no connection, connect through it.
psql() {
  if [ -n "${DATABASE_URL:-}" ]; then
    case " $* " in
      *" $DATABASE_URL "*|*" -h "*|*" --host"*|*" -d "*|*" --dbname"*|*"postgres://"*|*"postgresql://"*) ;;
      *) command psql "$DATABASE_URL" "$@"; return $? ;;
    esac
  fi
  command psql "$@"
}
_cv_secs_to_ms() {
  _cv_t=$(printf '%s' "${1:-0}" | tr ',' '.')
  _cv_s=${_cv_t%%.*}
  case "$_cv_t" in *.*) _cv_f=${_cv_t#*.}000 ;; *) _cv_f=000 ;; esac
  _cv_f=${_cv_f%"${_cv_f#???}"}
  while [ "${_cv_f#0}" != "$_cv_f" ]; do _cv_f=${_cv_f#0}; done
  _cv_is_int "$_cv_s" || _cv_s=0
  _cv_is_int "$_cv_f" || _cv_f=0
  printf '%s' "$(( _cv_s * 1000 + _cv_f ))"
}
_cv_is_status() { _cv_is_int "${1:-}" && [ ${#1} -eq 3 ]; }
cv_http() {
  if [ $# -ge 3 ] && [ $# -le 4 ] && _cv_is_status "$3" && { [ $# -eq 3 ] || _cv_is_int "$4"; }      && { [ -n "${4:-}" ] || [ -f "$(_cv_ms_file)" ]; }; then
    _cv_ms=${4:-}
    if [ -z "$_cv_ms" ] && [ -f "$(_cv_ms_file)" ]; then
      _cv_ms=$(cat "$(_cv_ms_file)" 2>/dev/null || true)
      rm -f "$(_cv_ms_file)" 2>/dev/null || :
    fi
    _cv_is_int "$_cv_ms" || _cv_ms=''
    printf 'CV_HTTP|%s|%s|%s%s\n' "$1" "$2" "$3" "${_cv_ms:+|$_cv_ms}"
    return 0
  fi
  _cv_method=${1:-GET}
  _cv_url=${2:-/}
  _cv_data=''
  _cv_expect=''
  if [ $# -ge 2 ]; then shift 2; else shift $#; fi
  if [ $# -ge 1 ] && ! _cv_is_status "$1"; then
    case "$1" in -*) ;; *) _cv_data=$1; shift ;; esac
  fi
  if [ $# -ge 1 ] && _cv_is_status "$1"; then _cv_expect=$1; shift; fi
  case "$_cv_url" in /*) _cv_url="${BASE_URL:-http://app:6713}$_cv_url" ;; esac
  CV_HTTP_BODY_FILE="${TMPDIR:-/tmp}/cv_http_body.$$"
  CV_HTTP_HEADERS_FILE="${TMPDIR:-/tmp}/cv_http_headers.$$"
  : > "$CV_HTTP_BODY_FILE"; : > "$CV_HTTP_HEADERS_FILE"
  printf 'REQUEST_HEADERS:\n%s %s\n' "$_cv_method" "$_cv_url"
  printf 'REQUEST_BODY:\n%s\n' "$_cv_data"
  if [ -n "$_cv_data" ]; then
    _cv_w=$(command curl -sS -X "$_cv_method" -H 'Content-Type: application/json' --data "$_cv_data" \
      -D "$CV_HTTP_HEADERS_FILE" -o "$CV_HTTP_BODY_FILE" -w '%{http_code} %{time_total}' "$@" "$_cv_url") || true
  else
    _cv_w=$(command curl -sS -X "$_cv_method" \
      -D "$CV_HTTP_HEADERS_FILE" -o "$CV_HTTP_BODY_FILE" -w '%{http_code} %{time_total}' "$@" "$_cv_url") || true
  fi
  CV_HTTP_STATUS=${_cv_w%% *}
  _cv_is_int "$CV_HTTP_STATUS" || CV_HTTP_STATUS=000
  case "$_cv_w" in *' '*) CV_HTTP_MS=$(_cv_secs_to_ms "${_cv_w#* }") ;; *) CV_HTTP_MS=0 ;; esac
  CV_HTTP_BODY=$(cat "$CV_HTTP_BODY_FILE" 2>/dev/null || true)
  printf 'RESPONSE_HEADERS:\n'; cat "$CV_HTTP_HEADERS_FILE" 2>/dev/null || true
  printf 'RESPONSE_BODY:\n%s\n' "$CV_HTTP_BODY"
  rm -f "$(_cv_ms_file)" 2>/dev/null || :
  printf 'CV_HTTP|%s|%s|%s|%s\n' "$_cv_method" "$_cv_url" "$CV_HTTP_STATUS" "$CV_HTTP_MS"
  if [ -n "$_cv_expect" ] && [ "$CV_HTTP_STATUS" != "$_cv_expect" ]; then
    cv_fail "expected HTTP $_cv_expect from $_cv_method $_cv_url got $CV_HTTP_STATUS: $(printf '%s' "$CV_HTTP_BODY" | head -c 300)" ""
  fi
  return 0
}
# --- end CodeValid diagnosis markers ---

# --- feature helpers ---
cv_unique() { date +%s%N; }

# cv_register_user <email> <password>  -> sets CV_USER_ID, CV_REG_TOKEN (fails on non-201)
cv_register_user() {
  cv_prereq "register customer $1 via POST /auth/register" "${LINENO}"
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')"
  if [ "$CV_HTTP_STATUS" != "201" ]; then
    cv_fail "expected 201 registering $1 got $CV_HTTP_STATUS: $CV_HTTP_BODY" "${LINENO}"
  fi
  CV_USER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
  CV_REG_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
  [ -n "$CV_USER_ID" ] || cv_fail "expected user.id in register response got: $CV_HTTP_BODY" "${LINENO}"
  export CV_USER_ID CV_REG_TOKEN
}

# cv_product_payload <sku>
cv_product_payload() {
  jq -nc --arg s "$1" '{name:("CV Product " + $s), description:"CodeValid test product", priceCents:1999, sku:$s}'
}

# cv_login_user <email> <password> -> sets CV_TOKEN (fails on non-200)
cv_login_user() {
  cv_prereq "sign in customer $1 via POST /auth/login" "${LINENO}"
  cv_http POST /auth/login "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')"
  if [ "$CV_HTTP_STATUS" != "200" ]; then
    cv_fail "expected 200 signing in $1 got $CV_HTTP_STATUS: $CV_HTTP_BODY" "${LINENO}"
  fi
  CV_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
  [ -n "$CV_TOKEN" ] || cv_fail "expected token in login response got: $CV_HTTP_BODY" "${LINENO}"
  export CV_TOKEN
}

# JWT secret the app runs with in the test stack (.codevalid/docker-compose.yml JWT_SECRET)
export CV_JWT_SECRET="${CV_JWT_SECRET:-codevalid-test-jwt-secret}"
_cv_b64url() { base64 -w0 | tr '+/' '-_' | tr -d '='; }
# _cv_hex_to_esc <hex> -> printf escape string (\xNN...)
_cv_hex_to_esc() { printf '%s' "$1" | sed 's/../\\x&/g'; }
# _cv_hmac_sha256_bin <key> <message> -> raw HMAC-SHA256 bytes on stdout (coreutils only)
_cv_hmac_sha256_bin() {
  _cv_khex=$(printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n')
  if [ ${#_cv_khex} -gt 128 ]; then
    _cv_khex=$(printf '%s' "$1" | sha256sum | cut -c1-64)
  fi
  while [ ${#_cv_khex} -lt 128 ]; do _cv_khex="${_cv_khex}00"; done
  _cv_ipad=''; _cv_opad=''
  for ((_cv_i = 0; _cv_i < 128; _cv_i += 2)); do
    _cv_b=$((16#${_cv_khex:_cv_i:2}))
    _cv_ipad+=$(printf '%02x' $((_cv_b ^ 0x36)))
    _cv_opad+=$(printf '%02x' $((_cv_b ^ 0x5c)))
  done
  _cv_inner=$({ printf "$(_cv_hex_to_esc "$_cv_ipad")"; printf '%s' "$2"; } | sha256sum | cut -c1-64)
  _cv_outer=$(printf "$(_cv_hex_to_esc "${_cv_opad}${_cv_inner}")" | sha256sum | cut -c1-64)
  printf "$(_cv_hex_to_esc "$_cv_outer")"
}
# cv_mint_jwt <payload-json> [secret] -> prints an HS256 JWT signed like the app's tokens
cv_mint_jwt() {
  _cv_h=$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | _cv_b64url)
  _cv_p=$(printf '%s' "$1" | _cv_b64url)
  _cv_sig=$(_cv_hmac_sha256_bin "${2:-$CV_JWT_SECRET}" "$_cv_h.$_cv_p" | _cv_b64url)
  printf '%s.%s.%s' "$_cv_h" "$_cv_p" "$_cv_sig"
}

# The app keeps users/products in memory and exposes no delete endpoint; data resets on stack restart.
cv_cleanup_note() { echo "cleanup: app store is in-memory with no delete endpoint; created data ($*) resets with the stack"; }
