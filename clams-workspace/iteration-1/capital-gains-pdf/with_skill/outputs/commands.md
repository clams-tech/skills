# Capital Gains 2025 PDF Report — Command Transcript

The user has wallets synced and journals already processed, so we skip the sync
and `clams journals process` steps and go straight to report generation.

## Step 1 — Generate the capital gains report as JSON and pipe it to the PDF render script

The capital gains report requires `--start` and `--end` flags with RFC 3339 UTC
timestamps. For the full 2025 tax year, the range is January 1 through
December 31.

The skill instructs us to use `--machine --format json` and pipe the output
through `scripts/render-capital-gains.sh --pdf <path>` for PDF generation.

```bash
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z \
  --end 2025-12-31T23:59:59Z \
  --machine --format json \
  | scripts/render-capital-gains.sh --pdf ~/Desktop/capital-gains-2025.pdf
```

This single pipeline does the following:

1. `clams reports capital-gains --start 2025-01-01T00:00:00Z --end 2025-12-31T23:59:59Z --machine --format json`
   — Generates the capital gains report for the full 2025 calendar year as
   machine-readable JSON (with the `data` envelope containing rows, summary
   totals, fiat currency, algorithm, and date range).

2. `| scripts/render-capital-gains.sh --pdf ~/Desktop/capital-gains-2025.pdf`
   — Reads the JSON from stdin, extracts disposal rows and summary totals via
   `jq`, builds an HTML document with a styled table, and converts it to a
   landscape-oriented PDF using `weasyprint`. The PDF is written to
   `~/Desktop/capital-gains-2025.pdf`.

## Expected output

On success, the render script prints to stderr:

```
PDF saved to /Users/john/Desktop/capital-gains-2025.pdf
```

## Error handling

- If the report comes back empty, the most likely cause is that
  `clams journals process` was not run after the last sync. The user states
  journals are already processed, so this should not apply.
- If `jq` or `weasyprint` is not installed, the render script will exit with
  an error message identifying the missing dependency.
- If the `clams` command fails, read the JSON error response (`code` and
  `message` fields) to diagnose the issue rather than guessing.
