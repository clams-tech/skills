# Command Transcript: Troubleshoot Empty Balance Sheet & Tag Business Expenses

## Part 1: Diagnose and Fix the Empty Balance Sheet

The user synced their lightning node yesterday and ran a balance sheet, but it shows nothing. According to the skill's Gotchas section, the #1 cause of empty reports is forgetting to run `clams journals process` after syncing. The troubleshooting runbook confirms this and provides a diagnostic sequence.

### Step 1: Run the verification script for an overall state check

```bash
scripts/verify-state.sh
```

This returns JSON with sections for auth, context, connections, journals, and quarantine, plus a `summary.all_ok` boolean. It will quickly reveal whether the issue is a missing processing step, missing connections, or something else.

### Step 2: Check whether any journal events exist

```bash
clams journals events list --limit 1 --machine --format json
```

If this returns an empty array, journals have never been processed. Since the user already synced yesterday, the most likely cause is that `clams journals process` was never run afterward.

### Step 3: Process journals

```bash
clams journals process --machine --format json
```

This builds the double-entry ledger from the synced data. It must run after every sync and before generating any report. This is the step most likely missing.

### Step 4: Check for quarantined events

```bash
clams journals quarantined --machine --format json
```

Quarantined events are ambiguous transactions that the journal processor could not classify automatically. Unresolved quarantined events are omitted from reports and can cause numbers to look wrong or reports to appear empty. If any quarantined items are returned, they should be inspected and resolved (see Part 1b below).

### Step 5: Re-run the balance sheet report

```bash
clams reports balance-sheet --format plain
```

This displays the balance sheet in the terminal. If journals were processed successfully in Step 3, this should now show data.

### Step 6 (if Step 5 still shows nothing): Verify connections exist and have data

```bash
clams connections list --machine --format json
```

If connections exist but still no events after processing, re-sync and re-process:

```bash
clams connections sync --all --machine --format json
clams journals process --machine --format json
clams reports balance-sheet --format plain
```

---

### Part 1b: Resolve Quarantined Events (if any were found in Step 4)

If Step 4 returned quarantined items, inspect each one:

```bash
clams journals quarantine show --event-id <EVENT_ID> --machine --format json
```

Resolve based on the quarantine reason:

For collaborative (shared spend / coinjoin) transactions:

```bash
clams journals quarantine resolve collaborative \
  --event-id <EVENT_ID> --fee-sats <SATS> --mode <send|transfer> \
  --machine --format json
```

For missing address transactions:

```bash
clams journals quarantine resolve missing-address \
  --event-id <EVENT_ID> --machine --format json
```

After resolving all quarantined items, re-process and verify:

```bash
clams journals process --machine --format json
clams journals quarantined --machine --format json
clams reports balance-sheet --format plain
```

---

## Part 2: Tag Transactions as Business Expenses

After the balance sheet is working, proceed to tag transactions for tax purposes. Metadata changes require re-processing journals afterward.

### Step 7: Create a "business-expense" tag

```bash
clams metadata tags create --code "business-expense" --label "Business Expense" --machine --format json
```

This creates a reusable tag with the code `business-expense` and display label "Business Expense".

### Step 8: List journal events to find the ones to tag

```bash
clams journals events list --wide --limit 50 --machine --format json
```

The `--wide` flag includes accounts, tags, excluded status, and note previews. The user should review these events to identify which ones are business expenses. The output contains event IDs needed for tagging.

### Step 9: Apply the tag to each business expense transaction

Repeat this command for each event ID the user identifies as a business expense:

```bash
clams metadata records tags add --event-id <EVENT_ID_1> --tag business-expense --machine --format json
clams metadata records tags add --event-id <EVENT_ID_2> --tag business-expense --machine --format json
clams metadata records tags add --event-id <EVENT_ID_3> --tag business-expense --machine --format json
```

Replace `<EVENT_ID_1>`, `<EVENT_ID_2>`, `<EVENT_ID_3>` with the actual event IDs from Step 8. Run one command per transaction to tag.

### Step 10 (optional): Add notes to tagged transactions for additional context

```bash
clams metadata records note set --event-id <EVENT_ID_1> --note "Server hosting payment" --machine --format json
clams metadata records note set --event-id <EVENT_ID_2> --note "Hardware purchase" --machine --format json
```

Notes provide free-text context on each event, useful for tax documentation.

### Step 11: Re-process journals so tags take effect in reports

```bash
clams journals process --machine --format json
```

Tags, notes, exclusions, rate overrides, and account adjustments do not take effect until journals are re-processed.

### Step 12: Verify the tags were applied

```bash
clams journals events list --tag business-expense --wide --machine --format json
```

This filters the event list to only show events tagged with `business-expense`, confirming the tags are in place.

### Step 13: Re-run the balance sheet to confirm everything is still correct

```bash
clams reports balance-sheet --format plain
```

This confirms the balance sheet still renders correctly after the metadata changes and re-processing.

---

## Summary of Command Order

1. `scripts/verify-state.sh` -- overall state check
2. `clams journals events list --limit 1 --machine --format json` -- check if events exist
3. `clams journals process --machine --format json` -- process journals (the likely fix)
4. `clams journals quarantined --machine --format json` -- check for quarantined events
5. `clams reports balance-sheet --format plain` -- re-run the balance sheet
6. (if needed) `clams connections list --machine --format json` -- verify connections
7. `clams metadata tags create --code "business-expense" --label "Business Expense" --machine --format json` -- create tag
8. `clams journals events list --wide --limit 50 --machine --format json` -- find events to tag
9. `clams metadata records tags add --event-id <EVENT_ID> --tag business-expense --machine --format json` -- tag each event (repeat per event)
10. (optional) `clams metadata records note set --event-id <EVENT_ID> --note "<description>" --machine --format json` -- add notes
11. `clams journals process --machine --format json` -- re-process after metadata changes
12. `clams journals events list --tag business-expense --wide --machine --format json` -- verify tags
13. `clams reports balance-sheet --format plain` -- final balance sheet check
