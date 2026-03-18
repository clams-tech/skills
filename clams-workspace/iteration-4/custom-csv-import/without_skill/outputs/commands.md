# Importing a Custom Exchange CSV into Clams

## Background

The source file is `~/Downloads/exchange-trades.csv` with columns:

```
Date,Type,Asset,Amount,Price,Fee,Fee Asset,Total
```

This CSV contains a mix of record types: **Buy** trades, **Sell** trades, a **Deposit**, and a **Withdrawal**. Clams does not have a built-in connection kind for this specific exchange format. The CSV import feature (`--input-format csv`) is designed for known adapter formats (Phoenix, River, etc.) that the backend already knows how to parse. A generic, unknown CSV layout cannot be imported directly via `clams connections import --input-format csv` because the backend would not know how to map the columns.

The strategy is:

1. Create a **Custom** connection to represent the exchange.
2. Split the CSV into Clams-native JSON payloads -- one per archive type (Trades, Deposits, Withdrawals).
3. Import each JSON payload using `clams connections import`.
4. Process journals and verify the records.

---

## Step 0 -- Confirm your context

Make sure Clams is pointed at the right workspace and profile.

```bash
clams context current
```

Expected output shows your workspace and profile IDs. If the wrong profile is selected, set it:

```bash
clams context set --profile <YOUR_PROFILE_ID_OR_LABEL>
```

---

## Step 1 -- Create a Custom connection for the exchange

Clams needs a connection to attach imported records to. Since this exchange is not a built-in kind, use the `Custom` kind.

```bash
clams connections create --label my-exchange --kind Custom
```

This creates a connection called `my-exchange`. Note the connection ID in the output -- you can also reference it by label in later commands.

Verify it was created:

```bash
clams connections list
```

---

## Step 2 -- Understand the required JSON archive formats

Before transforming the CSV, inspect what Clams expects for each archive type. The import command accepts `--archive-type` values like `Trades`, `Deposits`, and `Withdrawals` (among others). You can check the accepted schema by looking at existing records:

```bash
clams records trades list --format json
clams records deposits list --format json
clams records withdrawals list --format json
```

These show the canonical record shape for each type.

---

## Step 3 -- Transform the CSV into Clams-native JSON files

The exchange CSV mixes multiple record types in one file. You need to split it into separate JSON payloads. Create three JSON files manually (or with a script) based on the CSV rows.

### 3a -- Trades (Buy and Sell rows)

Create a file `~/Downloads/exchange-trades-import.json` with the Buy and Sell rows translated into the Clams trades archive format. The CSV rows are:

| Date | Type | Asset | Amount | Price | Fee | Fee Asset | Total |
|---|---|---|---|---|---|---|---|
| 2025-01-15T10:30:00Z | Buy | BTC | 0.05000000 | 42000.00 | 12.50 | USD | 2112.50 |
| 2025-03-22T14:15:00Z | Sell | BTC | 0.02000000 | 65000.00 | 8.75 | USD | 1291.25 |
| 2025-06-01T09:00:00Z | Buy | BTC | 0.10000000 | 38000.00 | 25.00 | USD | 3825.00 |

Write the following JSON to `~/Downloads/exchange-trades-import.json`:

```json
[
  {
    "timestamp": "2025-01-15T10:30:00Z",
    "direction": "buy",
    "base_asset": "BTC",
    "quote_asset": "USD",
    "base_amount_sats": 5000000,
    "quote_amount_cents": 210000,
    "price_usd": 42000.00,
    "fee_amount_cents": 1250,
    "fee_asset": "USD",
    "total_amount_cents": 211250,
    "external_id": "exchange-buy-2025-01-15"
  },
  {
    "timestamp": "2025-03-22T14:15:00Z",
    "direction": "sell",
    "base_asset": "BTC",
    "quote_asset": "USD",
    "base_amount_sats": 2000000,
    "quote_amount_cents": 130000,
    "price_usd": 65000.00,
    "fee_amount_cents": 875,
    "fee_asset": "USD",
    "total_amount_cents": 129125,
    "external_id": "exchange-sell-2025-03-22"
  },
  {
    "timestamp": "2025-06-01T09:00:00Z",
    "direction": "buy",
    "base_asset": "BTC",
    "quote_asset": "USD",
    "base_amount_sats": 10000000,
    "quote_amount_cents": 380000,
    "price_usd": 38000.00,
    "fee_amount_cents": 2500,
    "fee_asset": "USD",
    "total_amount_cents": 382500,
    "external_id": "exchange-buy-2025-06-01"
  }
]
```

> **Note on unit conversions:**
> - BTC amounts are converted to satoshis: `0.05 BTC = 5,000,000 sats`
> - USD amounts are converted to cents: `$2,112.50 = 211,250 cents`
> - The exact field names depend on the Clams backend schema. The field names above (`base_amount_sats`, `quote_amount_cents`, etc.) are reasonable conventions -- adjust if `clams records trades list --format json` reveals different field names in your installation.

