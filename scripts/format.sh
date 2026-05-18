#!/usr/bin/env bash
# format.sh — PRESENTATION-ONLY transforms for the bundled PDF render scripts.
#
# Boundary (must hold for every function here):
#   * Input is exactly ONE engine field.
#   * Output is that SAME value, made human-readable: a fixed-constant unit
#     scale (sats÷100000000, cents÷100), decimal/locale formatting, a
#     currency symbol, a "%", or a readable date.
#   * No function combines fields, derives a new figure, infers a sign from
#     account type, aggregates, or computes geometry. That is *computation*
#     and belongs in the Clams engine (see references/pdf-report-gaps.md).
#
# Sourced by render-*.sh. bash 3.2 safe (awk/sed, ANSI-C quoting, no mapfile).

# sats -> BTC  (÷100,000,000, 8 dp). Single field, fixed constant.
fmt_btc_sats() {
  [ -z "${1:-}" ] && return 0
  awk -v v="$1" 'BEGIN { printf "%.8f", v / 100000000 }'
}

# currency code -> symbol (presentation only; unknown codes fall back to code)
_ccy_symbol() {
  case "${1:-}" in
    USD|CAD|AUD|NZD|SGD|HKD|MXN) printf '$' ;;
    EUR) printf '\xe2\x82\xac' ;;
    GBP) printf '\xc2\xa3' ;;
    JPY|CNY) printf '\xc2\xa5' ;;
    "") printf '' ;;
    *)  printf '%s ' "$1" ;;
  esac
}

# Core money formatter: a single already-major-unit value -> grouped 2 dp
# with currency symbol, sign before the symbol ("-$1,234.56").
_fmt_money_major() {
  local v="${1:-}" sym="${2:-}"
  [ -z "$v" ] && return 0
  awk -v v="$v" -v s="$sym" 'BEGIN {
    n = v + 0; sign = (n < 0) ? "-" : ""; if (n < 0) n = -n
    t = sprintf("%.2f", n); split(t, a, "."); ip = a[1]; fp = a[2]
    out = ""; c = 0
    for (i = length(ip); i >= 1; i--) {
      out = substr(ip, i, 1) out; c++
      if (c % 3 == 0 && i > 1) out = "," out
    }
    printf "%s%s%s.%s", sign, s, out, fp
  }'
}

# major-unit fiat field (the *_fiat fields are already in major units) ->
# "$1,234.56". Single field; currency symbol only, no scaling.
fmt_fiat_major() {
  [ -z "${1:-}" ] && return 0
  _fmt_money_major "$1" "$(_ccy_symbol "${2:-}")"
}

# minor-unit fiat field (cents) -> "$12.34"  (÷100, fixed constant).
fmt_fiat_cents() {
  [ -z "${1:-}" ] && return 0
  local mj
  mj=$(awk -v v="$1" 'BEGIN { printf "%.6f", v / 100 }')
  _fmt_money_major "$mj" "$(_ccy_symbol "${2:-}")"
}

# bare percentage number -> "<n>%"  (append unit only).
fmt_pct() {
  [ -z "${1:-}" ] && return 0
  printf '%s%%' "$1"
}

# ISO 8601 -> "YYYY-MM-DD HH:MM UTC"  (string presentation only).
fmt_ts() {
  [ -z "${1:-}" ] && return 0
  printf '%s' "$1" | sed -E 's/\.[0-9]+//; s/T/ /; s/:[0-9]{2}(\+00:00|Z| UTC)?$//; s/(\+00:00|Z)$//' \
    | sed -E 's/$/ UTC/'
}

# ISO 8601 -> "YYYY-MM-DD"  (date only).
fmt_date() {
  [ -z "${1:-}" ] && return 0
  printf '%s' "$1" | sed -E 's/T.*//'
}
