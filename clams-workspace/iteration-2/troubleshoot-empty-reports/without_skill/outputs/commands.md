# Troubleshooting Empty Balance Sheet & Tagging Business Expenses

## Problem

You synced your lightning node yesterday and ran a balance sheet, but it shows nothing.
After fixing that, you want to tag several transactions as business expenses for tax purposes.

---

## Part 1: Diagnose and Fix the Empty Balance Sheet

### Step 1 -- Check overall CLI and backend health

```bash
clams status
```

Confirms authentication, backend target, and whether the CLI is properly configured.

### Step 2 -- Verify the active workspace and profile context

```bash
clams context current
```

An empty balance sheet often means no profile is selected, or the wrong profile is active.
Reports are profile-scoped, so running them without the correct context yields nothing.

### Step 3 -- List connections and confirm the lightning node connection exists

```bash
clams connections list
```

Verify your lightning node connection appears in the list and note its label or ID.
If no connections are listed, the sync would have had nothing to pull from.

### Step 4 -- Re-sync the lightning node connection to ensure data is fully pulled

```bash
clams connections sync --all
```

Even though you synced yesterday, re-syncing ensures all raw data has been fetched.
If you know the specific connection label (e.g., "core-ln"), you can target it:

```bash
clams connections sync --label core-ln
```

### Step 5 -- Check for quarantined journal events

```bash
clams journals quarantined
```

Quarantined events are transactions that could not be automatically journaled.
If all events are quarantined, the journal will be empty and so will the balance sheet.

### Step 6 -- Process journals (the most likely missing step)

```bash
clams journals process
```

This is the critical step. Syncing connections pulls raw data, but journals must be
explicitly processed to build the accounting snapshot that reports read from. If you
ran `connections sync` and then went straight to `reports balance-sheet` without
processing journals, the balance sheet would be empty.

### Step 7 -- Verify journal events now exist

```bash
clams journals events list --limit 50
```

Confirm that journal events have been created. If this list is populated, the
balance sheet should now work.

### Step 8 -- Run the balance sheet report again

```bash
clams reports balance-sheet
```

This should now display data. For a machine-readable version:

```bash
clams reports balance-sheet --format json
```

### Step 9 -- If still empty, run diagnostics

```bash
clams doctor --format json
```

Collect full diagnostic information to identify any deeper issues with the backend
or data pipeline.

---

## Part 2: Tag Transactions as Business Expenses

### Step 10 -- Create a "business-expense" tag

```bash
clams metadata tags create --code "business-expense" --label "Business Expense"
```

This creates a reusable tag that can be attached to any journal event for
categorization and tax reporting purposes.

### Step 11 -- List existing tags to confirm creation

```bash
clams metadata tags list
```

Verify the "business-expense" tag appears and note its code or ID.

### Step 12 -- List journal events to find the transactions you want to tag

```bash
clams journals events list --limit 100 --wide
```

The `--wide` flag shows accounts, tags, excluded status, and note previews. Browse
the output to identify the event IDs of the transactions you want to tag as business
expenses.

You can also filter by date range to narrow down:

```bash
clams journals events list --from 2026-01-01T00:00:00Z --to 2026-03-18T23:59:59Z --limit 100 --wide
```

Or filter by connection if you know which connection the expenses came from:

```bash
clams journals events list --connection core-ln --limit 100 --wide
```

### Step 13 -- Tag each transaction as a business expense

For each transaction you want to tag, run:

```bash
clams metadata records tags add --event-id <EVENT_ID_1> --tag business-expense
```

```bash
clams metadata records tags add --event-id <EVENT_ID_2> --tag business-expense
```

```bash
clams metadata records tags add --event-id <EVENT_ID_3> --tag business-expense
```

Replace `<EVENT_ID_1>`, `<EVENT_ID_2>`, `<EVENT_ID_3>` with the actual event IDs
from Step 12. Repeat for as many transactions as needed.

### Step 14 -- Optionally add notes to tagged transactions for audit trail

```bash
clams metadata records note set --event-id <EVENT_ID_1> --note "Server hosting payment - Q1 2026"
```

```bash
clams metadata records note set --event-id <EVENT_ID_2> --note "Software subscription renewal"
```

```bash
clams metadata records note set --event-id <EVENT_ID_3> --note "Hardware purchase for node"
```

### Step 15 -- Verify the tags were applied by listing tagged events

```bash
clams journals events list --tag business-expense --wide
```

This filters journal events to only those tagged with "business-expense", confirming
all your tags were applied correctly.

### Step 16 -- Re-process journals and regenerate the balance sheet

```bash
clams journals process
```

```bash
clams reports balance-sheet
```

After tagging, re-process journals and regenerate the balance sheet to confirm
everything is consistent.

### Step 17 -- Export journal entries for tax filing

```bash
clams reports journal-entries --format csv --output journal-entries.csv
```

Export a full CSV of all journal entries, which can be filtered externally by the
"business-expense" tag for tax preparation.

---

## Summary of the Likely Root Cause

The empty balance sheet was almost certainly caused by a missing `clams journals process`
step. The Clams pipeline is:

1. `clams connections sync` -- pulls raw data from your lightning node
2. `clams journals process` -- transforms raw data into double-entry journal events
3. `clams reports balance-sheet` -- reads processed journal data to generate the report

Skipping step 2 means the report has no journal data to read, producing an empty output.
