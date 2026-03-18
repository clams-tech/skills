#!/usr/bin/env bash
set -euo pipefail

# render-portfolio-summary.sh — Reads clams portfolio-summary JSON from stdin,
# renders a PDF report.
#
# Usage:
#   clams reports portfolio-summary --machine --format json \
#     | ./clams/scripts/render-portfolio-summary.sh --pdf ~/Desktop/portfolio-summary.pdf

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

# Extract top-level fields
TIMESTAMP=$(echo "$JSON" | jq -r '.data.snapshot_timestamp')
FIAT_CURRENCY=$(echo "$JSON" | jq -r '.data.fiat_valuation.fiat_currency')
ALGORITHM=$(echo "$JSON" | jq -r '.data.btc_capital_gains.algorithm')

# Portfolio balance
BTC_BALANCE=$(echo "$JSON" | jq -r '.data.btc_balance | tonumber / 100000000')
BTC_BALANCE_FIAT=$(echo "$JSON" | jq -r '.data.btc_balance_fiat | tonumber')

# Capital gains summary
SALE_COUNT=$(echo "$JSON" | jq -r '.data.btc_capital_gains.sale_count')
TOTAL_QTY_SOLD=$(echo "$JSON" | jq -r '.data.btc_capital_gains.total_quantity_sold | tonumber / 100000000')
TOTAL_PROCEEDS=$(echo "$JSON" | jq -r '.data.btc_capital_gains.total_proceeds_fiat | tonumber')
TOTAL_COST_BASIS=$(echo "$JSON" | jq -r '.data.btc_capital_gains.total_cost_basis_fiat | tonumber')
REALIZED_GAIN=$(echo "$JSON" | jq -r '.data.btc_capital_gains.realized_gain_fiat | tonumber')
REALIZED_PCT=$(echo "$JSON" | jq -r '.data.btc_capital_gains.realized_gain_percentage | tonumber')
UNREALIZED_GAIN=$(echo "$JSON" | jq -r '.data.btc_capital_gains.unrealized_gain_fiat | tonumber')
UNREALIZED_PCT=$(echo "$JSON" | jq -r '.data.btc_capital_gains.unrealized_gain_percentage | tonumber')
UNREALIZED_COST_BASIS=$(echo "$JSON" | jq -r '.data.btc_capital_gains.unrealized_cost_basis_fiat | tonumber')
AVG_COST_BASIS=$(echo "$JSON" | jq -r '.data.btc_capital_gains.average_cost_basis_fiat_per_btc | tonumber')
TOTAL_GAIN=$(echo "$JSON" | jq -r '.data.btc_capital_gains.total_gain_fiat | tonumber')

