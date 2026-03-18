# Troubleshooting Empty Balance Sheet & Tagging Transactions as Business Expenses

## Problem Summary

The user synced their lightning node yesterday and ran a balance sheet report, but
it shows nothing. After fixing that, they want to tag several transactions as
business expenses for tax purposes.

---

## Part 1: Diagnose and Fix the Empty Balance Sheet

### Step 1 -- Check overall CLI and backend state

```
clams status
```

This confirms the CLI is authenticated, the backend is reachable, and a
workspace/profile context is set. If no context is set, the balance sheet would
have no data to report on.

### Step 2 -- Verify the current workspace and profile context

```
clams context set --help
```

```
clams connections list --format json
```

List all connections for the current profile to confirm the lightning node
connection exists and to capture its connection ID or label.

### Step 3 -- Re-sync the lightning node connection

Syncing pulls raw data from the lightning node into the Clams backend. If the
sync yesterday completed but journals were never processed afterward, the
balance sheet would be empty. Re-sync to make sure data is current:

```
clams connections sync --all
```

Or, to sync just the specific lightning connection by label (replace
`<CONNECTION_LABEL>` with the actual label from Step 2):

```
clams connections sync --label <CONNECTION_LABEL>
```

### Step 4 -- Process journals

This is the most likely root cause of the empty balance sheet. Syncing pulls
raw data, but `journals process` is required to transform that raw data into
double-entry journal entries that the balance sheet report reads from. If this
step was skipped after the sync, the balance sheet would show nothing.

```
clams journals process
```

### Step 5 -- Check for quarantined events

Some events may have been quarantined during journal processing (e.g.,
ambiguous collaborative transactions). Review them:

```
clams journals quarantined
```

If quarantined events exist, inspect and resolve each one:

```
clams journals quarantine show --event-id <EVENT_ID>
```

```
clams journals quarantine resolve collaborative --event-id <EVENT_ID> --fee-sats <SATS> --mode send
```

After resolving quarantined events, re-process journals:

```
clams journals process
```

### Step 6 -- Re-run the balance sheet report

```
clams reports balance-sheet
```

The balance sheet should now display data. For a machine-readable version:

```
clams reports balance-sheet --format json
```

---

## Part 2: Tag Transactions as Business Expenses

### Step 7 -- List existing tags to see if a "business-expense" tag already exists

```
clams metadata tags list
```

### Step 8 -- Create the "business-expense" tag (if it does not already exist)

```
clams metadata tags create --code "business-expense" --label "Business Expense"
```

### Step 9 -- List journal events to identify the transactions to tag

Browse recent journal events to find the ones that should be tagged:

```
clams journals events list --limit 50 --wide
```

To narrow the search to a specific date range:

```
clams journals events list --from 2026-03-01T00:00:00Z --to 2026-03-18T23:59:59Z --limit 50 --wide
```

To filter by a specific connection (e.g., lightning node only):

```
clams journals events list --connection <CONNECTION_LABEL> --limit 50 --wide
```

Note the `EVENT_ID` values for each transaction you want to tag.

### Step 10 -- Tag each transaction as a business expense

For each transaction that should be tagged, run:

```
clams metadata records tags add --event-id <EVENT_ID_1> --tag business-expense
```

```
clams metadata records tags add --event-id <EVENT_ID_2> --tag business-expense
```

```
clams metadata records tags add --event-id <EVENT_ID_3> --tag business-expense
```

Repeat for every transaction that qualifies as a business expense.

### Step 11 -- Optionally add a note to each tagged transaction for audit context

```
clams metadata records note set --event-id <EVENT_ID_1> --note "Server hosting payment - Q1 2026"
```

```
clams metadata records note set --event-id <EVENT_ID_2> --note "Domain renewal - March 2026"
```

```
clams metadata records note set --event-id <EVENT_ID_3> --note "VPN subscription - March 2026"
```

### Step 12 -- Re-process journals so tags are reflected in reports

```
clams journals process
```

### Step 13 -- Verify the tags were applied

List events filtered by the tag to confirm:

```
clams journals events list --tag business-expense --wide
```

### Step 14 -- Generate a filtered report for tax purposes

Run the journal entries report to produce a CSV of all entries, which can then
be filtered by the business-expense tag:

```
clams reports journal-entries --format csv --output business-expenses-2026.csv
```

Or generate a capital gains report for the tax year:

```
clams reports capital-gains --start 2026-01-01T00:00:00Z --end 2026-12-31T23:59:59Z --format csv --output capital-gains-2026.csv
```

---

## Summary of Commands in Order

| # | Command | Purpose |
|---|---------|---------|
| 1 | `clams status` | Check CLI/backend health and context |
| 2 | `clams connections list --format json` | Confirm lightning connection exists |
| 3 | `clams connections sync --all` | Re-sync all connections |
| 4 | `clams journals process` | Process raw data into journal entries (likely root cause fix) |
| 5 | `clams journals quarantined` | Check for quarantined events |
| 6 | `clams reports balance-sheet` | Verify balance sheet now shows data |
| 7 | `clams metadata tags list` | Check for existing tags |
| 8 | `clams metadata tags create --code "business-expense" --label "Business Expense"` | Create the tag |
| 9 | `clams journals events list --limit 50 --wide` | Find transactions to tag |
| 10 | `clams metadata records tags add --event-id <EVENT_ID> --tag business-expense` | Apply tag (repeat per transaction) |
| 11 | `clams metadata records note set --event-id <EVENT_ID> --note "<description>"` | Add audit notes (optional, repeat per transaction) |
| 12 | `clams journals process` | Re-process so tags appear in reports |
| 13 | `clams journals events list --tag business-expense --wide` | Verify tags were applied |
| 14 | `clams reports journal-entries --format csv --output business-expenses-2026.csv` | Export for tax filing |
