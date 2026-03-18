# Importing a Custom Exchange CSV into Clams

## Background

You have an exchange CSV export at `~/Downloads/exchange-trades.csv` with columns:
`Date, Type, Asset, Amount, Price, Fee, Fee Asset, Total`

The CSV contains a mix of record types (Buy, Sell, Deposit, Withdrawal). Clams does
not have a built-in adapter for this exchange's CSV format, so the CSV cannot be
imported directly. Instead, you need to split the rows by type, convert each group
into the JSON schema that Clams expects for the corresponding archive type, and
import each group into a `Custom` connection.

The overall workflow is:

1. Verify your workspace/profile context
2. Create a `Custom` connection for the exchange
3. Split the CSV into per-archive-type JSON files that match Clams canonical schemas
4. Import each JSON file using `clams connections import`
5. Sync the connection
6. Process journals
7. Verify the imported records
8. (Optional) Generate reports

---

## Step 1 -- Verify your workspace and profile context

Make sure your default context points to the correct workspace and profile.

```bash
clams context current
```

You should see your workspace and profile IDs. If they are not set, use:

```bash
clams context set --profile <PROFILE_ID_OR_LABEL>
```

---

## Step 2 -- Create a Custom connection for the exchange

Because Clams has no built-in adapter for this exchange's CSV format, create a
`Custom` connection. Give it a descriptive label so you can reference it later.

```bash
clams connections create --label my-exchange --kind Custom
```

Verify it was created:

```bash
clams connections list
```

Note the connection ID or label (`my-exchange`) for subsequent commands.

---

## Step 3 -- Transform the CSV into Clams-compatible JSON files

Clams `connections import` accepts JSON payloads organized by archive type. The CSV
rows map to three archive types:

| CSV `Type` value | Clams archive type |
|------------------|--------------------|
| Buy, Sell        | `Trades`           |
| Deposit          | `Deposits`         |
| Withdrawal       | `Withdrawals`      |

You need to manually convert each group of rows into the appropriate JSON schema.
Below are the JSON files you would create from the sample data.

### 3a -- Trades (`~/Downloads/exchange-trades.json`)

The Buy and Sell rows become trade records. Each trade needs a timestamp, direction,
base/quote amounts, and fee information. BTC amounts are converted to millisatoshis
(1 BTC = 100,000,000,000 msat).

Create `~/Downloads/exchange-trades.json`:

```json
[
  {
    "external_id": "trade-2025-01-15-buy",
    "timestamp": "2025-01-15T10:30:00Z",
    "direction": "buy",
    "base_asset": "BTC",
    "base_amount_msat": 5000000000,
    "quote_asset": "USD",
    "quote_amount": 2100.00,
    "price": 42000.00,
    "fee_amount": 12.50,
    "fee_asset": "USD",
    "total": 2112.50
  },
  {
    "external_id": "trade-2025-03-22-sell",
    "timestamp": "2025-03-22T14:15:00Z",
    "direction": "sell",
    "base_asset": "BTC",
    "base_amount_msat": 2000000000,
    "quote_asset": "USD",
    "quote_amount": 1300.00,
    "price": 65000.00,
    "fee_amount": 8.75,
    "fee_asset": "USD",
    "total": 1291.25
  },
  {
    "external_id": "trade-2025-06-01-buy",
    "timestamp": "2025-06-01T09:00:00Z",
    "direction": "buy",
    "base_asset": "BTC",
    "base_amount_msat": 10000000000,
    "quote_asset": "USD",
    "quote_amount": 3800.00,
    "price": 38000.00,
    "fee_amount": 25.00,
    "fee_asset": "USD",
    "total": 3825.00
  }
]
```

### 3b -- Deposits (`~/Downloads/exchange-deposits.json`)

The Deposit row (0.5 BTC received with no fee) becomes a deposit record.

Create `~/Downloads/exchange-deposits.json`:

```json
[
  {
    "external_id": "deposit-2025-08-10",
    "timestamp": "2025-08-10T16:45:00Z",
    "asset": "BTC",
    "amount_msat": 50000000000
  }
]
```

### 3c -- Withdrawals (`~/Downloads/exchange-withdrawals.json`)

The Withdrawal row (0.03 BTC sent, 5000 sat fee) becomes a withdrawal record.
The fee is 5000 sats = 5,000,000 msat.

