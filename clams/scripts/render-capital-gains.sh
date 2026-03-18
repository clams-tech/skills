#!/usr/bin/env bash
set -euo pipefail

# render-capital-gains.sh — Reads clams capital-gains JSON from stdin,
# renders a PDF report.
#
# Usage:
#   clams reports capital-gains --start 2025-01-01T00:00:00Z --end 2025-12-31T23:59:59Z --machine --format json \
#     | ./clams/scripts/render-capital-gains.sh --pdf ~/Desktop/capital-gains.pdf

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

# Extract header fields
FIAT_CURRENCY=$(echo "$JSON" | jq -r '.data.fiat_currency')
ALGORITHM=$(echo "$JSON" | jq -r '.data.algorithm')
START_DATE=$(echo "$JSON" | jq -r '.data.range_start' | sed 's/T.*//')
END_DATE=$(echo "$JSON" | jq -r '.data.range_end' | sed 's/T.*//')

# Build disposal rows as TSV
DISPOSAL_ROWS=$(echo "$JSON" | jq -r '
  .data.rows[] |
  (.sale_timestamp | split("T")[0]) as $sale_date |
  (.purchase_timestamp | split("T")[0]) as $purchase_date |
  (.quantity_disposed | tonumber / 100000000000) as $qty |
  (.net_proceeds_fiat | tonumber) as $proceeds |
  (.cost_basis_fiat | tonumber) as $cost_basis |
  (.realized_gain_fiat | tonumber) as $gain_loss |
  (if .holding_period_days >= 365 then "long-term" else "short-term" end) as $holding |
  "\($sale_date)\t\($purchase_date)\t\($qty)\t\($proceeds)\t\($cost_basis)\t\($gain_loss)\t\($holding)"
')

# Extract summary totals
TOTAL_PROCEEDS=$(echo "$JSON" | jq -r '.data.summary.total_net_proceeds_fiat | tonumber')
TOTAL_COST_BASIS=$(echo "$JSON" | jq -r '.data.summary.total_cost_basis_fiat | tonumber')
TOTAL_GAIN_LOSS=$(echo "$JSON" | jq -r '.data.summary.total_realized_gain_fiat | tonumber')

# Generate table rows HTML with gain/loss coloring
TABLE_HTML=""
while IFS=$'\t' read -r sale_date purchase_date qty proceeds cost_basis gain_loss holding; do
  [ -z "$sale_date" ] && continue
  qty_fmt=$(printf "%.8f" "$qty")
  proceeds_fmt=$(printf "%.2f" "$proceeds")
  cost_basis_fmt=$(printf "%.2f" "$cost_basis")
  gain_loss_fmt=$(printf "%.2f" "$gain_loss")
  gl_class=$(echo "$gain_loss" | awk '{print ($1 >= 0) ? "positive" : "negative"}')
  TABLE_HTML="${TABLE_HTML}<tr><td>${sale_date}</td><td>${purchase_date}</td><td class=\"num\">${qty_fmt}</td><td class=\"num\">${proceeds_fmt}</td><td class=\"num\">${cost_basis_fmt}</td><td class=\"num ${gl_class}\">${gain_loss_fmt}</td><td>${holding}</td></tr>"
done <<< "$DISPOSAL_ROWS"

# Format summary totals
TOTAL_PROCEEDS_FMT=$(printf "%'.2f" "$TOTAL_PROCEEDS")
TOTAL_COST_BASIS_FMT=$(printf "%'.2f" "$TOTAL_COST_BASIS")
TOTAL_GAIN_LOSS_FMT=$(printf "%'.2f" "$TOTAL_GAIN_LOSS")
TOTAL_GL_TEXT=$(echo "$TOTAL_GAIN_LOSS" | awk '{print ($1 >= 0) ? "positive" : "negative"}')

emit_html() {
cat <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Capital Gains Report</title>
<style>
  @page {
    size: letter landscape;
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
    margin-bottom: 20px;
  }
  /* ── Summary metrics ── */
  .summary {
    display: flex;
    border-bottom: 1px solid #e5e7eb;
    padding-bottom: 16px;
    margin-bottom: 16px;
  }
  .summary-metric {
    flex: 1;
  }
  .summary-label {
    font-size: 10px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: #999;
    margin-bottom: 2px;
  }
  .summary-value {
    font-size: 18px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.01em;
  }
  .positive { color: #15803d; }
  .negative { color: #b91c1c; }
  h2 {
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: #999;
    margin: 20px 0 10px;
    padding-bottom: 6px;
    border-bottom: 1px solid #e5e7eb;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 11px;
  }
  th {
    text-align: left;
    color: #999;
    font-size: 10px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    padding: 6px 6px 6px 0;
    border-bottom: 1px solid #d1d5db;
  }
  th.num, td.num { text-align: right; font-variant-numeric: tabular-nums; }
  td {
    padding: 4px 6px 4px 0;
    border-bottom: 1px solid #f3f4f6;
  }
  tr { page-break-inside: avoid; }
  tbody tr:nth-child(even) td { background: #fafafa; }
  tr.total td {
    font-weight: 600;
    border-top: 2px solid #1a1a1a;
    border-bottom: none;
    padding-top: 8px;
  }
</style>
</head>
<body>
<h1>Capital Gains Report</h1>
<p class="meta">${START_DATE} to ${END_DATE} &middot; ${FIAT_CURRENCY} &middot; ${ALGORITHM}</p>

<div class="summary">
  <div class="summary-metric">
    <div class="summary-label">Total Proceeds</div>
    <div class="summary-value">\$${TOTAL_PROCEEDS_FMT}</div>
  </div>
  <div class="summary-metric">
    <div class="summary-label">Total Cost Basis</div>
    <div class="summary-value">\$${TOTAL_COST_BASIS_FMT}</div>
  </div>
  <div class="summary-metric">
    <div class="summary-label">Net Gain / Loss</div>
    <div class="summary-value ${TOTAL_GL_TEXT}">\$${TOTAL_GAIN_LOSS_FMT}</div>
  </div>
</div>

<h2>Disposals</h2>
<table>
  <thead>
    <tr><th>Sale Date</th><th>Purchase Date</th><th class="num">Qty (BTC)</th><th class="num">Proceeds (${FIAT_CURRENCY})</th><th class="num">Cost Basis (${FIAT_CURRENCY})</th><th class="num">Gain/Loss (${FIAT_CURRENCY})</th><th>Holding</th></tr>
  </thead>
  <tbody>
${TABLE_HTML}
    <tr class="total"><td colspan="3">Totals</td><td class="num">${TOTAL_PROCEEDS_FMT}</td><td class="num">${TOTAL_COST_BASIS_FMT}</td><td class="num ${TOTAL_GL_TEXT}">${TOTAL_GAIN_LOSS_FMT}</td><td></td></tr>
  </tbody>
</table>

</body>
</html>
HTMLEOF
}

emit_html | weasyprint -q - "$PDF_OUTPUT"
echo "PDF saved to $PDF_OUTPUT" >&2
