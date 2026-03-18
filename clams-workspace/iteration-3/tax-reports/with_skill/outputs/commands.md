# Tax Season 2025 — Command Transcript

Everything is already synced and journals are processed, so we go straight to
generating the three reports the accountant needs.

---

## 1. Capital Gains Report (PDF) — full year 2025

Pipe the JSON output through the capital-gains render script to produce a PDF
on the Desktop.

```bash
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z --end 2025-12-31T23:59:59Z \
  --machine --format json \
  | scripts/render-capital-gains.sh --pdf ~/Desktop/capital-gains-2025.pdf
```

This covers every disposal event from January 1 through December 31, 2025.

---

## 2. Journal Entries (CSV)

Journal entries only support CSV output. Write the file directly to the
Desktop.

```bash
clams reports journal-entries \
  --format csv --output ~/Desktop/journal-entries-2025.csv
```

---

## 3. Balance Sheet (PDF)

Pipe the JSON output through the balance-sheet render script to produce a PDF
on the Desktop.

```bash
clams reports balance-sheet \
  --machine --format json \
  | scripts/render-balance-sheet.sh --pdf ~/Desktop/balance-sheet-2025.pdf
```

---

## Summary

| Report | Format | Output Path |
|---|---|---|
| Capital Gains (2025) | PDF | `~/Desktop/capital-gains-2025.pdf` |
| Journal Entries | CSV | `~/Desktop/journal-entries-2025.csv` |
| Balance Sheet | PDF | `~/Desktop/balance-sheet-2025.pdf` |

Three commands total. No sync or journal processing needed since the user
confirmed both are already done.
