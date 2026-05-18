# PDF Report Gaps — Upstream Engine Spec

**Status:** the bundled PDF render scripts are **presentation-formatting
templaters**. Via `scripts/format.sh` they apply *single-field* presentation
formatting only (sats→BTC, cents→fiat, currency symbol + 2 dp, `%`, readable
dates). They do **not** compute totals, ratios, charts, or invert
credit-normal signs.

**Consequence:** values render cleanly, but two classes of gap remain because
they require *multi-field* logic the skill must not do:

1. **Sign normalization (X5).** Balance-sheet Liabilities/Equity/Income are
   credit-normal; the CLI plain-text formatter flips them positive, the JSON
   does not. The PDF shows the engine's own negative signs and so diverges
   from `clams reports balance-sheet`.
2. **Derived/aggregate visuals (chart, direction).** The portfolio
   cost-basis-vs-market-value chart was removed (it needed computed geometry).

This document is the spec for the Clams engine team: implement these and the
PDFs match the CLI exactly with zero multi-field logic in the skill. The
single-field formatting gaps (X1–X4, X6) are now handled by the skill;
canonical engine `_display` fields are still **recommended** so PDF, CLI, and
locale never disagree, but they are no longer blocking.

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

## Cross-cutting gaps (all reports)

| # | Gap | Engine returns today | Needed (display-ready) |
|---|-----|----------------------|------------------------|
| X1 | **BTC amounts in satoshis** | `"13906056.427"` | A BTC-denominated display string, e.g. `"0.13906056"` (or a companion `*_btc_display`) |
| X2 | **Fiat asset balances in cents** | `"65.500"` | Major-unit display string at correct precision, e.g. `"0.66"` (or `*_display`) |
| X3 | **`*_fiat` fields are 3-dp, unsigned-formatted, no symbol** | `"-4624.353"` | Locale/precision-correct display string incl. currency, e.g. `"-$4,624.35"` (or `*_display` + keep raw) |
| X4 | **Percentages are bare numbers** | `"-0.175"` | Display-ready percentage string, e.g. `"-0.18%"` (or `*_display`) |
| X5 | **Credit-normal sign not normalized** | Liabilities/Equity/Income `.net` are negative; the CLI *plain* formatter flips them, the JSON does not | A per-row display value already sign-normalized the way the CLI balance sheet shows it (e.g. `display_net`), or an explicit `normal_balance` enum so styling is declarative |
| X6 | **Timestamps raw ISO** | `"2026-05-18T10:53:57.434Z"` | A formatted display string, e.g. `"2026-05-18 10:53 UTC"` (or accept raw) |
| X7 | **No summary-only payload** | `--machine --format json` always includes the full `rows[]` / `disposals[]` / `open_lots[]` arrays (126 MB for 160k disposals) even though the PDF needs only summary scalars | A summary-only mode (e.g. `--summary`, or omit the arrays) so the skill never has to ingest/parse the entire ledger for a one-page summary. **This is also the real fix for PDF latency.** |
| X8 | **Gain/loss direction not provided** | only a signed number | An explicit `direction` enum (`gain` \| `loss` \| `flat`) so red/green/“+” is declarative, not derived |

A single, consistent convention would resolve most of the above: **every
monetary/quantity field gets a sibling `_display` string** the engine has
already formatted (unit, precision, sign, symbol, locale). The skill renders
`_display`; the raw field stays for machine use.

---

## Per-report field map

### Capital Gains (`render-capital-gains.sh`)

| Slot | Engine field | Today | Display-ready need |
|------|--------------|-------|--------------------|
| Date range | `range_start` / `range_end` | raw ISO | X6 |
| Cost basis method | `algorithm` | `"FIFO"` | ✅ ready |
| Currency | `fiat_currency` | `"USD"` | ✅ ready |
| Disposals / Lot selections | `summary.disposal_count` / `row_count` | integers | ✅ ready |
| Total Quantity Disposed | `summary.total_quantity_disposed` | sats `"3398209007.000"` | X1 |
| Gross / Fees / Net / Cost Basis | `summary.total_*_fiat` | `"0.000"` | X3 |
| Realized Gain/Loss | `summary.total_realized_gain_fiat` | `"-4624.353"` | X3, X8 |
| Realized % | `summary.total_realized_gain_percentage` | `"-0.175"` | X4 |

### Portfolio Summary (`render-portfolio-summary.sh`)

| Slot | Engine field | Today | Display-ready need |
|------|--------------|-------|--------------------|
| Snapshot time | `snapshot_timestamp` | raw ISO | X6 |
| Algorithm / Currency | `btc_capital_gains.algorithm` / `fiat_valuation.fiat_currency` | strings | ✅ ready |
| BTC Holdings | `btc_balance` | sats | X1 |
| BTC market value / Net portfolio value | `btc_balance_fiat` / `fiat_valuation.total` | 3-dp fiat | X3 |
| Asset balances | `balances[].net` | sats (BTC) / cents (USD) | X1, X2 |
| Realized / Unrealized / Total gain | `btc_capital_gains.*_gain_fiat` | 3-dp fiat | X3, X8 |
| Realized / Unrealized % | `btc_capital_gains.*_percentage` | bare number | X4 |
| Sale count | `btc_capital_gains.sale_count` | integer | ✅ ready |
| Total Sold | `btc_capital_gains.total_quantity_sold` | sats | X1 |
| Proceeds / Cost basis (sold/open/all) / Avg cost | `btc_capital_gains.*_fiat` | 3-dp fiat | X3 |
| **Cost Basis vs Market Value chart** | — | not provided | **Removed.** Required skill-computed bar geometry. To restore: engine provides the two values display-ready (X3) *and* a chart-ready ratio/percent pair, or a pre-rendered comparison. |

### Balance Sheet (`render-balance-sheet.sh`)

| Slot | Engine field | Today | Display-ready need |
|------|--------------|-------|--------------------|
| Snapshot time | `snapshot_timestamp` | raw ISO | X6 |
| Included kinds | `included_kinds` | string list | ✅ ready (joined for display) |
| Account tree | `roots[]…children[].balances[].net` | sats/cents, **credit-normal not flipped** | X1, X2, **X5** |
| Totals | `totals[].debit_total/credit_total/net` | sats/cents | X1, X2 |
| Connection balances | `connection_balances[].balances[].net` | sats/cents, credit-normal not flipped | X1, X2, X5 |
| Issues | `issues.unknown_account_rows` | integer | ✅ ready |
| Account depth | (engine traversal) | no `depth` field (`depth: null`); skill derives it by walking `children` | Acceptable (structural, not financial) but an explicit `depth` per node would remove the traversal |

---

## Acceptance criteria

The render scripts are correct as-is (dumb templaters). They become *good*
when the engine ships the above. Concretely:

1. Every monetary/quantity field has an engine-formatted `_display` sibling
   (X1–X4). Scripts swap raw → `_display`. No script change beyond the field
   name.
2. Balance-sheet rows carry an engine `display_net` (already sign-normalized
   to match `clams reports balance-sheet` plain output) or a `normal_balance`
   enum (X5).
3. A summary-only JSON mode exists (X7); the skill requests it for PDFs. This
   also removes the multi-second/large-payload latency.
4. Optional polish: `direction` enum (X8) for gain/loss styling; formatted
   `snapshot_timestamp_display` (X6); per-node `depth`.

Until then, the PDFs intentionally display raw engine values. That is the
correct behaviour for a dumb templater and makes these gaps unambiguous.
