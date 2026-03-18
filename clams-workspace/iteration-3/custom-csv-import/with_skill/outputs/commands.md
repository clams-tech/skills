# Importing a Custom Exchange CSV into Clams

Your exchange CSV does not match any of the built-in connection kinds (Phoenix, River, etc.), so you need to use a **Custom** connection and transform your CSV into the Clams **Trades** archive format before importing.

The overall workflow is:

1. Create a `Custom` connection for the exchange
2. Transform the CSV into Clams-compatible JSON (Trades archive format)
3. Import the JSON via `clams connections import`
4. Process journals
5. Check for quarantined events
6. Verify and generate reports

---

## Step 1: Verify your current setup

Confirm that your workspace and profile are configured and the CLI is authenticated.

```bash
scripts/verify-state.sh
```

Check that `auth`, `context` sections show `ok: true`. If not, run `clams login` and/or `clams context set --profile <PROFILE_ID>` to fix.

---

## Step 2: Create a Custom connection for your exchange

Since this is a generic exchange export that doesn't match a built-in kind, create a `Custom` connection.

```bash
clams connections create --label exchange --kind Custom --machine --format json
```

This creates a connection labeled `exchange` that accepts manual/custom imports. No configuration payload is needed for the `Custom` kind.

---

## Step 3: Inspect the expected Trades archive format

Before transforming your CSV, check what fields the Trades archive type expects.

```bash
clams connections import --help
```

The Trades archive type is one of the supported `--archive-type` values. The import accepts JSON via `--file` or `--stdin`.

---

## Step 4: Transform your CSV into Clams Trades JSON

Your CSV has rows of different types (Buy, Sell, Deposit, Withdrawal) with varying fields. You need to convert each row into a JSON trade record.

The key mapping from your CSV columns to Clams trade fields:

| CSV Column | Notes |
|---|---|
| `Date` | Already in RFC3339/ISO8601 format -- good |
| `Type` | Buy, Sell, Deposit, Withdrawal |
| `Asset` | BTC |
| `Amount` | The BTC amount (needs conversion to millisatoshis: multiply by 100,000,000,000) |
| `Price` | USD price per BTC at time of trade |
| `Fee` | Fee amount |
| `Fee Asset` | USD or sats |
| `Total` | Total USD cost/proceeds |

Create a script to perform the transformation. Save this as `~/transform-trades.sh`:

```bash
cat > ~/transform-trades.sh << 'SCRIPT'
#!/usr/bin/env bash
#
# Transforms exchange-trades.csv into Clams Trades JSON format.
# Usage: ./transform-trades.sh ~/Downloads/exchange-trades.csv > trades.json
#

set -euo pipefail

INPUT="$1"

# Use jq to build the JSON array from CSV.
# First, skip the header and parse each line.

tail -n +2 "$INPUT" | python3 -c "
import csv, json, sys
from datetime import datetime

trades = []
reader = csv.DictReader(open(sys.argv[1]))
for row in reader:
    # Convert BTC amount to millisatoshis (1 BTC = 100,000,000,000 msat)
    amount_btc = float(row['Amount'])
    amount_msat = int(amount_btc * 100_000_000_000)

    # Parse fee -- handle sats vs USD
    fee_msat = 0
    if row['Fee'] and row['Fee Asset']:
        if row['Fee Asset'] == 'sats':
            fee_msat = int(float(row['Fee']) * 1_000)  # sats to msat
        elif row['Fee Asset'] == 'USD':
            # Store USD fee as-is in the fiat fee field
            pass

    trade = {
        'timestamp': row['Date'],
        'type': row['Type'].lower(),
        'amount_msat': amount_msat,
    }

    if row['Price']:
        trade['price_per_btc'] = float(row['Price'])

    if row['Fee'] and row['Fee Asset'] == 'USD':
        trade['fee_fiat'] = float(row['Fee'])
        trade['fee_fiat_currency'] = 'USD'
    elif row['Fee'] and row['Fee Asset'] == 'sats':
        trade['fee_msat'] = fee_msat

    if row['Total']:
        trade['total_fiat'] = float(row['Total'])
        trade['total_fiat_currency'] = 'USD'

    trades.append(trade)

print(json.dumps(trades, indent=2))
" "$INPUT"
SCRIPT
chmod +x ~/transform-trades.sh
```

Run the transformation:

```bash
~/transform-trades.sh ~/Downloads/exchange-trades.csv > ~/Downloads/exchange-trades.json
```

Review the output to verify it looks correct:

```bash
cat ~/Downloads/exchange-trades.json
```

Expected output should be a JSON array of trade objects with timestamps, types, amounts in millisatoshis, prices, and fees.

---

## Step 5: Import the Trades JSON into Clams

```bash
clams connections import \
  --label exchange \
  --archive-type Trades \
  --file ~/Downloads/exchange-trades.json \
  --machine --format json
```

This imports all five records (2 buys, 1 sell, 1 deposit, 1 withdrawal) into the `exchange` connection.

---

## Step 6: Process journals

This is mandatory after every import. Without this step, reports will be empty.

```bash
clams journals process --machine --format json
```

---

## Step 7: Check for quarantined events

Some transactions (especially deposits and withdrawals) may be quarantined if the journal processor cannot classify them automatically.

```bash
clams journals quarantined --machine --format json
```

If quarantined events exist, inspect each one:

```bash
clams journals quarantine show --event-id <EVENT_ID> --machine --format json
```

Resolve as needed (the deposit and withdrawal rows may need resolution depending on how Clams classifies them). For example, if the deposit is quarantined:

```bash
clams journals quarantine resolve missing-address \
  --event-id <EVENT_ID> \
  --machine --format json
```

After resolving all quarantined events, re-process journals:

```bash
clams journals process --machine --format json
```

Verify quarantine is clear:

```bash
clams journals quarantined --machine --format json
```

---

## Step 8: Verify the imported data

List the journal events to confirm all trades were imported correctly:

```bash
clams journals events list --connection exchange --wide --machine --format json
```

You should see 5 events corresponding to your CSV rows.

---

## Step 9: Generate reports

Now you can generate reports. For example, to see a quick balance sheet:

```bash
clams reports balance-sheet --format plain
```

Or to see capital gains for the 2025 tax year:

```bash
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z \
  --end 2025-12-31T23:59:59Z \
  --format plain
```

---

## Summary of all commands in order

```bash
# 1. Verify setup
scripts/verify-state.sh

# 2. Create a Custom connection
clams connections create --label exchange --kind Custom --machine --format json

# 3. Transform the CSV to JSON (run the transform script)
~/transform-trades.sh ~/Downloads/exchange-trades.csv > ~/Downloads/exchange-trades.json

# 4. Import the trades
clams connections import \
  --label exchange \
  --archive-type Trades \
  --file ~/Downloads/exchange-trades.json \
  --machine --format json

# 5. Process journals
clams journals process --machine --format json

# 6. Check and resolve quarantine
clams journals quarantined --machine --format json
# (resolve any quarantined events as needed, then re-process)

# 7. Verify imported events
clams journals events list --connection exchange --wide --machine --format json

# 8. Generate reports
clams reports balance-sheet --format plain
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z \
  --end 2025-12-31T23:59:59Z \
  --format plain
```
