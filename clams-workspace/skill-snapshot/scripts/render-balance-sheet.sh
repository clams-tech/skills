#!/usr/bin/env bash
set -euo pipefail

# render-balance-sheet.sh — Reads clams balance-sheet JSON from stdin,
# renders a PDF report.
#
# Usage:
#   clams reports balance-sheet --machine --format json \
#     | ./clams/scripts/render-balance-sheet.sh --pdf ~/Desktop/balance-sheet.pdf

PDF_OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdf)
      PDF_OUTPUT="${2:?'--pdf requires an output file path'}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$PDF_OUTPUT" ]; then
  echo "Error: --pdf <path> is required." >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed." >&2
  exit 1
fi

if ! command -v weasyprint &>/dev/null; then
  echo "Error: weasyprint is required but not installed." >&2
  echo "Install with: brew install weasyprint" >&2
  exit 1
fi

JSON=$(cat)

# Extract timestamp
TIMESTAMP=$(echo "$JSON" | jq -r '.data.snapshot_timestamp')

# Build account tree rows as TSV: depth \t label \t btc_balance
# Recursive jq function walks the tree
ACCOUNT_ROWS=$(echo "$JSON" | jq -r '
  def walk_tree(depth):
    . as $node |
    ($node.balances // []) as $bals |
    (if ($bals | length) > 0 then
       ($bals[0].net | tonumber / 100000000)
     else
       0
     end) as $btc |
    "\(depth)\t\($node.label)\t\($btc)",
    (($node.children // [])[] | walk_tree(depth + 1));
  .data.roots[] | walk_tree(0)
')

# Build connection balance rows as TSV: kind \t label \t btc_balance
CONNECTION_ROWS=$(echo "$JSON" | jq -r '
  .data.connection_balances[] |
  select(.kind == "Assets" or .kind == "Liabilities" or .kind == "Equity") |
  (.balances // []) as $bals |
  (if ($bals | length) > 0 then
     ($bals[0].net | tonumber / 100000000)
   else
     0
   end) as $btc |
  "\(.kind)\t\(.connection_label)\t\($btc)"
')

# Total assets in BTC
TOTAL_BTC=$(echo "$JSON" | jq -r '
  .data.totals[0].net // "0" | tonumber / 100000000
')

# Format timestamp for display
DISPLAY_DATE=$(echo "$TIMESTAMP" | sed 's/T/ /; s/\+.*$/Z/; s/\.[0-9]*Z/Z/')

# Generate account table rows HTML
ACCOUNT_HTML=""
while IFS=$'\t' read -r depth label btc; do
  [ -z "$depth" ] && continue
  padding=$(( depth * 24 ))

  # Format BTC to 8 decimal places
  btc_fmt=$(printf "%.8f" "$btc")

  # Style: root accounts (depth 0) are bold
  if [ "$depth" -eq 0 ]; then
    ACCOUNT_HTML="${ACCOUNT_HTML}<tr class=\"root\"><td style=\"padding-left:${padding}px\">${label}</td><td class=\"num\">${btc_fmt}</td></tr>"
  else
    ACCOUNT_HTML="${ACCOUNT_HTML}<tr class=\"child\"><td style=\"padding-left:${padding}px\">${label}</td><td class=\"num\">${btc_fmt}</td></tr>"
  fi
done <<< "$ACCOUNT_ROWS"

# Generate connection balance rows HTML
CONNECTION_HTML=""
while IFS=$'\t' read -r kind label btc; do
  [ -z "$kind" ] && continue
  btc_fmt=$(printf "%.8f" "$btc")
  CONNECTION_HTML="${CONNECTION_HTML}<tr><td>${label}</td><td>${kind}</td><td class=\"num\">${btc_fmt}</td></tr>"
done <<< "$CONNECTION_ROWS"

TOTAL_FMT=$(printf "%.8f" "$TOTAL_BTC")

emit_html() {
cat <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Balance Sheet</title>
<style>
  @page {
    size: letter;
    margin: 56px 56px 64px 56px;
    @top-left {
      content: "";
      border-top: 2px solid #1a1a1a;
      width: 100%;
    }
    @bottom-left {
      content: "Clams";
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
      font-size: 8px; color: #bbb; letter-spacing: 0.05em;
    }
    @bottom-right {
      content: "Page " counter(page) " of " counter(pages);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
      font-size: 8px; color: #bbb;
    }
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: #fff;
    color: #1a1a1a;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    font-size: 13px;
    line-height: 1.5;
  }
  h1 {
    font-size: 22px;
    font-weight: 600;
    letter-spacing: -0.01em;
    margin-bottom: 2px;
  }
  .meta {
    color: #999;
    font-size: 11px;
    margin-bottom: 28px;
  }
  h2 {
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: #999;
    margin: 28px 0 12px;
    padding-bottom: 6px;
    border-bottom: 1px solid #e5e7eb;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
  }
  th {
    text-align: left;
    color: #999;
    font-size: 10px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    padding: 6px 8px 6px 0;
    border-bottom: 1px solid #d1d5db;
  }
  th.num, td.num { text-align: right; font-variant-numeric: tabular-nums; }
  td {
    padding: 5px 8px 5px 0;
    border-bottom: 1px solid #f3f4f6;
  }
  tbody tr:nth-child(even) td { background: #fafafa; }
  tr.root td { font-weight: 600; }
  tr.child td { color: #444; }
  tr.total td {
    font-weight: 600;
    border-top: 2px solid #1a1a1a;
    border-bottom: none;
    padding-top: 8px;
  }
</style>
</head>
<body>
<h1>Balance Sheet</h1>
<p class="meta">${DISPLAY_DATE}</p>

<h2>Accounts</h2>
<table>
  <thead>
    <tr><th>Account</th><th class="num">Balance (BTC)</th></tr>
  </thead>
  <tbody>
${ACCOUNT_HTML}
    <tr class="total"><td>Total Assets</td><td class="num">${TOTAL_FMT}</td></tr>
  </tbody>
</table>

<h2>Connection Balances</h2>
<table>
  <thead>
    <tr><th>Connection</th><th>Kind</th><th class="num">Balance (BTC)</th></tr>
  </thead>
  <tbody>
${CONNECTION_HTML}
  </tbody>
</table>

</body>
</html>
HTMLEOF
}

emit_html | weasyprint -q - "$PDF_OUTPUT"
echo "PDF saved to $PDF_OUTPUT" >&2
