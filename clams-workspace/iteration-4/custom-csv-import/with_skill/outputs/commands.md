# Importing a Custom Exchange CSV into Clams

This transcript walks through every command needed to import
`~/Downloads/exchange-trades.csv` into Clams using a Custom connection
with a `csv_mapping` configuration.

## Prerequisites

- Clams CLI is installed and authenticated.
- A workspace and profile already exist (the user confirmed this).
- The CSV file is at `~/Downloads/exchange-trades.csv`.

---

## Step 1 -- Analyze the CSV

Before writing any mapping, review the CSV structure:

```
Date,Type,Asset,Amount,Price,Fee,Fee Asset,Total
2025-01-15T10:30:00Z,Buy,BTC,0.05000000,42000.00,12.50,USD,2112.50
2025-03-22T14:15:00Z,Sell,BTC,0.02000000,65000.00,8.75,USD,1291.25
2025-06-01T09:00:00Z,Buy,BTC,0.10000000,38000.00,25.00,USD,3825.00
2025-08-10T16:45:00Z,Deposit,BTC,0.50000000,,,,
2025-11-05T11:20:00Z,Withdrawal,BTC,0.03000000,,5000,sats,
```

There are four row types to handle:

| Row type   | Canonical type | Key observations |
|------------|---------------|------------------|
| Buy        | `trade`       | User gives USD (Total column), receives BTC (Amount column). Fee is in USD. |
| Sell       | `trade`       | User gives BTC (Amount column), receives USD (Total column). Fee is in USD. |
| Deposit    | `deposit`     | BTC received. Price/Fee/Total columns are empty. |
| Withdrawal | `withdrawal`  | BTC sent. Fee is in sats (not USD), Total is empty. |

---

## Step 2 -- Create the csv_mapping file

Save the following JSON to a file. This mapping tells Clams how to
classify each row and extract the canonical fields.

```bash
cat > mapping.json << 'MAPPING_EOF'
{
  "csv_mapping": {
    "dialect": {
      "delimiter": ",",
      "has_header": true
    },
    "row_patterns": [
      {
        "name": "buy",
        "canonical_type": "trade",
        "when": {
          "eq": {
            "a": {"lower": {"trim": {"col": "Type"}}},
            "b": {"lit": {"type": "string", "value": "buy"}}
          }
        },
        "fields": {
          "canonical_id": {"concat": [{"col": "Date"}, {"lit": {"type": "string", "value": "-buy"}}]},
          "timestamp": {"parse_rfc3339": {"trim": {"col": "Date"}}},
          "from_asset": {"lit": {"type": "string", "value": "USD"}},
          "from_amount": {"parse_decimal_sats": {"trim": {"col": "Total"}}},
          "to_asset": {"lit": {"type": "string", "value": "BTC"}},
          "to_amount": {"parse_decimal_sats_from_btc": {"trim": {"col": "Amount"}}},
          "fee_asset": {"some": {"lit": {"type": "string", "value": "USD"}}},
          "fee_amount": {"some": {"parse_decimal_sats": {"trim": {"col": "Fee"}}}}
        }
      },
      {
        "name": "sell",
        "canonical_type": "trade",
        "when": {
          "eq": {
            "a": {"lower": {"trim": {"col": "Type"}}},
            "b": {"lit": {"type": "string", "value": "sell"}}
          }
        },
        "fields": {
          "canonical_id": {"concat": [{"col": "Date"}, {"lit": {"type": "string", "value": "-sell"}}]},
          "timestamp": {"parse_rfc3339": {"trim": {"col": "Date"}}},
          "from_asset": {"lit": {"type": "string", "value": "BTC"}},
          "from_amount": {"parse_decimal_sats_from_btc": {"trim": {"col": "Amount"}}},
          "to_asset": {"lit": {"type": "string", "value": "USD"}},
          "to_amount": {"parse_decimal_sats": {"trim": {"col": "Total"}}},
          "fee_asset": {"some": {"lit": {"type": "string", "value": "USD"}}},
          "fee_amount": {"some": {"parse_decimal_sats": {"trim": {"col": "Fee"}}}}
        }
      },
      {
        "name": "deposit",
        "canonical_type": "deposit",
        "when": {
          "eq": {
            "a": {"lower": {"trim": {"col": "Type"}}},
            "b": {"lit": {"type": "string", "value": "deposit"}}
          }
        },
        "fields": {
          "canonical_id": {"concat": [{"col": "Date"}, {"lit": {"type": "string", "value": "-deposit"}}]},
          "timestamp": {"parse_rfc3339": {"trim": {"col": "Date"}}},
          "asset": {"lit": {"type": "string", "value": "BTC"}},
          "amount": {"parse_decimal_sats_from_btc": {"trim": {"col": "Amount"}}}
        }
      },
      {
        "name": "withdrawal",
        "canonical_type": "withdrawal",
        "when": {
          "eq": {
            "a": {"lower": {"trim": {"col": "Type"}}},
            "b": {"lit": {"type": "string", "value": "withdrawal"}}
          }
        },
        "fields": {
          "canonical_id": {"concat": [{"col": "Date"}, {"lit": {"type": "string", "value": "-withdrawal"}}]},
          "timestamp": {"parse_rfc3339": {"trim": {"col": "Date"}}},
          "asset": {"lit": {"type": "string", "value": "BTC"}},
          "amount": {"parse_decimal_sats_from_btc": {"trim": {"col": "Amount"}}},
          "fee": {
            "if": {
              "cond": {"eq": {"a": {"trim": {"col": "Fee Asset"}}, "b": {"lit": {"type": "string", "value": "sats"}}}},
              "then": {"some": {"to_decimal_sats_from_msat": {"mul_i128_const": {"value": {"parse_i128": {"trim": {"col": "Fee"}}}, "k": 1000}}}},
              "else": {"none": {"type": "decimal_sats"}}
            }
          }
        }
      }
    ]
  }
}
MAPPING_EOF
```

