# Capital Gains 2025 PDF Report — Command Transcript

The user has confirmed that wallets are already synced and journals are already processed, so we skip the sync and `clams journals process` steps and go straight to report generation.

## Step 1: Generate the capital gains report as JSON and pipe it to the PDF render script

This is the single command needed. It generates the capital gains report for the full 2025 calendar year (January 1 through December 31) in machine-readable JSON format, then pipes that JSON into the `render-capital-gains.sh` script which converts it to a styled PDF using `weasyprint`.

```bash
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z --end 2025-12-31T23:59:59Z \
  --machine --format json \
  | scripts/render-capital-gains.sh --pdf ~/Desktop/capital-gains-2025.pdf
```

### Breakdown of flags

- `--start 2025-01-01T00:00:00Z` — Beginning of the reporting period (RFC3339 UTC timestamp for January 1, 2025).
- `--end 2025-12-31T23:59:59Z` — End of the reporting period (RFC3339 UTC timestamp for December 31, 2025).
- `--machine --format json` — Produces structured JSON output suitable for piping to a render script. These two flags must be used together.
- `| scripts/render-capital-gains.sh --pdf ~/Desktop/capital-gains-2025.pdf` — The render script reads the JSON from stdin, extracts disposal rows and summary totals, builds an HTML report, and uses `weasyprint` to convert it to a PDF saved at `~/Desktop/capital-gains-2025.pdf`.

### Prerequisites (already satisfied per user)

- Wallets are synced (`clams sync` has been run).
- Journals are processed (`clams journals process` has been run).
- `jq` is installed (required by the render script to parse JSON).
- `weasyprint` is installed (required by the render script to generate PDF).

### Expected output

On success, the script prints to stderr:

```
PDF saved to /Users/john/Desktop/capital-gains-2025.pdf
```

The PDF file at `~/Desktop/capital-gains-2025.pdf` will contain:
- A header with the date range, fiat currency, and cost basis algorithm
- Summary metrics: total proceeds, total cost basis, and net gain/loss
- A detailed table of all disposals with sale date, purchase date, quantity, proceeds, cost basis, gain/loss, and holding period (short-term vs long-term)
- Totals row at the bottom of the table
