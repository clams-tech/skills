# Tax Season 2025 -- Command Transcript for Clams CLI

Everything below assumes data is already synced and journals are already processed.
The commands use the default workspace/profile from your current context.

---

## 1. Capital Gains Report as PDF (Desktop)

The Clams CLI does not have a native `--format pdf` option. The supported output
formats are: `table`, `tree`, `json`, `plain`, `csv`, and `yaml`. To produce a
PDF, we first export the capital gains report for the full 2025 calendar year as
a plain-text table, then convert it to PDF using a lightweight utility.

### Step 1a -- Generate capital gains as a plain-text file

```bash
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z \
  --end 2025-12-31T23:59:59Z \
  --format plain \
  --output ~/Desktop/capital-gains-2025.txt
```

**Explanation:** This computes the capital gains report scoped to the 2025 tax
year (January 1 through December 31) and writes the plain-text output to a file
on the Desktop. The `--start` and `--end` flags accept RFC 3339 timestamps.
The `--output` flag writes directly to a file instead of stdout.

### Step 1b -- Convert the plain-text file to PDF

```bash
cupsfilter ~/Desktop/capital-gains-2025.txt > ~/Desktop/capital-gains-2025.pdf 2>/dev/null
```

**Explanation:** `cupsfilter` is available by default on macOS and converts text
files to PDF via the CUPS printing system. Alternatively, if you have other
tools installed you could use:

- **enscript + ps2pdf:**
  ```bash
  enscript -p - ~/Desktop/capital-gains-2025.txt | ps2pdf - ~/Desktop/capital-gains-2025.pdf
  ```
- **pandoc:**
  ```bash
  pandoc ~/Desktop/capital-gains-2025.txt -o ~/Desktop/capital-gains-2025.pdf
  ```

After the PDF is created, you can optionally remove the intermediate text file:

```bash
rm ~/Desktop/capital-gains-2025.txt
```

---

## 2. Journal Entries Report as CSV

```bash
clams reports journal-entries \
  --format csv \
  --output ~/Desktop/journal-entries-2025.csv
```

**Explanation:** This generates the journal entries report and writes it as CSV
directly to the Desktop using the `--output` flag. The journal-entries
subcommand does not have `--start`/`--end` date filters; it exports the full
set of processed journal entries for the current profile. Your accountant
receives every journal entry in a spreadsheet-friendly format.

---

## 3. Balance Sheet Report as PDF (Desktop)

Like capital gains, the balance sheet has no native PDF export. The balance
sheet subcommand also does not support the `--output` flag, so we redirect
stdout to a file.

### Step 3a -- Generate the balance sheet as a plain-text file

```bash
clams reports balance-sheet \
  --format plain \
  --no-pager > ~/Desktop/balance-sheet-2025.txt
```

**Explanation:** This computes the current balance sheet for the default
workspace/profile and writes the plain-text (ASCII) tree to a file. The
`--no-pager` flag ensures the output goes straight to the redirect rather
than into an interactive pager.

### Step 3b -- Convert the plain-text file to PDF

```bash
cupsfilter ~/Desktop/balance-sheet-2025.txt > ~/Desktop/balance-sheet-2025.pdf 2>/dev/null
```

**Explanation:** Same approach as the capital gains conversion above. Use
whichever text-to-PDF tool you prefer (cupsfilter, enscript+ps2pdf, pandoc).

After the PDF is created, you can optionally remove the intermediate text file:

```bash
rm ~/Desktop/balance-sheet-2025.txt
```

---

## Summary of Output Files

| File                                    | Format | Report          |
|-----------------------------------------|--------|-----------------|
| `~/Desktop/capital-gains-2025.pdf`      | PDF    | Capital Gains   |
| `~/Desktop/journal-entries-2025.csv`    | CSV    | Journal Entries |
| `~/Desktop/balance-sheet-2025.pdf`      | PDF    | Balance Sheet   |

---

## Notes

- **No native PDF support:** Clams CLI supports `table`, `tree`, `json`,
  `plain`, `csv`, `yaml`, and `ids` output formats. PDF generation requires
  a separate conversion step as shown above.
- **Date scoping:** The `capital-gains` subcommand accepts `--start` and
  `--end` flags for date filtering. The `journal-entries` and `balance-sheet`
  subcommands do not have date-range filters and export the full dataset.
- **Workspace/profile context:** All commands above use the default
  workspace and profile from your current context (set via
  `clams context set`). To target a specific workspace or profile, add
  `-w <WORKSPACE_ID>` and/or `-p <PROFILE_ID>` to each command.