### Mapping design notes

- **Buy trades**: `from_asset` is USD and `from_amount` uses the Total column
  (the full USD outlay including the fee). `to_asset` is BTC and `to_amount`
  is parsed from the Amount column with `parse_decimal_sats_from_btc` (the
  correct parser for BTC-denominated strings like "0.05000000"). The fee is
  in USD so it uses `parse_decimal_sats`.
- **Sell trades**: The direction is reversed -- `from_asset` is BTC (user
  gives up bitcoin) and `to_asset` is USD (user receives fiat). The fee
  remains in USD.
- **Deposits**: Only need `amount` and `asset`. The Price, Fee, and Total
  columns are empty for deposits, so they are not referenced.
- **Withdrawals**: The fee is conditional. The CSV shows the fee in sats
  (Fee Asset = "sats"), so the mapping checks Fee Asset and converts sats to
  millisatoshis by multiplying by 1000 via `mul_i128_const`. If the fee
  asset is not "sats", the fee is set to None.
- **canonical_id**: Built by concatenating the Date column with the row type
  (e.g., "2025-01-15T10:30:00Z-buy") to ensure uniqueness.
- **Timestamps**: All dates are RFC 3339, so `parse_rfc3339` is used.

---

## Step 3 -- Create the Custom connection

Create a connection of kind `Custom`, passing the mapping file as the
configuration. The `--configuration-file` flag is used (not `--configuration`)
because the mapping JSON is too large to inline reliably.

```bash
clams connections create \
  --label my-exchange \
  --kind Custom \
  --configuration-file mapping.json \
  --machine --format json
```

This registers a new connection named "my-exchange" in your profile with the
csv_mapping configuration attached.

---

## Step 4 -- Import the CSV

Import the exchange CSV file into the connection:

```bash
clams connections import \
  --label my-exchange \
  --input-format csv \
  --file ~/Downloads/exchange-trades.csv \
  --machine --format json
```

This parses every row in the CSV through the mapping. Each row is classified
by the first matching `row_pattern` and converted into a canonical event
(trade, deposit, or withdrawal). The import is all-or-nothing -- if any row
fails to parse, the entire import errors out. If that happens, re-run the
command with `--debug` to see which row caused the failure.

---

## Step 5 -- Process journals

Build the double-entry ledger from the imported events. This step is
**mandatory** after every import and before any report. Skipping it is the
number one cause of empty reports.

```bash
clams journals process --machine --format json
```

---

## Step 6 -- Check for quarantined events

Quarantined events are ambiguous transactions that the journal processor
could not classify automatically. Always check after processing:

```bash
clams journals quarantined --machine --format json
```

If this returns an empty list, all events were processed cleanly and you are
done. If any events appear here, they need manual resolution before reports
will be fully accurate (quarantined events are omitted from reports).

---

## Summary

The complete sequence of commands, in order:

