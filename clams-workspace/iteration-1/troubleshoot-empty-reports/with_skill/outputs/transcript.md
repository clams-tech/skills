# Transcript: Troubleshoot Empty Balance Sheet & Tag Transactions as Business Expenses

## Problem

The user synced their lightning node yesterday and ran a balance sheet, but it shows nothing. They also want to tag a few transactions as business expenses for tax purposes.

## Diagnosis

The #1 cause of empty reports is forgetting to run `clams journals process` after syncing. The skill's Gotchas section calls this out explicitly: "Empty reports? You forgot `clams journals process`." The correct processing order is: sync -> `clams journals process` -> reports.

---

## Part 1: Fix the Empty Balance Sheet

### Step 1 -- Run a full state verification to understand what is broken

```bash
scripts/verify-state.sh
```

This returns JSON with sections for `auth`, `context`, `connections`, `journals`, and `quarantine`, plus a `summary.all_ok` boolean. Reading `summary.issues` will tell us exactly what is wrong.

### Step 2 -- Check whether journal events exist

```bash
clams journals events list --limit 1 --machine --format json
```

If this returns an empty array, journals have not been processed. If events exist, the issue is elsewhere (date range, quarantine, etc.).

### Step 3 -- Process journals (the most likely fix)

Since the user synced yesterday but the balance sheet is empty, the most probable cause is that `clams journals process` was never run after the sync. Process now:

```bash
clams journals process --machine --format json
```

### Step 4 -- Check for quarantined events

Quarantined events are omitted from reports and can cause numbers to look wrong or reports to appear empty:

```bash
clams journals quarantined --machine --format json
```

If quarantined items exist, inspect each one:

```bash
clams journals quarantine show --event-id <EVENT_ID> --machine --format json
```

Resolve based on the quarantine reason. For collaborative transactions (coinjoin, payjoin):

```bash
clams journals quarantine resolve collaborative \
  --event-id <EVENT_ID> --fee-sats <SATS> --mode <send|transfer> \
  --machine --format json
```

For missing address issues:

```bash
clams journals quarantine resolve missing-address \
  --event-id <EVENT_ID> --machine --format json
```

If any quarantine items were resolved, re-process journals:

```bash
clams journals process --machine --format json
```

Then verify the quarantine is clear:

```bash
clams journals quarantined --machine --format json
```

### Step 5 -- Re-run the balance sheet to confirm the fix

Quick look in the terminal:

```bash
clams reports balance-sheet --format plain
```

This should now show data. Display the CLI output directly without reformatting it.

---

## Part 2: Tag Transactions as Business Expenses

### Step 6 -- Create the "business-expense" tag

```bash
clams metadata tags create --code "business-expense" --label "Business Expense" --machine --format json
```

### Step 7 -- List journal events to find the transactions to tag

```bash
clams journals events list --wide --machine --format json
```

Use `--wide` to see accounts, tags, excluded status, and note previews. Increase the limit or add date filters if needed:

```bash
clams journals events list --wide --limit 50 --machine --format json
```

From the output, identify the event IDs of the transactions the user wants to tag as business expenses. The event IDs will be in the `.data` array of the JSON response.

### Step 8 -- Apply the tag to each target transaction

Repeat for each transaction the user identifies (replace `<EVENT_ID>` with the actual event ID):

```bash
clams metadata records tags add --event-id <EVENT_ID_1> --tag business-expense --machine --format json
```

```bash
clams metadata records tags add --event-id <EVENT_ID_2> --tag business-expense --machine --format json
```

```bash
clams metadata records tags add --event-id <EVENT_ID_3> --tag business-expense --machine --format json
```

### Step 9 -- Re-process journals so the tags take effect in reports

Metadata changes (including tags) do not appear in reports until journals are re-processed:

```bash
clams journals process --machine --format json
```

### Step 10 -- Verify the tags were applied

List events filtered by the new tag to confirm:

```bash
clams journals events list --tag business-expense --wide --machine --format json
```

### Step 11 -- Regenerate the balance sheet to confirm everything is working

```bash
clams reports balance-sheet --format plain
```

---

## Summary of Commands in Order

| # | Command | Purpose |
|---|---------|---------|
| 1 | `scripts/verify-state.sh` | Full state check to identify issues |
| 2 | `clams journals events list --limit 1 --machine --format json` | Check if any journal events exist |
| 3 | `clams journals process --machine --format json` | Process journals (the fix for empty reports) |
| 4 | `clams journals quarantined --machine --format json` | Check for quarantined events blocking reports |
| 5 | `clams reports balance-sheet --format plain` | Confirm the balance sheet now has data |
| 6 | `clams metadata tags create --code "business-expense" --label "Business Expense" --machine --format json` | Create the business-expense tag |
| 7 | `clams journals events list --wide --limit 50 --machine --format json` | List events to find transaction IDs to tag |
| 8 | `clams metadata records tags add --event-id <EVENT_ID> --tag business-expense --machine --format json` | Apply the tag to each selected transaction (repeat per event) |
| 9 | `clams journals process --machine --format json` | Re-process so tagged metadata appears in reports |
| 10 | `clams journals events list --tag business-expense --wide --machine --format json` | Verify tags were applied correctly |
| 11 | `clams reports balance-sheet --format plain` | Final confirmation that everything looks correct |
