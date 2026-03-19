# Custom Connections & CSV Mapping

When the user's data source doesn't match a built-in connection kind (Phoenix, River, etc.), use a **Custom** connection with a `csv_mapping` configuration. This lets Clams parse arbitrary exchange CSVs directly — no intermediate transform scripts needed.

## Workflow

```
1. Inspect the user's CSV (headers, row types, amount formats)
2. Build a csv_mapping JSON that classifies rows and maps columns to canonical fields
3. clams connections create --label <label> --kind Custom --configuration-file mapping.json
4. clams connections import --label <label> --input-format csv --file <path-to-csv>
5. clams journals process
6. clams journals quarantined   (check for ambiguous events)
```

The csv_mapping is passed as the connection's `--configuration` (inline JSON) or `--configuration-file` (path to JSON file). The configuration-file approach is strongly preferred — mapping JSON is verbose and error-prone to inline.

## csv_mapping Structure

```json
{
  "csv_mapping": {
    "dialect": {
      "delimiter": ",",
      "has_header": true
    },
    "row_patterns": [
      {
        "name": "unique-pattern-name",
        "canonical_type": "deposit|withdrawal|trade|pay|invoice",
        "when": { /* bool expression to classify this row */ },
        "fields": { /* map canonical field names → expressions */ }
      }
    ]
  }
}
```

### dialect

| Field | Required | Default | Notes |
|---|---|---|---|
| `delimiter` | yes | — | Single character: `","`, `"\t"`, `";"`, etc. |
| `has_header` | yes | — | Must be `true` (headerless CSVs not supported) |
| `quote` | no | `"\""` | Quote character |

### row_patterns

Each pattern classifies a subset of CSV rows into a canonical type. Patterns are evaluated in order; the first match wins. Rows matching no pattern are silently skipped.

- **name**: unique identifier for this pattern (used in error messages)
- **canonical_type**: one of `deposit`, `withdrawal`, `trade`, `pay`, `invoice`
- **when**: boolean expression that selects which rows this pattern handles
- **fields**: maps canonical field names to expressions that extract values from CSV columns

## Canonical Types & Required Fields

### trade
For buy/sell transactions on exchanges. Required:
- `canonical_id` (string) — unique per row, e.g. concat date + type
- `timestamp` (timestamp)
- `from_asset` (string) — what the user gave up (USD for buys, BTC for sells)
- `from_amount` (decimal_sats) — amount given up
- `to_asset` (string) — what the user received (BTC for buys, USD for sells)
- `to_amount` (decimal_sats) — amount received

Optional: `fee_asset`, `fee_amount`, `trade_id`, `order_id`

### deposit
For BTC received. Required:
- `canonical_id` (string)
- `timestamp` (timestamp)
- `amount` (decimal_sats)
- `asset` (string) — typically `"BTC"`

Optional: `fee`, `btc_destination`, `btc_txid`, `description`

### withdrawal
For BTC sent. Required:
- `canonical_id` (string)
- `timestamp` (timestamp)
- `amount` (decimal_sats)
- `asset` (string)

Optional: `fee`, `btc_destination`, `btc_txid`, `description`

### pay
For Lightning payments. Required: `canonical_id`, `timestamp`, `amount`, `fee`

### invoice
For Lightning invoices. Required: `canonical_id`, `timestamp`, `amount`

## Expression Reference

Expressions extract and transform CSV column values into the types canonical fields expect.

### Reading columns
```json
{"col": "Header Name"}         // read column value as string (fails if missing)
{"col_opt": "Header Name"}     // read column value as option<string> (None if missing)
```

### Literals
```json
{"lit": {"type": "string", "value": "BTC"}}
{"lit": {"type": "i128", "value": 0}}
{"lit": {"type": "bool", "value": true}}
```

### String operations
```json
{"trim": <expr>}                    // strip whitespace
{"lower": <expr>}                   // lowercase
{"concat": [<expr>, <expr>, ...]}   // join strings
{"contains": {"haystack": <expr>, "needle": <expr>}}  // → bool
{"empty_to_none": <expr>}           // "" → None, else Some(value)
```

### Parsing amounts — THIS IS CRITICAL

Clams stores amounts as `decimal_sats` (a Decimal with 3 fractional digits, representing millisatoshis).

```json
// BTC string like "0.05000000" → decimal_sats
{"parse_decimal_sats_from_btc": {"trim": {"col": "Amount"}}}

// Sats integer string like "5000" → decimal_sats (multiply by 1000 to get msat)
{"to_decimal_sats_from_msat": {"mul_i128_const": {"value": {"parse_i128": {"trim": {"col": "Fee"}}}, "k": 1000}}}

// Millisats string → decimal_sats
{"to_decimal_sats_from_msat": {"parse_i128": {"trim": {"col": "amount_msat"}}}}

// USD or fiat amount string like "42000.00" → decimal_sats (for fiat side of trades)
{"parse_decimal_sats": {"trim": {"col": "Price"}}}

// Zero amount
{"to_decimal_sats_from_msat": {"lit": {"type": "i128", "value": 0}}}
```