# Open lots: count total, show most recent 20
MAX_LOTS=20
TOTAL_LOTS=$(echo "$JSON" | jq '.data.btc_capital_gains.open_lots | length')
LOT_ROWS=$(echo "$JSON" | jq -r --argjson max "$MAX_LOTS" '
  .data.btc_capital_gains.open_lots | sort_by(.acquired_at) | .[-$max:][] |
  (.acquired_at | split("T")[0]) as $date |
  (.quantity | tonumber / 100000000) as $qty |
  (.cost_basis_fiat | tonumber) as $cost |
  "\(.lot_id)\t\($date)\t\($qty)\t\($cost)"
')

# Format display values
DISPLAY_DATE=$(echo "$TIMESTAMP" | sed 's/T/ /; s/\+.*$/Z/; s/\.[0-9]*Z/Z/')
BTC_FMT=$(printf "%.8f" "$BTC_BALANCE")
BTC_FIAT_FMT=$(printf "%'.2f" "$BTC_BALANCE_FIAT")
QTY_SOLD_FMT=$(printf "%.8f" "$TOTAL_QTY_SOLD")
PROCEEDS_FMT=$(printf "%'.2f" "$TOTAL_PROCEEDS")
COST_BASIS_FMT=$(printf "%'.2f" "$TOTAL_COST_BASIS")
REALIZED_FMT=$(printf "%'.2f" "$REALIZED_GAIN")
REALIZED_PCT_FMT=$(printf "%.2f" "$REALIZED_PCT")
UNREALIZED_FMT=$(printf "%'.2f" "$UNREALIZED_GAIN")
UNREALIZED_PCT_FMT=$(printf "%.2f" "$UNREALIZED_PCT")
UNREALIZED_CB_FMT=$(printf "%'.2f" "$UNREALIZED_COST_BASIS")
AVG_CB_FMT=$(printf "%'.2f" "$AVG_COST_BASIS")
TOTAL_GAIN_FMT=$(printf "%'.2f" "$TOTAL_GAIN")

# Chart: Cost Basis vs Market Value bar widths
read -r CB_BAR_W MV_BAR_W CB_LABEL_X MV_LABEL_X MV_BAR_COLOR < <(
  awk -v cb="$UNREALIZED_COST_BASIS" -v mv="$BTC_BALANCE_FIAT" -v gain="$UNREALIZED_GAIN" 'BEGIN {
    maxw=380; bx=100; pad=8
    m=(cb>mv)?cb:mv
    if (m>0) { cbw=cb/m*maxw; mvw=mv/m*maxw } else { cbw=0; mvw=0 }
    printf "%.1f %.1f %.1f %.1f %s\n", cbw, mvw, bx+cbw+pad, bx+mvw+pad, (gain>=0)?"#86efac":"#fca5a5"
  }'
)

# Generate open lots table rows HTML
LOTS_HTML=""
while IFS=$'\t' read -r lot_id acquired qty cost; do
  [ -z "$lot_id" ] && continue
  qty_fmt=$(printf "%.8f" "$qty")
  cost_fmt=$(printf "%'.2f" "$cost")
  LOTS_HTML="${LOTS_HTML}<tr><td>${lot_id}</td><td>${acquired}</td><td class=\"num\">${qty_fmt}</td><td class=\"num\">${cost_fmt}</td></tr>"
done <<< "$LOT_ROWS"

