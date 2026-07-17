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
clams journals events list --sort asc

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

Use the dedicated count command — it reads the latest processed snapshot (run `clams journals process` first):

```bash
clams journals events count --machine --format json
```

The response already breaks counts down, so you do **not** need to paginate for per-connection or per-kind totals:

```json
{
  "data": {
    "unique_total": 126,
    "by_event_kind": [ { "event_kind": "pay", "count": 16 }, ... ],
    "by_connection": [ { "connection_label": "cold-storage", "total": 20,
                         "by_event_kind": [ { "event_kind": "transaction", "count": 20 } ] }, ... ]
  }
}
```

Caveats (both observed against the live CLI):
- `count` takes **no filter flags**. For a count filtered by a dimension it doesn't pre-group — tag, note, date range, account — paginate `clams journals events list` with that filter and sum `len(items)` per page (add a 0.5 s delay between pages; see Gotchas in SKILL.md).
- `count` can fail with `CLAMS_E_UNKNOWN` ("snapshot rows are not ordered by event cursor key") on profiles that contain Liquid peg-bridge events. If it errors, fall back to paginating `clams journals events list`.

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

## Quarantine: Diagnose Root Cause

A quarantine that looks collaborative (multiple or unrecognized spent inputs) often is **not** — it is frequently an artifact of incomplete onchain sync. **Surface the quarantine to the user before producing any reports**, because unresolved quarantines are omitted and make reports incomplete. Then ask, in plain language, which of these two root causes applies:

1. **Unrecognized spent inputs from incomplete onchain sync.** The onchain sync may not have picked up every transaction or UTXO, so the processor sees inputs it can't attribute to the wallet and flags the spend as collaborative. This happens when the wallet's address usage has a larger gap than the connection's `gap_limit` — for example when an xpub or descriptor has been imported into multiple wallets that derive addresses at different indexes, or when the same xpub/descriptor has also been used by BTCPay Server, Zaprite, or another invoice generator that leaves large address gaps. **Fix: increase the gap limit and re-sync before resolving manually** (see below).
2. **Actual collaborative or privacy-preserving activity.** The user genuinely did a coinjoin, payjoin, or similar shared-input transaction. **Fix: resolve manually** as collaborative (see [Quarantine: Resolve](#quarantine-resolve)).

Guidance:
- Do **not** assume coinjoin / privacy-preserving activity, and do **not** silently resolve or continue — ask and let the user confirm which root cause applies.
- Prefer a wider-gap re-sync **only** when the user's answer points to missing wallet history or UTXOs. If they confirm real collaborative activity, skip the re-sync and resolve manually.

### Re-sync with a larger gap limit (root cause 1)

Raise the gap limit on the affected on-chain connection(s), re-sync, then re-process. The processor may now recognize the previously unknown inputs and clear the quarantine on its own. Use the dedicated `--gap-limit` flag — do **not** rebuild the whole `--configuration` JSON.

```bash
# 1. Raise the gap limit (XPub, Descriptor, and LiquidDescriptor connections only).
#    The default gap limit is 20; large external gaps may need 100–500+.
clams connections update <CONNECTION> --gap-limit 100

# 2. Re-sync. Use --force-full-sync so the wider gap is re-scanned from scratch
#    instead of resuming from the stored checkpoint.
clams connections sync <CONNECTION> --force-full-sync

# 3. Re-process journals
clams journals process

# 4. Re-check quarantine — it may now be clear
clams journals quarantined
```

Increase the gap limit incrementally (e.g. 20 → 100 → 500) if the first bump doesn't clear it. If the quarantine persists after a generous gap limit, the inputs are genuinely external — resolve manually as collaborative.

### Targeted discovery for a known large gap (root cause 1, alternative)

When you know roughly *where* the activity resumes — a wallet reused by BTCPay Server / Zaprite / another invoice generator often leaves a large gap and then has activity again at a high derivation index — scan that range directly instead of permanently raising the gap limit for every sync:

```bash
# Discover sparse activity on the external (receive) branch from index 7000 onward
clams connections discover <CONNECTION> --keychain external --from 7000

# Cap the scan to a range, or scan the internal (change) branch
clams connections discover <CONNECTION> --keychain external --from 7000 --to 10000
clams connections discover <CONNECTION> --keychain internal --from 2500
```

`--keychain` is `external` (receive) or `internal` (change); `--from` is the inclusive start index and `--to` an optional exclusive cap. After discovery, re-process and re-check quarantine:

```bash
clams journals process
clams journals quarantined
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

## Manual Transfer Links

A transfer link manually ties an outgoing event to the incoming event that it funds, so the engine treats the pair as one internal transfer.

**Most transfers are matched automatically and cannot (and need not) be linked by hand.** The engine rejects manual links for pairs it already handles itself:
- On-chain wallet-to-wallet (`transaction` → `transaction`) — *"wallet-to-wallet remains automatic"*
- Lightning (`pay` → `invoice`) — *"Lightning pay/invoice remains automatic"*

Manual links are only for the specific cross-rail / cross-custodian cases the engine can't auto-match. The CLI enforces which event-kind pairs are allowed and returns a clear error for anything else (`unsupported manual transfer link event kind pair`) — **read the error and follow it; do not assume a pair is supported.**

### Create a Link

```bash
clams journals transfers link \
  --from-kind <EVENT_KIND> --from-event-id <EVENT_ID> \
  --to-kind <EVENT_KIND> --to-event-id <EVENT_ID>
```

- `--from-kind` / `--to-kind`: the event kind on each side (event kinds: `deposit`, `forward`, `invoice`, `pay`, `trade`, `transaction`, `withdrawal`). Not every combination is accepted — see above.
- `--from-event-id` / `--to-event-id`: the event IDs being linked (for on-chain events this is the txid)
- `--transaction-outpoint <OUTPOINT>`: optional; pin the link to a specific output (`<txid>:<vout>`) when an on-chain transaction has several

Find the two event IDs with `clams journals events list` / `get` (see above) before linking.

### Inspect Links

```bash
# List all transfer links
clams journals transfers list

# Show a single link
clams journals transfers show <LINK_ID>
clams journals transfers show --link-id <LINK_ID>
```

### Delete a Link

```bash
clams journals transfers delete <LINK_ID>
clams journals transfers delete --link-id <LINK_ID>
```

Re-process journals after creating or deleting a link so the change takes effect.

## After Resolving

Re-process journals to apply the resolutions:

```bash
clams journals process
```

Then proceed to reports — see [reports.md](reports.md).