Create `~/Downloads/exchange-withdrawals.json`:

```json
[
  {
    "external_id": "withdrawal-2025-11-05",
    "timestamp": "2025-11-05T11:20:00Z",
    "asset": "BTC",
    "amount_msat": 3000000000,
    "fee_amount_msat": 5000000000
  }
]
```

> **Note:** The exact JSON field names depend on Clams' canonical schema for each
> archive type. The names above are reasonable guesses based on the CLI's archive
> types (`Trades`, `Deposits`, `Withdrawals`). If the import rejects a file, run the
> import with `--debug` to see the expected schema, and adjust accordingly.

---

## Step 4 -- Import each JSON file into the connection

Import the three JSON files one at a time, specifying the correct `--archive-type`
for each.

### 4a -- Import trades

```bash
clams connections import \
  --label my-exchange \
  --archive-type Trades \
  --file ~/Downloads/exchange-trades.json
```

### 4b -- Import deposits

```bash
clams connections import \
  --label my-exchange \
  --archive-type Deposits \
  --file ~/Downloads/exchange-deposits.json
```

### 4c -- Import withdrawals

```bash
clams connections import \
  --label my-exchange \
  --archive-type Withdrawals \
  --file ~/Downloads/exchange-withdrawals.json
```

> If any import fails, add `--debug` to see the full error chain:
>
> ```bash
> clams connections import \
>   --label my-exchange \
>   --archive-type Trades \
>   --file ~/Downloads/exchange-trades.json \
>   --debug
> ```

---

## Step 5 -- Sync the connection

After importing, sync the connection so Clams processes the raw archives into
canonical records.

```bash
clams connections sync --label my-exchange
```

---

## Step 6 -- Process journals

Run journal processing to convert the canonical records into accounting journal
entries.

```bash
clams journals process
```

---

## Step 7 -- Verify the imported records

Check that the records were created correctly.

### 7a -- List trades

```bash
clams records trades list --connection my-exchange
```

You should see the three trade records (two buys and one sell).

### 7b -- List deposits

```bash
clams records deposits list --connection my-exchange
```

You should see the single deposit record.

### 7c -- List withdrawals

```bash
clams records withdrawals list --connection my-exchange
```

You should see the single withdrawal record.

### 7d -- Check for quarantined events

If any records could not be journaled (e.g., missing rate data or schema issues),
they will appear in the quarantine list.

```bash
clams journals quarantined
```

If there are quarantined events, inspect each one and resolve as needed:

```bash
clams journals quarantine show --event-id <EVENT_ID>
```

---

## Step 8 -- (Optional) Generate reports

With the data imported and journals processed, you can generate reports.

### Balance sheet

```bash
clams reports balance-sheet
```

### Capital gains for 2025

```bash
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z \
  --end 2025-12-31T23:59:59Z \
  --format csv \
  --output ~/Downloads/capital-gains-2025.csv
```

### Journal entries

```bash
clams reports journal-entries --format csv --output ~/Downloads/journal-entries.csv
```

---

## Summary of all commands (in order)

```bash
# 1. Verify context
clams context current

# 2. Create a Custom connection
clams connections create --label my-exchange --kind Custom

# 3. (Manual step) Create the three JSON files described above:
#    ~/Downloads/exchange-trades.json
#    ~/Downloads/exchange-deposits.json
#    ~/Downloads/exchange-withdrawals.json

# 4. Import each archive type
clams connections import --label my-exchange --archive-type Trades --file ~/Downloads/exchange-trades.json
clams connections import --label my-exchange --archive-type Deposits --file ~/Downloads/exchange-deposits.json
clams connections import --label my-exchange --archive-type Withdrawals --file ~/Downloads/exchange-withdrawals.json

# 5. Sync the connection
clams connections sync --label my-exchange

# 6. Process journals
clams journals process

# 7. Verify records
clams records trades list --connection my-exchange
clams records deposits list --connection my-exchange
clams records withdrawals list --connection my-exchange
clams journals quarantined

# 8. (Optional) Generate reports
clams reports balance-sheet
clams reports capital-gains --start 2025-01-01T00:00:00Z --end 2025-12-31T23:59:59Z --format csv --output ~/Downloads/capital-gains-2025.csv
```
