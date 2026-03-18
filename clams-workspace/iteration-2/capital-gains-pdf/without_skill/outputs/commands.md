# Capital Gains 2025 PDF Report — Command Transcript

## Overview

The `clams` CLI does not support PDF as a native output format. The `--format` flag
accepts: `table`, `tree`, `json`, `plain`, `csv`, `yaml`, `ids`. There is no built-in
`--format pdf` option, no `render` subcommand, and no bundled script for PDF generation.

To produce a PDF for an accountant, the approach is:

1. Export the 2025 capital gains report to CSV using `clams reports capital-gains`.
2. Convert the CSV to PDF using an external tool (e.g., `pandoc`, `python3`, `libreoffice`, or `wkhtmltopdf`).

---

## Step 1 — Generate the capital gains CSV for 2025

```bash
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z \
  --end 2025-12-31T23:59:59Z \
  --format csv \
  --output /tmp/capital-gains-2025.csv
```

**Flags explained:**

| Flag | Purpose |
|---|---|
| `--start 2025-01-01T00:00:00Z` | Inclusive UTC start of tax year 2025 |
| `--end 2025-12-31T23:59:59Z` | Inclusive UTC end of tax year 2025 |
| `--format csv` | Output as CSV (structured, convertible) |
| `--output /tmp/capital-gains-2025.csv` | Write to a temporary CSV file |

If you need to target a specific workspace/profile (instead of the current context default),
add `-w <WORKSPACE_ID>` and/or `-p <PROFILE_ID>`.

---

## Step 2 — Convert CSV to PDF

The `clams` CLI cannot do this step. You must use an external tool. Below are three
options, any one of which will work.

### Option A — Python 3 (no extra installs beyond standard library + fpdf2)

```bash
pip3 install fpdf2

python3 -c "
import csv
from fpdf import FPDF

pdf = FPDF(orientation='L', format='A4')
pdf.set_auto_page_break(auto=True, margin=15)
pdf.add_page()
pdf.set_font('Helvetica', 'B', 14)
pdf.cell(0, 10, 'Capital Gains Report — 2025', ln=True, align='C')
pdf.ln(5)

with open('/tmp/capital-gains-2025.csv', newline='') as f:
    reader = csv.reader(f)
    headers = next(reader)
    col_count = len(headers)
    col_width = (pdf.w - 20) / col_count

    pdf.set_font('Helvetica', 'B', 8)
    for h in headers:
        pdf.cell(col_width, 7, h[:20], border=1, align='C')
    pdf.ln()

    pdf.set_font('Helvetica', '', 7)
    for row in reader:
        for cell in row:
            pdf.cell(col_width, 6, str(cell)[:20], border=1)
        pdf.ln()

pdf.output('$HOME/Desktop/capital-gains-2025.pdf')
print('PDF saved to ~/Desktop/capital-gains-2025.pdf')
"
```

### Option B — Pandoc (if installed)

```bash
# Convert CSV to a simple Markdown table, then to PDF via LaTeX
python3 -c "
import csv, sys
with open('/tmp/capital-gains-2025.csv') as f:
    reader = csv.reader(f)
    headers = next(reader)
    print('# Capital Gains Report - 2025')
    print()
    print('| ' + ' | '.join(headers) + ' |')
    print('| ' + ' | '.join(['---'] * len(headers)) + ' |')
    for row in reader:
        print('| ' + ' | '.join(row) + ' |')
" > /tmp/capital-gains-2025.md

pandoc /tmp/capital-gains-2025.md \
  -o ~/Desktop/capital-gains-2025.pdf \
  --pdf-engine=xelatex \
  -V geometry:landscape \
  -V geometry:margin=1cm
```

### Option C — LibreOffice (if installed)

```bash
libreoffice --headless --convert-to pdf \
  --outdir ~/Desktop \
  /tmp/capital-gains-2025.csv

# LibreOffice names the output based on input filename, so rename:
mv ~/Desktop/capital-gains-2025.pdf ~/Desktop/capital-gains-2025.pdf 2>/dev/null || true
```

---

## Step 3 — Verify the PDF exists

```bash
ls -lh ~/Desktop/capital-gains-2025.pdf
```

---

## Summary of all commands in order

```bash
# 1. Export capital gains data for 2025 as CSV
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z \
  --end 2025-12-31T23:59:59Z \
  --format csv \
  --output /tmp/capital-gains-2025.csv

# 2. Install fpdf2 if not already available
pip3 install fpdf2

# 3. Convert CSV to PDF using Python
python3 -c "
import csv
from fpdf import FPDF

pdf = FPDF(orientation='L', format='A4')
pdf.set_auto_page_break(auto=True, margin=15)
pdf.add_page()
pdf.set_font('Helvetica', 'B', 14)
pdf.cell(0, 10, 'Capital Gains Report — 2025', ln=True, align='C')
pdf.ln(5)

with open('/tmp/capital-gains-2025.csv', newline='') as f:
    reader = csv.reader(f)
    headers = next(reader)
    col_count = len(headers)
    col_width = (pdf.w - 20) / col_count

    pdf.set_font('Helvetica', 'B', 8)
    for h in headers:
        pdf.cell(col_width, 7, h[:20], border=1, align='C')
    pdf.ln()

    pdf.set_font('Helvetica', '', 7)
    for row in reader:
        for cell in row:
            pdf.cell(col_width, 6, str(cell)[:20], border=1)
        pdf.ln()

pdf.output('$HOME/Desktop/capital-gains-2025.pdf')
print('PDF saved to ~/Desktop/capital-gains-2025.pdf')
"

# 4. Verify output
ls -lh ~/Desktop/capital-gains-2025.pdf
```

---

## Notes

- The `clams reports capital-gains` command uses the workspace and profile from your
  current context (set via `clams context set`). If you have multiple profiles, pass
  `-w <WORKSPACE_ID> -p <PROFILE_ID>` explicitly.
- Timestamps are RFC 3339 in UTC. Adjust if your tax jurisdiction uses a non-calendar
  fiscal year.
- The `--output` flag writes CSV directly to a file; without it, CSV is printed to stdout.
- PDF conversion requires an external tool because `clams` output formats are limited to:
  table, tree, json, plain, csv, yaml, ids.
