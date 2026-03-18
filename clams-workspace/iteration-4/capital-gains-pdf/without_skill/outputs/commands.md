# Capital Gains 2025 PDF Report -- Command Transcript

## Goal

Generate a 2025 capital gains report from the Clams CLI and save it as a PDF at `~/Desktop/capital-gains-2025.pdf`.

## Prerequisites

- Wallets are synced and journals are already processed.
- A default workspace and profile are set in the current context (via `clams context set`).

## Important Note

The Clams CLI does not support PDF as a native output format. The available `--format` values are: `table`, `tree`, `json`, `plain`, `csv`, `yaml`, and `ids`. To produce a PDF we will first export the report as a CSV file, then convert that CSV to PDF using an external tool.

There are several common approaches for CSV-to-PDF conversion on macOS. The transcript below uses `cupsfilter` (ships with macOS) as a zero-dependency option, but alternatives are noted at the end.

---

## Commands

### Step 1 -- Generate the capital gains report as CSV

```bash
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z \
  --end 2025-12-31T23:59:59Z \
  --format csv \
  --output ~/Desktop/capital-gains-2025.csv
```

**Explanation:** Runs the `capital-gains` report scoped to the full 2025 calendar year (UTC). The `--format csv` flag produces comma-separated output, and `--output` writes it directly to a file on the Desktop. Because wallets are synced and journals are already processed, no prior sync or journal-processing step is needed. The command uses the default workspace and profile from the current context.

### Step 2 -- Convert the CSV to PDF

**Option A -- Using `cupsfilter` (built into macOS, no extra installs):**

```bash
cupsfilter ~/Desktop/capital-gains-2025.csv > ~/Desktop/capital-gains-2025.pdf
```

**Explanation:** `cupsfilter` is part of the macOS printing subsystem (CUPS). It converts the CSV (treated as plain text) into a PDF. The output is clean, monospaced text suitable for an accountant. Note: `cupsfilter` writes diagnostic messages to stderr; the PDF content goes to stdout, which is redirected to the target file.

**Option B -- Using `enscript` + `ps2pdf` (if installed via Homebrew):**

```bash
enscript --no-header -p ~/Desktop/capital-gains-2025.ps ~/Desktop/capital-gains-2025.csv
ps2pdf ~/Desktop/capital-gains-2025.ps ~/Desktop/capital-gains-2025.pdf
rm ~/Desktop/capital-gains-2025.ps
```

**Explanation:** `enscript` converts the CSV text to a PostScript file with clean formatting. `ps2pdf` (from Ghostscript) then converts PostScript to PDF. The intermediate `.ps` file is removed afterward. Install these with `brew install enscript ghostscript` if not already present.

**Option C -- Using Python (no extra installs needed on macOS):**

```bash
python3 -c "
import csv, os

# -- lightweight PDF generation without third-party packages --
input_path = os.path.expanduser('~/Desktop/capital-gains-2025.csv')
output_path = os.path.expanduser('~/Desktop/capital-gains-2025.pdf')

with open(input_path) as f:
    lines = f.read()

from subprocess import run
# Use macOS built-in textutil -> html, then cupsfilter
import tempfile, html as html_mod

with open(input_path) as f:
    reader = csv.reader(f)
    rows = list(reader)

html = '<html><body><h2>Capital Gains Report -- 2025</h2><table border=\"1\" cellpadding=\"4\" cellspacing=\"0\">'
for i, row in enumerate(rows):
    tag = 'th' if i == 0 else 'td'
    html += '<tr>' + ''.join(f'<{tag}>{html_mod.escape(cell)}</{tag}>' for cell in row) + '</tr>'
html += '</table></body></html>'

html_path = tempfile.mktemp(suffix='.html')
with open(html_path, 'w') as hf:
    hf.write(html)

run(['/usr/sbin/cupsfilter', html_path], stdout=open(output_path, 'wb'), stderr=open(os.devnull, 'wb'))
os.remove(html_path)
print(f'PDF saved to {output_path}')
"
```

**Explanation:** This self-contained Python script reads the CSV, builds an HTML table with a header row, then uses `cupsfilter` to render it as a PDF. This produces a nicely formatted tabular PDF rather than raw monospaced text.

### Step 3 -- Verify the PDF was created

```bash
ls -lh ~/Desktop/capital-gains-2025.pdf
```

**Explanation:** Confirms the PDF file exists and shows its size.

### Step 4 (optional) -- Open the PDF to review it

```bash
open ~/Desktop/capital-gains-2025.pdf
```

**Explanation:** Opens the PDF in the default viewer (Preview on macOS) so you can review it before sending it to your accountant.

### Step 5 (optional) -- Clean up the intermediate CSV

```bash
rm ~/Desktop/capital-gains-2025.csv
```

**Explanation:** Removes the intermediate CSV file if you only need the PDF.

---

## Summary

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `clams reports capital-gains --start 2025-01-01T00:00:00Z --end 2025-12-31T23:59:59Z --format csv --output ~/Desktop/capital-gains-2025.csv` | Export 2025 capital gains as CSV |
| 2 | `cupsfilter ~/Desktop/capital-gains-2025.csv > ~/Desktop/capital-gains-2025.pdf` | Convert CSV to PDF |
| 3 | `ls -lh ~/Desktop/capital-gains-2025.pdf` | Verify the PDF exists |
| 4 | `open ~/Desktop/capital-gains-2025.pdf` | (Optional) Preview the PDF |
| 5 | `rm ~/Desktop/capital-gains-2025.csv` | (Optional) Remove intermediate CSV |
