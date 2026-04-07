# Reports

**Prerequisites**:
- Journals must be processed first — see [journal-processing.md](journal-processing.md).
- Exchange rates must be synced (`clams rates sync`) before generating any report. Always run this if rates have not been synced since the last connection sync.

**Never** summarize, convert, or display amounts from raw JSON — values are in millisatoshis and will be wrong if you try to convert them.

## Output Formats

| Format | Flag | When to use |
|---|---|---|
| **Plain text** | `--format plain` | **Default for display reports** (balance sheet, portfolio summary, balance history). Show CLI output directly, do not reformat it |
| **CSV** | `--format csv --output <path>` | **Default for data reports** (capital gains, journal entries). Saves a file the user can open in a spreadsheet |
| **PDF** | `--machine --format json` piped to `<skill-dir>/scripts/render-*.sh --pdf <path>` | **Only when the user explicitly asks for PDF.** Requires `weasyprint` to be installed |

**Do not** default to PDF. Use plain text or CSV as described above. Only generate PDF when the user specifically requests it.

**Do not** use `--machine --format json` and then try to display the result yourself. Either pipe it to a render script for PDF, or use `--format plain` for terminal display.

## Format Support by Report

| Report | Default | Plain | CSV | PDF |
|---|---|---|---|---|
| Balance Sheet | plain | Yes | No | Yes |
| Balance History | plain | Yes | Yes | No |
| Portfolio Summary | plain | Yes | No | Yes |
| Capital Gains | csv | No | Yes | Yes |
| Journal Entries | csv | No | Yes | No |

## Balance Sheet

```bash
# Default — display in terminal
clams reports balance-sheet --format plain

# PDF (only if user asks)
clams reports balance-sheet --machine --format json \
  | <skill-dir>/scripts/render-balance-sheet.sh --pdf <output-path>.pdf
```

## Balance History

Shows balance over time with configurable interval and filters.

```bash
# Default — display in terminal
clams reports balance-history --format plain

# With date range and interval
clams reports balance-history \
  --start <YYYY-MM-DD>T00:00:00Z --end <YYYY-MM-DD>T23:59:59Z \
  --interval day --format plain

# Filter by connection, account, or asset
clams reports balance-history --connection <LABEL> --asset BTC --interval week

# CSV export
clams reports balance-history --format csv --output <path>.csv
```

Intervals: `hour`, `day`, `week`, `month`.

## Portfolio Summary

```bash
# Default — display in terminal
clams reports portfolio-summary --format plain

# PDF (only if user asks)
clams reports portfolio-summary --machine --format json \
  | <skill-dir>/scripts/render-portfolio-summary.sh --pdf <output-path>.pdf
```

## Capital Gains

Requires `--start` and `--end` (RFC3339 UTC timestamps). Does **not** support `--format plain`.

```bash
# Default — save as CSV
clams reports capital-gains \
  --start <YYYY-MM-DD>T00:00:00Z --end <YYYY-MM-DD>T23:59:59Z \
  --format csv --output <path>.csv

# PDF (only if user asks)
clams reports capital-gains \
  --start <YYYY-MM-DD>T00:00:00Z --end <YYYY-MM-DD>T23:59:59Z \
  --machine --format json \
  | <skill-dir>/scripts/render-capital-gains.sh --pdf <output-path>.pdf
```

## Journal Entries

CSV only:

```bash
clams reports journal-entries --format csv --output <path>.csv
```

## Exchange Rates

```bash
# Current rate
clams rates latest BTC-USD

# Historical range
clams rates range --start 2024-11-01T00:00:00Z --end 2024-11-30T23:59:59Z BTC-USD

# List supported pairs
clams rates pairs

# Sync rate cache
clams rates sync
```