### Parsing timestamps
```json
{"parse_rfc3339": {"trim": {"col": "Date"}}}                              // ISO 8601 / RFC 3339
{"parse_timestamp": {"trim": {"col": "Date"}}}                             // auto-detect format
{"parse_timestamp_format": {"value": {"col": "Date"}, "format": "%m/%d/%Y %I:%M:%S %p"}}  // custom format
```

### Option handling
```json
{"some": <expr>}                                         // wrap value in Some
{"none": {"type": "decimal_sats"}}                       // None of given type
{"coalesce": [<expr_opt>, <expr_opt>]}                  // first non-None
{"unwrap_or": {"value": <expr_opt>, "default": <expr>}} // unwrap or use default
```

### Conditionals
```json
{"if": {"cond": <bool_expr>, "then": <expr>, "else": <expr>}}
```

### Comparisons
```json
{"eq": {"a": <expr>, "b": <expr>}}     // equality
{"gt": {"a": <expr>, "b": <expr>}}     // greater than
{"lt": {"a": <expr>, "b": <expr>}}     // less than
{"and": [<bool>, <bool>]}              // all true
{"or": [<bool>, <bool>]}               // any true
{"not": <bool>}                        // negate
```

### Math (for amounts)
```json
{"abs_i128": <expr>}                                      // absolute value
{"add_i128": [<expr>, <expr>]}                            // addition
{"sub_i128": [<expr>, <expr>]}                            // subtraction
{"mul_i128_const": {"value": <expr>, "k": 1000}}         // multiply by constant
{"add_decimal_sats": [<expr>, <expr>]}                    // add decimal_sats values
```

## When Clauses — Row Classification

The `when` field uses boolean expressions to match rows. Common pattern:

```json
"when": {
  "eq": {
    "a": {"lower": {"trim": {"col": "Type"}}},
    "b": {"lit": {"type": "string", "value": "buy"}}
  }
}
```

Combine conditions:
```json
"when": {
  "and": [
    {"eq": {"a": {"col": "Type"}, "b": {"lit": {"type": "string", "value": "Buy"}}}},
    {"eq": {"a": {"col": "Asset"}, "b": {"lit": {"type": "string", "value": "BTC"}}}}
  ]
}
```

## Complete Example: Exchange with Buy/Sell/Deposit/Withdrawal

Given a CSV like:
```
Date,Type,Asset,Amount,Price,Fee,Fee Asset,Total
2025-01-15T10:30:00Z,Buy,BTC,0.05000000,42000.00,12.50,USD,2112.50
2025-03-22T14:15:00Z,Sell,BTC,0.02000000,65000.00,8.75,USD,1291.25
2025-08-10T16:45:00Z,Deposit,BTC,0.50000000,,,,
2025-11-05T11:20:00Z,Withdrawal,BTC,0.03000000,,5000,sats,
```

Save this as `mapping.json`:

```json
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
```

Then:
```bash
clams connections create --label my-exchange --kind Custom --configuration-file mapping.json --machine --format json
clams connections import --label my-exchange --input-format csv --file ~/Downloads/exchange-trades.csv --machine --format json
clams journals process --machine --format json
```

## Gotchas

- **Use `--configuration-file`, not `--configuration`** for csv_mapping. The JSON is too large and complex to inline reliably.
- **Buy = user gives USD, gets BTC.** `from_asset` is USD, `to_asset` is BTC. Sell is the reverse. Getting this backwards inverts cost basis.
- **BTC amounts use `parse_decimal_sats_from_btc`**, not `parse_decimal_sats`. The BTC parser handles up to 11 fractional digits (satoshi precision). `parse_decimal_sats` is for fiat amounts.
- **Fees in sats need conversion.** Sats → msat requires `mul_i128_const` with `k: 1000`. Fees in USD use `parse_decimal_sats` directly.
- **Empty cells break `col`.** If a column might be empty, use `col_opt` + `coalesce`/`unwrap_or`, or guard with an `if` + `eq` empty-string check.
- **Rows matching no pattern are skipped.** If a row type isn't covered (e.g. "Transfer", "Staking Reward"), it's silently dropped. Check `clams journals quarantined` after processing.
- **Imports are all-or-nothing.** A single bad row fails the entire import. Use `--debug` to see which row and why.
- **canonical_id must be unique per row.** Use `concat` with date + type or a row-specific field to generate unique IDs.
- **Re-imports are safe.** Clams deduplicates by canonical_id, so re-running the import with the same CSV is idempotent.
