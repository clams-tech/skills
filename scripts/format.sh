#!/usr/bin/env bash
# format.sh — PRESENTATION-ONLY transforms for the bundled PDF render scripts.
#
# Boundary (must hold for every function here):
#   * Input is exactly ONE engine field.
#   * Output is that SAME value, made human-readable: a fixed-constant unit
#     scale (sats÷100000000), decimal/locale formatting, a currency symbol,
#     a "%", or a readable date.
#
# Engine amount units (see the Clams CLI's amount_display.rs):
#   * BTC amounts are sats (3-decimal msat scale): ÷100,000,000 for BTC.
#   * Fiat and system stablecoins (USDT, USDC) are already in their native
#     units: 1234.560 USD is $1,234.56. Never divide them.
#   * Liquid assets (L-BTC, issued assets like USDt) are integer base units:
#     ÷10^precision, where the engine declares the precision.
#   * No function combines fields, derives a new figure, infers a sign from
#     account type, aggregates, or computes geometry. That is *computation*
#     and belongs in the Clams engine.
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

# true when the code is one of the engine's fiat currencies
# (FiatCurrency in the Clams CLI).
is_fiat_code() {
  case "${1:-}" in
    USD|EUR|JPY|GBP|CNY|AUD|CAD|CHF|HKD|NZD|SEK|KRW|SGD|MXN|INR|BRL|NOK|ZAR|DKK) return 0 ;;
    *) return 1 ;;
  esac
}

# native-unit amount -> "250.123456 USDT"  (no scaling; value as emitted).
fmt_native_units() {
  [ -z "${1:-}" ] && return 0
  printf '%s %s' "$1" "${2:-}"
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
