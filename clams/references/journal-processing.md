# Journal Processing & Quarantine Resolution

All commands below require `--machine --format json` appended. Shown without for brevity.

## Process Journals

After syncing or importing data, process journals to build the double-entry ledger:

```bash
clams journals process
```

This must run **after every sync** and **before generating any reports**. Skipping this is the #1 cause of empty reports.

## Workflow

```
sync/import → process → check quarantined → resolve → re-process → reports
```

## List Journal Events

```bash
# Recent events (default limit: 10)
clams journals events list

# With date range and higher limit
clams journals events list --from 2024-01-01T00:00:00Z --to 2024-12-31T23:59:59Z --limit 50

# Filter by connection
clams journals events list --connection <LABEL_OR_ID>

# Filter by tag
clams journals events list --tag <TAG_CODE>

# Filter by note content
clams journals events list --note-contains "hardware"

# Filter by account
clams journals events list --account <ACCOUNT_LABEL_OR_ID>

# Wide output (shows accounts, tags, excluded, note preview)
clams journals events list --wide
```

Get a single event:

```bash
clams journals events get <EVENT_ID>

# Show entry signatures (needed for account adjustments)
clams journals events get <EVENT_ID> --show-signatures
```

## Quarantine: Inspect

Quarantined events are ambiguous transactions that the journal processor could not classify automatically.

```bash
# List all quarantined events
clams journals quarantined

# Or equivalently
clams journals quarantine list

# Inspect a single quarantined event
clams journals quarantine show --event-id <EVENT_ID>
```

## Quarantine: Resolve

### Collaborative (Shared Spend)

For transactions where multiple parties contributed inputs (e.g., coinjoin, payjoin):

```bash
clams journals quarantine resolve collaborative \
  --event-id <EVENT_ID> \
  --fee-sats <SATS> \
  --mode <MODE>
```

- `--fee-sats`: miner fee paid by the wallet owner, in sats
- `--mode`: `send` (payment) or `transfer` (self-transfer)

### Missing Address

For transactions with unknown addresses (balance-only reconciliation):

```bash
clams journals quarantine resolve missing-address --event-id <EVENT_ID>
```

## Quarantine: Clear Resolution

Remove a previously set manual resolution:

```bash
clams journals quarantine clear --event-id <EVENT_ID>
```

## Quarantine: List Resolutions

View all persisted quarantine resolutions:

```bash
clams journals quarantine resolutions list
```

## After Resolving

Re-process journals to apply the resolutions:

```bash
clams journals process
```

Then proceed to reports — see [reports.md](reports.md).
