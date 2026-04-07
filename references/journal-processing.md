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

# Filter by event kind (deposit, forward, invoice, pay, trade, transaction, withdrawal)
clams journals events list --event-kind forward

# Filter by tag
clams journals events list --tag <TAG_CODE>

# Filter by note content
clams journals events list --note-contains "hardware"

# Filter by account
clams journals events list --account <ACCOUNT_LABEL_OR_ID>

# Sort oldest-first (default is newest-first)
clams journals events list --ascending

# Wide output (shows accounts, tags, excluded, note preview)
clams journals events list --wide
```

## Pagination

The `--limit` flag accepts 1–500 (default: 10). When there are more results, the JSON response includes a `next_cursor` field. Pass it back with `--cursor` to fetch the next page. When `next_cursor` is `null`, you've reached the last page.

```bash
# First page
clams journals events list --limit 500 --connection <LABEL> --machine --format json

# Next page (use next_cursor value from previous response)
clams journals events list --limit 500 --connection <LABEL> --machine --format json \
  --cursor <CURSOR>
```

Response shape:
```json
{
  "data": {
    "items": [...],
    "next_cursor": "<opaque-string-or-null>"
  }
}
```

### Counting events

There is no dedicated count endpoint. To get an exact event count, paginate through all pages and sum `len(items)` on each page. For connections with many events (tens of thousands), this requires many requests — add a 0.5 s delay between pages to avoid rate limiting (see Gotchas in SKILL.md).

Get a single event:

```bash
clams journals events get <EVENT_ID>

# Show entry signatures (needed for account adjustments)
clams journals events get <EVENT_ID> --show-signatures
```

For on-chain transactions, the blockchain txid is the event ID. If a user provides a txid, use it directly:

```bash
clams journals events get <TXID>
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
