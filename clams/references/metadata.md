# Metadata: Notes, Tags, Exclusions, Rate Overrides, Adjustments

All commands below require `--machine --format json` appended. Shown without for brevity.

Metadata lets you annotate journal events with notes, tags, exclusions, manual rate overrides, and account adjustments. After changing metadata, re-process journals (`clams journals process`) for changes to take effect in reports.

## Finding Event IDs

To annotate events, you need their event IDs. List journal events to find them:

```bash
clams journals events list --limit 50
clams journals events list --wide --from 2024-01-01T00:00:00Z --to 2024-12-31T23:59:59Z
```

## List Metadata Records

```bash
clams metadata records list

# Paginate
clams metadata records list --limit 50 --cursor <CURSOR>
```

## Get a Single Record

```bash
clams metadata records get --event-id <EVENT_ID>
```

## Notes

Add a free-text note to a journal event:

```bash
clams metadata records note set --event-id <EVENT_ID> --note "Office hardware purchase"
```

Clear a note:

```bash
clams metadata records note clear --event-id <EVENT_ID>
```

## Tags

### Create a Tag

```bash
clams metadata tags create --code "business-expense" --label "Business Expense"
```

- `--code`: lowercase identifier (auto-lowercased)
- `--label`: display name

### List Tags

```bash
clams metadata tags list
```

### Get, Update, Delete a Tag

```bash
clams metadata tags get --code <CODE>
clams metadata tags update --code <CODE> --label "New Label"
clams metadata tags delete --code <CODE>
```

### Apply a Tag to an Event

```bash
clams metadata records tags add --event-id <EVENT_ID> --tag <TAG_CODE_OR_ID>
```

### Remove a Tag from an Event

```bash
clams metadata records tags delete --event-id <EVENT_ID> --tag <TAG_CODE_OR_ID>
```

## Exclusions

Exclude an event from reports:

```bash
clams metadata records excluded set --event-id <EVENT_ID> --excluded true
```

Re-include an excluded event:

```bash
clams metadata records excluded set --event-id <EVENT_ID>
```

(Omitting `--excluded` removes the exclusion.)

## Rate Overrides

Override the BTC-fiat exchange rate used for a specific event:

```bash
clams metadata records rate set --event-id <EVENT_ID> --btc-fiat-rate 70000
```

Clear a rate override:

```bash
clams metadata records rate clear --event-id <EVENT_ID>
```

## Account Adjustments

Reassign a journal entry to a different account. First get the entry signatures:

```bash
clams journals events get <EVENT_ID> --show-signatures
```

Then add the adjustment:

```bash
# By entry signature
clams metadata records adjustments add \
  --event-id <EVENT_ID> \
  --entry-signature <SIG> \
  --account-id <ACCOUNT_ID>

# By entry index (0-based)
clams metadata records adjustments add \
  --event-id <EVENT_ID> \
  --entry-index 0 \
  --account-id <ACCOUNT_ID>
```

Remove an adjustment:

```bash
clams metadata records adjustments delete --event-id <EVENT_ID> --entry-signature <SIG>
```

## After Changing Metadata

Re-process journals to apply metadata changes to reports:

```bash
clams journals process
```