emit_html() {
cat <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Portfolio Summary</title>
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
  /* ── Metrics row ── */
  .metrics {
    display: flex;
    border-bottom: 1px solid #e5e7eb;
    padding-bottom: 16px;
    margin-bottom: 0;
  }
  .metric {
    flex: 1;
  }
  .metric-label {
    font-size: 10px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: #999;
    margin-bottom: 2px;
  }
  .metric-value {
    font-size: 20px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.01em;
  }
  /* ── Gains row ── */
  .gains {
    display: flex;
    padding-bottom: 12px;
    margin-bottom: 0;
  }
  .gain {
    flex: 1;
  }
  .gain-label {
    font-size: 10px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: #999;
    margin-bottom: 2px;
  }
  .gain-value {
    font-size: 16px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }
  .gain-pct {
    font-size: 11px;
    color: #999;
    font-variant-numeric: tabular-nums;
  }
  .positive { color: #15803d; }
  .negative { color: #b91c1c; }
  /* ── Detail lines ── */
  .details {
    display: grid;
    grid-template-columns: 1fr 1fr;
    column-gap: 40px;
  }
  .detail {
    display: flex;
    justify-content: space-between;
    padding: 5px 0;
    border-bottom: 1px solid #f3f4f6;
    font-size: 12px;
  }
  .detail-label { color: #999; }
  .detail-value { font-weight: 500; font-variant-numeric: tabular-nums; }
  /* ── Tables ── */
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
    padding: 4px 8px 4px 0;
    border-bottom: 1px solid #f3f4f6;
  }
  tbody tr:nth-child(even) td { background: #fafafa; }
  .note { color: #999; font-size: 11px; margin-bottom: 6px; }
</style>
</head>
<body>
<h1>Portfolio Summary</h1>
<p class="meta">${DISPLAY_DATE} &middot; ${ALGORITHM}</p>

<h2>Balance</h2>
<div class="metrics">
  <div class="metric">
    <div class="metric-label">BTC Balance</div>
    <div class="metric-value">${BTC_FMT}</div>
  </div>
  <div class="metric">
    <div class="metric-label">Market Value (${FIAT_CURRENCY})</div>
    <div class="metric-value">\$${BTC_FIAT_FMT}</div>
  </div>
</div>

<h2>Capital Gains</h2>
<div class="gains">
  <div class="gain">
    <div class="gain-label">Realized</div>
    <div class="gain-value $(echo "$REALIZED_GAIN" | awk '{print ($1 >= 0) ? "positive" : "negative"}')">\$${REALIZED_FMT}</div>
    <div class="gain-pct">${REALIZED_PCT_FMT}%</div>
  </div>
  <div class="gain">
    <div class="gain-label">Unrealized</div>
    <div class="gain-value $(echo "$UNREALIZED_GAIN" | awk '{print ($1 >= 0) ? "positive" : "negative"}')">\$${UNREALIZED_FMT}</div>
    <div class="gain-pct">${UNREALIZED_PCT_FMT}%</div>
  </div>
  <div class="gain">
    <div class="gain-label">Total</div>
    <div class="gain-value $(echo "$TOTAL_GAIN" | awk '{print ($1 >= 0) ? "positive" : "negative"}')">\$${TOTAL_GAIN_FMT}</div>
  </div>
</div>

<h2>Cost Basis vs Market Value</h2>
<svg xmlns="http://www.w3.org/2000/svg" width="520" height="68" style="margin-bottom:8px">
  <text x="0" y="19" font-size="10" font-family="-apple-system, BlinkMacSystemFont, sans-serif" fill="#999">Cost Basis</text>
  <rect x="100" y="8" width="${CB_BAR_W}" height="18" fill="#d1d5db"/>
  <text x="${CB_LABEL_X}" y="21" font-size="10" font-family="-apple-system, BlinkMacSystemFont, sans-serif" fill="#1a1a1a" font-weight="500">\$${UNREALIZED_CB_FMT}</text>
  <text x="0" y="49" font-size="10" font-family="-apple-system, BlinkMacSystemFont, sans-serif" fill="#999">Market Value</text>
  <rect x="100" y="38" width="${MV_BAR_W}" height="18" fill="${MV_BAR_COLOR}"/>
  <text x="${MV_LABEL_X}" y="51" font-size="10" font-family="-apple-system, BlinkMacSystemFont, sans-serif" fill="#1a1a1a" font-weight="500">\$${BTC_FIAT_FMT}</text>
</svg>

<h2>Details</h2>
<div class="details">
  <div class="detail"><span class="detail-label">Disposals</span><span class="detail-value">${SALE_COUNT}</span></div>
  <div class="detail"><span class="detail-label">Total Sold</span><span class="detail-value">${QTY_SOLD_FMT} BTC</span></div>
  <div class="detail"><span class="detail-label">Total Proceeds</span><span class="detail-value">\$${PROCEEDS_FMT}</span></div>
  <div class="detail"><span class="detail-label">Cost Basis (Sold)</span><span class="detail-value">\$${COST_BASIS_FMT}</span></div>
  <div class="detail"><span class="detail-label">Cost Basis (Open)</span><span class="detail-value">\$${UNREALIZED_CB_FMT}</span></div>
  <div class="detail"><span class="detail-label">Avg Cost / BTC</span><span class="detail-value">\$${AVG_CB_FMT}</span></div>
</div>

<h2>Open Lots (${TOTAL_LOTS} total)</h2>
$(if [ "$TOTAL_LOTS" -gt "$MAX_LOTS" ]; then echo "<p class=\"note\">Showing ${MAX_LOTS} most recent</p>"; fi)
<table>
  <thead>
    <tr><th>Lot</th><th>Acquired</th><th class="num">Quantity (BTC)</th><th class="num">Cost Basis (${FIAT_CURRENCY})</th></tr>
  </thead>
  <tbody>
${LOTS_HTML}
  </tbody>
</table>

</body>
</html>
HTMLEOF
}

emit_html | weasyprint -q - "$PDF_OUTPUT"
echo "PDF saved to $PDF_OUTPUT" >&2
