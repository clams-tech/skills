# PDF Report Gaps — Upstream Engine Spec

**Status:** the bundled PDF render scripts are **presentation-formatting
templaters**. Via `scripts/format.sh` they apply *single-field* presentation
formatting only — sats→BTC (÷100,000,000), cents→fiat (÷100), currency
symbol + 2 dp + grouping, bare number → `n%`, ISO → readable date/time. They
do **not** compute totals, ratios, charts, or invert credit-normal signs.

Responsibility split:

| Who | Does |
|-----|------|
| Clams engine | Computes every financial value (balances, gains, cost basis, totals). |
| Render script (`scripts/format.sh`) | Formats one engine value at a time for display. No derivation. |
| Agent | Calls the script. No math, no formatting. |

This document is the spec for the Clams engine team. The single-field
formatting gaps are now handled in the skill and render cleanly; what remains
are **multi-field** gaps the skill must not touch.

---

## Principle

> The skill formats one engine value at a time for display. It never derives a
> *new* figure (sum, ratio, account-type sign, chart geometry) — that is the
> engine's job. CSV remains the machine ledger.

A render script **may**: select a field, apply a fixed-constant unit scale or
locale/symbol/`%`/date formatting to that single field, place it in a slot,
repeat an engine list into rows, toggle a block on an engine boolean, and do
declarative layout (CSS). It **may not**: combine or aggregate fields, derive
percentages or signs from other fields, invert accounting signs by account
type, or compute chart geometry.

---

## Tier A — handled by the skill (engine work optional)

These were once gaps; the skill now formats them per the principle (one
field, fixed transform). They render correctly today.

| # | Field class | Engine returns | Skill renders | Optional engine improvement |
|---|-------------|----------------|---------------|------------------------------|
| A1 | BTC amounts | sats, millisat precision (`"13906056.427"`) | `0.13906056 BTC` (8 dp) | A canonical `*_btc_display` so the BTC precision/rounding choice is the engine's, not the skill's |
| A2 | Fiat asset balances | cents (`"65.500"`) | `$0.66` | `*_display` |
| A3 | `*_fiat` summary fields | 3-dp major units (`"-4624.353"`) | `-$4,624.35` | `*_display` (so locale/rounding match the CLI exactly) |
| A4 | Percentages | bare number (`"-0.175"`) | `-0.175%` | `*_display` (engine decides dp) |
| A6 | Timestamps | raw ISO (`"…T10:53:57.434Z"`) | `2026-05-18 10:53 UTC` | `*_display` |

A single convention would make Tier A canonical rather than skill-inferred:
**every monetary/quantity/percent/time field gets a sibling `_display`
string** the engine has already formatted (unit, precision, sign, symbol,
locale). The skill would render `_display` and stop owning the formatting
choice. Recommended, not blocking.

---

## Tier B — open engine gaps (require engine work)

The skill **cannot** close these without violating the principle.

| # | Gap | Engine returns today | Needed |
|---|-----|----------------------|--------|
| **B5** | **Credit-normal sign not normalized.** Balance-sheet Liabilities/Equity/Income `.net` are negative; `clams reports balance-sheet` (plain) flips them positive, the JSON does not. The PDF shows the engine's negative signs and so **diverges from the CLI**. | negative `.net` for credit-normal rows | A per-row `display_net` already sign-normalized to match the CLI plain output, **or** a `normal_balance` enum (`debit`\|`credit`) so the template can present the convention declaratively. **Highest-impact gap.** |
| **B7** | **No summary-only payload.** `--machine --format json` always includes the full `rows[]` / `disposals[]` / `open_lots[]` arrays (≈126 MB for ~160k disposals) even though the PDF needs only summary scalars. | full ledger arrays | A summary-only mode (e.g. `--summary`, or omit the arrays). Also the real fix for PDF latency and memory. |
| **B8** | **Gain/loss direction not provided.** Red/green/“+” styling would require deriving meaning from a sign. Removed; values render sign-only, no colour. | signed number only | An explicit `direction` enum (`gain`\|`loss`\|`flat`) so styling is declarative. Polish. |
| **B9** | **Cost-basis-vs-market-value chart removed** (portfolio). It required skill-computed bar geometry from two fields. | — | Engine provides chart-ready proportions (e.g. a 0–1 ratio pair) or a pre-rendered comparison; then the template can draw it without math. Polish. |

