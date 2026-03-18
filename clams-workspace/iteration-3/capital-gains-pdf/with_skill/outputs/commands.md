# Capital Gains 2025 PDF Report — Command Transcript

The user already has wallets synced and journals processed, so we skip the
sync and `clams journals process` steps and go straight to report generation.

## 1. Generate the capital gains report as a PDF

The capital gains report requires `--start` and `--end` flags with RFC 3339 UTC
timestamps. For the full 2025 calendar year that means January 1 through
December 31. We pipe the JSON output through the render script to produce the
PDF.

```bash
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z --end 2025-12-31T23:59:59Z \
  --machine --format json \
  | scripts/render-capital-gains.sh --pdf ~/Desktop/capital-gains-2025.pdf
```

**What this does:**

- `clams reports capital-gains` generates the capital gains report.
- `--start 2025-01-01T00:00:00Z --end 2025-12-31T23:59:59Z` scopes the report
  to the 2025 tax year.
- `--machine --format json` outputs structured JSON (required for piping to the
  render script).
- `| scripts/render-capital-gains.sh --pdf ~/Desktop/capital-gains-2025.pdf`
  takes that JSON on stdin and renders it to a PDF file at the specified path.

That single pipeline is the only command needed. The PDF will be saved to
`~/Desktop/capital-gains-2025.pdf`, ready to hand off to your accountant.
