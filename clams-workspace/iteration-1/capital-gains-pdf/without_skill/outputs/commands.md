# Capital Gains 2025 PDF Report -- Command Transcript

## Overview

The `clams` CLI (v1.0.0-beta.8) does not support PDF as a native output format.
The supported `--format` values are: `table`, `tree`, `json`, `plain`, `csv`,
`yaml`, `ids`. To produce a PDF for an accountant, we generate the report as CSV
and then convert the CSV to PDF using a standard command-line tool.

The user's wallets are synced and journals are already processed, so no
`clams journals process` or `clams connections sync` steps are needed.

---

## Step 1 -- Generate the 2025 capital gains report as CSV

```bash
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z \
  --end 2025-12-31T23:59:59Z \
  --format csv \
  --output ~/Desktop/capital-gains-2025.csv
```

**Flags explained:**

| Flag | Purpose |
|------|---------|
| `--start 2025-01-01T00:00:00Z` | Inclusive UTC start of tax year 2025 |
| `--end 2025-12-31T23:59:59Z` | Inclusive UTC end of tax year 2025 |
| `--format csv` | Emit the report in CSV format |
| `--output ~/Desktop/capital-gains-2025.csv` | Write CSV to a file on the Desktop |

The `--workspace` and `--profile` flags are omitted because the user already has
a default context set (verified by `clams context current`). If multiple
profiles exist, pass `-w <WORKSPACE_ID> -p <PROFILE_ID>` explicitly.

---

## Step 2 -- Convert the CSV to PDF

The `clams` CLI has no built-in PDF renderer. Use one of the following
approaches to convert the CSV file to PDF. Option A is the most portable on
macOS; Option B works if Python 3 is available.

### Option A -- Using `cupsfilter` (macOS built-in, no extra dependencies)

```bash
cupsfilter ~/Desktop/capital-gains-2025.csv > ~/Desktop/capital-gains-2025.pdf
```

### Option B -- Using Python 3 with the `csv` and `fpdf2` libraries

```bash
pip3 install fpdf2
```

```bash
python3 - ~/Desktop/capital-gains-2025.csv ~/Desktop/capital-gains-2025.pdf <<'PYEOF'
import csv, sys
from fpdf import FPDF

input_path = sys.argv[1]
output_path = sys.argv[2]

with open(input_path, newline="") as f:
    reader = csv.reader(f)
    rows = list(reader)

pdf = FPDF(orientation="L", format="Letter")
pdf.set_auto_page_break(auto=True, margin=15)
pdf.add_page()
pdf.set_font("Helvetica", "B", 14)
pdf.cell(0, 10, "Capital Gains Report -- Tax Year 2025", ln=True, align="C")
pdf.ln(4)

if rows:
    headers = rows[0]
    data = rows[1:]
    col_count = len(headers)
    col_width = (pdf.w - 20) / col_count

    pdf.set_font("Helvetica", "B", 8)
    for h in headers:
        pdf.cell(col_width, 7, h, border=1)
    pdf.ln()

    pdf.set_font("Helvetica", "", 7)
    for row in data:
        for cell in row:
            pdf.cell(col_width, 6, str(cell)[:40], border=1)
        pdf.ln()

pdf.output(output_path)
print(f"PDF written to {output_path}")
PYEOF
```

### Option C -- Using `enscript` + `ps2pdf` (if available)

```bash
enscript ~/Desktop/capital-gains-2025.csv \
  --output=- \
  --no-header \
  --font=Courier8 \
  --media=Letter \
  | ps2pdf - ~/Desktop/capital-gains-2025.pdf
```

---

## Step 3 -- Verify the output

```bash
ls -lh ~/Desktop/capital-gains-2025.pdf
```

Optionally open it to confirm:

```bash
open ~/Desktop/capital-gains-2025.pdf
```

---

## Step 4 -- Clean up the intermediate CSV (optional)

```bash
rm ~/Desktop/capital-gains-2025.csv
```

---

## Complete single-pipeline example (Steps 1 + 2A combined)

```bash
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z \
  --end 2025-12-31T23:59:59Z \
  --format csv \
  --output ~/Desktop/capital-gains-2025.csv \
  && cupsfilter ~/Desktop/capital-gains-2025.csv > ~/Desktop/capital-gains-2025.pdf \
  && rm ~/Desktop/capital-gains-2025.csv
```

This produces `~/Desktop/capital-gains-2025.pdf` ready to send to the accountant.