---

## Per-report map

### Capital Gains (`render-capital-gains.sh`)

| Slot | Engine field | Status |
|------|--------------|--------|
| Date range | `range_start` / `range_end` | A6 (formatted to date) |
| Cost basis method / Currency | `algorithm` / `fiat_currency` | ✅ engine-ready |
| Disposals / Lot selections | `summary.disposal_count` / `row_count` | ✅ engine-ready (integers) |
| Total Quantity Disposed | `summary.total_quantity_disposed` | A1 |
| Gross / Fees / Net / Cost Basis | `summary.total_*_fiat` | A3 |
| Realized Gain/Loss | `summary.total_realized_gain_fiat` | A3 (+ B8 for colour) |
| Realized % | `summary.total_realized_gain_percentage` | A4 |

### Portfolio Summary (`render-portfolio-summary.sh`)

| Slot | Engine field | Status |
|------|--------------|--------|
| Snapshot time | `snapshot_timestamp` | A6 |
| Algorithm / Currency | `btc_capital_gains.algorithm` / `fiat_valuation.fiat_currency` | ✅ engine-ready |
| BTC Holdings / Total Sold | `btc_balance` / `btc_capital_gains.total_quantity_sold` | A1 |
| BTC market value / Net portfolio value | `btc_balance_fiat` / `fiat_valuation.total` | A3 |
| Asset balances | `balances[].net` | A1 (BTC) / A2 (fiat) |
| Realized / Unrealized / Total gain | `btc_capital_gains.*_gain_fiat` | A3 (+ B8) |
| Realized / Unrealized % | `btc_capital_gains.*_percentage` | A4 |
| Sale count | `btc_capital_gains.sale_count` | ✅ engine-ready |
| Proceeds / Cost basis (sold/open/all) / Avg cost | `btc_capital_gains.*_fiat` | A3 |
| Cost Basis vs Market Value chart | — | **B9 (removed)** |

### Balance Sheet (`render-balance-sheet.sh`)

| Slot | Engine field | Status |
|------|--------------|--------|
| Snapshot time | `snapshot_timestamp` | A6 |
| Included kinds | `included_kinds` | ✅ engine-ready (joined) |
| Account tree | `roots[]…children[].balances[].net` | A1 / A2 + **B5** |
| Totals | `totals[].debit_total/credit_total/net` | A1 / A2 |
| Connection balances | `connection_balances[].balances[].net` | A1 / A2 + **B5** |
| Issues | `issues.unknown_account_rows` | ✅ engine-ready |
| Account depth | (no `depth` field; `depth: null`) | Skill derives by walking `children` — structural, not financial, so allowed. An explicit per-node `depth` would remove the traversal. |

---

## Acceptance criteria

The render scripts are correct as-is (presentation-formatting templaters).
The PDFs match the CLI **except** balance-sheet credit-normal sign (B5).
Engine work, in priority order:

1. **B5** — `display_net` or `normal_balance` so the balance sheet PDF agrees
   with `clams reports balance-sheet`. Highest impact (correctness/parity).
2. **B7** — summary-only payload. Removes the large-payload latency/memory
   cost and the need to ship the full ledger for a one-page summary.
3. **Tier A canonicalization** (optional) — `_display` siblings so unit,
   precision, sign, symbol and locale are the engine's decision, guaranteeing
   PDF/CLI parity. Scripts then render `_display` with no `format.sh` step.
4. **B8 / B9** (polish) — `direction` enum for gain/loss colour; chart-ready
   proportions to restore the cost-basis-vs-market-value bar.

Until B5 ships, the balance-sheet PDF intentionally shows the engine's own
signs for credit-normal accounts — a visible, honest marker of the gap rather
than a skill-side accounting transform.