### 3b -- Deposits

The CSV has one deposit row:

| Date | Type | Asset | Amount |
|---|---|---|---|
| 2025-08-10T16:45:00Z | Deposit | BTC | 0.50000000 |

Create `~/Downloads/exchange-deposits-import.json`:

```json
[
  {
    "timestamp": "2025-08-10T16:45:00Z",
    "asset": "BTC",
    "amount_sats": 50000000,
    "external_id": "exchange-deposit-2025-08-10"
  }
]
```

> **Unit conversion:** `0.50000000 BTC = 50,000,000 sats`

### 3c -- Withdrawals

The CSV has one withdrawal row:

| Date | Type | Asset | Amount | Fee | Fee Asset |
|---|---|---|---|---|---|
| 2025-11-05T11:20:00Z | Withdrawal | BTC | 0.03000000 | 5000 | sats |

Create `~/Downloads/exchange-withdrawals-import.json`:

```json
[
  {
    "timestamp": "2025-11-05T11:20:00Z",
    "asset": "BTC",
    "amount_sats": 3000000,
    "fee_sats": 5000,
    "external_id": "exchange-withdrawal-2025-11-05"
  }
]
```

> **Unit conversions:**
> - `0.03000000 BTC = 3,000,000 sats`
> - The fee is already in sats: `5,000 sats`

---

## Step 4 -- Import each JSON payload

Import the three files, each with the appropriate `--archive-type`, targeting the `my-exchange` connection.

### 4a -- Import trades

```bash
clams connections import \
  --label my-exchange \
  --archive-type Trades \
  --file ~/Downloads/exchange-trades-import.json
```

### 4b -- Import deposits

```bash
clams connections import \
  --label my-exchange \
  --archive-type Deposits \
  --file ~/Downloads/exchange-deposits-import.json
```

### 4c -- Import withdrawals

```bash
clams connections import \
  --label my-exchange \
  --archive-type Withdrawals \
  --file ~/Downloads/exchange-withdrawals-import.json
```

Each command should confirm the number of records imported. Review the output for errors.

---

## Step 5 -- Process journals

After importing raw records, Clams needs to process them into journal entries for reporting.

```bash
clams journals process
```

This builds a journals snapshot from all imported records across all connections in the active profile.

---

## Step 6 -- Check for quarantined events

Some records may fail journal processing (e.g., missing rates, ambiguous data). Check for quarantined events:

```bash
clams journals quarantined
```

If any events are quarantined, inspect them individually:

```bash
clams journals quarantine show --event-id <EVENT_ID>
```

Resolve any issues following the on-screen guidance, then re-process:

```bash
clams journals process
```

---

## Step 7 -- Verify the imported records

Confirm each record type was ingested correctly.

### List trades

```bash
clams records trades list --connection my-exchange
```

You should see the 3 trade records (2 buys, 1 sell).

### List deposits

```bash
clams records deposits list --connection my-exchange
```

You should see the 1 deposit record.

### List withdrawals

```bash
clams records withdrawals list --connection my-exchange
```

You should see the 1 withdrawal record.

---

## Step 8 -- Generate reports (optional)

With journals processed, you can generate accounting reports:

```bash
# Balance sheet
clams reports balance-sheet

# Capital gains for the year
clams reports capital-gains \
  --start 2025-01-01T00:00:00Z \
  --end 2025-12-31T23:59:59Z \
  --format csv \
  --output ~/Downloads/capital-gains-2025.csv

# Journal entries
clams reports journal-entries --format csv --output ~/Downloads/journal-entries.csv
```

---

## Summary of all commands (in order)

```bash
# 0. Confirm context
clams context current

# 1. Create a Custom connection
clams connections create --label my-exchange --kind Custom

# 2. (Manual step) Create the three JSON files described above:
#    ~/Downloads/exchange-trades-import.json
#    ~/Downloads/exchange-deposits-import.json
#    ~/Downloads/exchange-withdrawals-import.json

# 3. Import trades
clams connections import \
  --label my-exchange \
  --archive-type Trades \
  --file ~/Downloads/exchange-trades-import.json

# 4. Import deposits
clams connections import \
  --label my-exchange \
  --archive-type Deposits \
  --file ~/Downloads/exchange-deposits-import.json

# 5. Import withdrawals
clams connections import \
  --label my-exchange \
  --archive-type Withdrawals \
  --file ~/Downloads/exchange-withdrawals-import.json

# 6. Process journals
clams journals process

# 7. Check for quarantined events
clams journals quarantined

# 8. Verify imported records
clams records trades list --connection my-exchange
clams records deposits list --connection my-exchange
clams records withdrawals list --connection my-exchange
```