```bash
# 1. Write the csv_mapping configuration to a file
cat > mapping.json << 'MAPPING_EOF'
{
  "csv_mapping": {
    "dialect": {
      "delimiter": ",",
      "has_header": true
    },
    "row_patterns": [
      {
        "name": "buy",
        "canonical_type": "trade",
        "when": {
          "eq": {
            "a": {"lower": {"trim": {"col": "Type"}}},
            "b": {"lit": {"type": "string", "value": "buy"}}
          }
        },
        "fields": {
          "canonical_id": {"concat": [{"col": "Date"}, {"lit": {"type": "string", "value": "-buy"}}]},
          "timestamp": {"parse_rfc3339": {"trim": {"col": "Date"}}},
          "from_asset": {"lit": {"type": "string", "value": "USD"}},
          "from_amount": {"parse_decimal_sats": {"trim": {"col": "Total"}}},
          "to_asset": {"lit": {"type": "string", "value": "BTC"}},
          "to_amount": {"parse_decimal_sats_from_btc": {"trim": {"col": "Amount"}}},
          "fee_asset": {"some": {"lit": {"type": "string", "value": "USD"}}},
          "fee_amount": {"some": {"parse_decimal_sats": {"trim": {"col": "Fee"}}}}
        }
      },
      {
        "name": "sell",
        "canonical_type": "trade",
        "when": {
          "eq": {
            "a": {"lower": {"trim": {"col": "Type"}}},
            "b": {"lit": {"type": "string", "value": "sell"}}
          }
        },
        "fields": {
          "canonical_id": {"concat": [{"col": "Date"}, {"lit": {"type": "string", "value": "-sell"}}]},
          "timestamp": {"parse_rfc3339": {"trim": {"col": "Date"}}},
          "from_asset": {"lit": {"type": "string", "value": "BTC"}},
          "from_amount": {"parse_decimal_sats_from_btc": {"trim": {"col": "Amount"}}},
          "to_asset": {"lit": {"type": "string", "value": "USD"}},
          "to_amount": {"parse_decimal_sats": {"trim": {"col": "Total"}}},
          "fee_asset": {"some": {"lit": {"type": "string", "value": "USD"}}},
          "fee_amount": {"some": {"parse_decimal_sats": {"trim": {"col": "Fee"}}}}
        }
      },
      {
        "name": "deposit",
        "canonical_type": "deposit",
        "when": {
          "eq": {
            "a": {"lower": {"trim": {"col": "Type"}}},
            "b": {"lit": {"type": "string", "value": "deposit"}}
          }
        },
        "fields": {
          "canonical_id": {"concat": [{"col": "Date"}, {"lit": {"type": "string", "value": "-deposit"}}]},
          "timestamp": {"parse_rfc3339": {"trim": {"col": "Date"}}},
          "asset": {"lit": {"type": "string", "value": "BTC"}},
          "amount": {"parse_decimal_sats_from_btc": {"trim": {"col": "Amount"}}}
        }
      },
      {
        "name": "withdrawal",
        "canonical_type": "withdrawal",
        "when": {
          "eq": {
            "a": {"lower": {"trim": {"col": "Type"}}},
            "b": {"lit": {"type": "string", "value": "withdrawal"}}
          }
        },
        "fields": {
          "canonical_id": {"concat": [{"col": "Date"}, {"lit": {"type": "string", "value": "-withdrawal"}}]},
          "timestamp": {"parse_rfc3339": {"trim": {"col": "Date"}}},
          "asset": {"lit": {"type": "string", "value": "BTC"}},
          "amount": {"parse_decimal_sats_from_btc": {"trim": {"col": "Amount"}}},
          "fee": {
            "if": {
              "cond": {"eq": {"a": {"trim": {"col": "Fee Asset"}}, "b": {"lit": {"type": "string", "value": "sats"}}}},
              "then": {"some": {"to_decimal_sats_from_msat": {"mul_i128_const": {"value": {"parse_i128": {"trim": {"col": "Fee"}}}, "k": 1000}}}},
              "else": {"none": {"type": "decimal_sats"}}
            }
          }
        }
      }
    ]
  }
}
MAPPING_EOF

# 2. Create the Custom connection with the mapping
clams connections create \
  --label my-exchange \
  --kind Custom \
  --configuration-file mapping.json \
  --machine --format json

# 3. Import the CSV
clams connections import \
  --label my-exchange \
  --input-format csv \
  --file ~/Downloads/exchange-trades.csv \
  --machine --format json

# 4. Process journals (mandatory before any reports)
clams journals process --machine --format json

# 5. Check for quarantined events
clams journals quarantined --machine --format json
```
