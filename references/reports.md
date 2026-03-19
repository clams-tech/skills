# Reports

**Prerequisite**: Journals must be processed first — see [journal-processing.md](journal-processing.md).

**Never** summarize, convert, or display amounts from raw JSON — values are in millisatoshis and will be wrong if you try to convert them.

## Output Formats

| Format | Flag | Use when |
|---|---|---|
| **Plain text** | `--format plain` | User wants a quick look in the terminal — show this output directly, do not reformat it |
| **PDF** | `--machine --format json` piped to `<skill-dir>/scripts/render-*.sh --pdf <path>` | User wants a file to save, share, or print |
| **CSV** | `--format csv --output <path>` | User wants spreadsheet data (capital gains and journal entries only) |

**Do not** use `--machine --format json` and then try to display the result yourself. Either pipe it to a render script for PDF, or use `--format plain` for terminal display.

## Format Support by Report

| Report | Plain | PDF | CSV |
|---|---|---|---|
| Balance Sheet | Yes | Yes | No |
| Portfolio Summary | Yes | Yes | No |
| Capital Gains | Yes | Yes | Yes |
| Journal Entries | No | No | Yes |

## Balance Sheet

Quick look:

```bash
clams reports balance-sheet --format plain
```

PDF:

```bash
clams reports balance-sheet --machine --format json \
  | <skill-dir>/scripts/render-balance-sheet.sh --pdf <output-path>.pdf
```

## Portfolio Summary

Quick look:

```bash
clams reports portfolio-summary --format plain
```

PDF:

```bash
clams reports portfolio-summary --machine --format json \
  | <skill-dir>/scripts/render-portfolio-summary.sh --pdf <output-path>.pdf
```

## Capital Gains

Requires `--start` and `--end` (RFC3339 UTC timestamps).

Quick look:

```bash
clams reports capital-gains \
  --start <YYYY-MM-DD>T00:00:00Z --end <YYYY-MM-DD>T23:59:59Z \
  --format plain
```

PDF:

```bash
clams reports capital-gains \
  --start <YYYY-MM-DD>T00:00:00Z --end <YYYY-MM-DD>T23:59:59Z \
  --machine --format json \
  | <skill-dir>/scripts/render-capital-gains.sh --pdf <output-path>.pdf
```

CSV:

```bash
clams reports capital-gains \
  --start <YYYY-MM-DD>T00:00:00Z --end <YYYY-MM-DD>T23:59:59Z \
  --format csv --output <path>.csv
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
