# Multi-Source Bitcoin Portfolio in Clams -- Command Transcript

This transcript walks through connecting three Bitcoin sources (a Coldcard xpub,
an LND node via LNC, and a Phoenix wallet CSV export) and producing a
consolidated portfolio summary in USD.

---

## Prerequisites

Before starting, you need the Clams CLI installed and authenticated.
If you have not done so already, run `clams init` to log in, create a workspace,
and create a profile in one guided flow.

---

## Step 1 -- Initialize (login, workspace, and profile)

```bash
clams init
```

**What this does:** Opens the browser-based login flow, sets up the local
backend data root, creates a workspace, and creates a profile. Follow the
interactive prompts to complete setup. This only needs to be done once.

If you have already logged in and have a workspace but need a new profile
dedicated to this portfolio, you can create one explicitly:

```bash
clams profiles create --label "my-portfolio"
```

Then set it as the default context so all subsequent commands target it:

```bash
clams context set --profile my-portfolio
```

---

## Step 2 -- Configure the fiat currency to USD

Set the profile's fiat currency to USD so that all reports are denominated in
US dollars:

```bash
clams profiles set --fiat-currency USD
```

---

## Step 3 -- Create an onchain data source

The XPub connection requires an onchain data source for address derivation and
transaction lookups. Create one using a public Electrum server (or substitute
your own):

```bash
clams onchain create \
  --label electrum-public \
  --kind Electrum \
  --url ssl://electrum.blockstream.info:50002 \
  --select
```

**What this does:** Registers a public Electrum server as the onchain backend
and the `--select` flag automatically associates it with the current profile's
settings so that XPub and other onchain connection types can resolve addresses
and transactions.

---

## Step 4 -- Connect the Coldcard xpub (on-chain wallet)

Create an XPub connection using the extended public key from the Coldcard. The
configuration JSON tells Clams the xpub value, the address type to derive, and
the Bitcoin network:

```bash
clams connections create \
  --label coldcard \
  --kind XPub \
  --configuration '{
    "xpub": "xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz",
    "address_types": ["bech32"],
    "gap_limit": 20,
    "network": "bitcoin"
  }'
```

**What this does:** Creates a connection labeled "coldcard" of kind `XPub`.
Clams will derive addresses from this xpub using native SegWit (bech32) address
encoding, scanning up to 20 unused addresses beyond the last funded one (the
gap limit). No private keys are needed -- only the xpub for read-only access.

---

## Step 5 -- Connect the LND node via LNC

Create an LND connection using the Lightning Node Connect (LNC) pairing phrase.
This lets Clams sync invoices, payments, forwards, and channel state from the
LND node without direct gRPC access:

```bash
clams connections create \
  --label lnd-node \
  --kind Lnd \
  --configuration '{
    "transport": "lnc",
    "config": {
      "pairing_phrase": "uncle obvious bean future drastic gossip gate exhaust media faith"
    }
  }'
```

**What this does:** Creates a connection labeled "lnd-node" of kind `Lnd` using
the `lnc` transport. The pairing phrase establishes an end-to-end encrypted
session with the LND node through the Lightning Node Connect relay. Clams uses
this to pull invoice, payment, forwarding, and channel data.

---

## Step 6 -- Connect the Phoenix wallet (CSV import)

Phoenix connections are import-only -- you first create the connection, then
import the CSV export file into it.

### 6a. Create the Phoenix connection

```bash
clams connections create \
  --label phoenix \
  --kind Phoenix
```

**What this does:** Registers a Phoenix wallet connection. Phoenix connections
do not require runtime configuration because data is supplied via CSV import
rather than a live sync.

### 6b. Import the Phoenix CSV export

```bash
clams connections import \
  --label phoenix \
  --input-format csv \
  --file ~/Downloads/phoenix-export.csv
```

**What this does:** Reads the Phoenix CSV export file and ingests its
transactions (sends, receives, swaps, fees) into the "phoenix" connection.
The `--input-format csv` flag tells Clams to parse the file as CSV rather than
the default JSON format.

---

## Step 7 -- Sync the live connections

The Coldcard xpub and LND connections can pull fresh data from their respective
sources. The Phoenix connection was populated by the CSV import and does not
need syncing. Sync all connections in one command:

```bash
clams connections sync --all
```

**What this does:** Triggers a parallel sync of every connection in the current
profile. For the XPub connection, Clams derives addresses and fetches their
transaction history from the configured onchain (Electrum) source. For the LND
connection, Clams connects over LNC and pulls invoices, payments, forwards,
and channel state. The Phoenix connection (import-only) is a no-op during sync.

If a sync times out for large histories, you can increase the timeout:

```bash
clams connections sync --all --sync-timeout 30m
```

---

## Step 8 -- Verify the connections

List all connections to confirm they were created and their sync status:

```bash
clams connections list
```

You should see three connections: `coldcard` (XPub), `lnd-node` (Lnd), and
`phoenix` (Phoenix), each showing their latest sync timestamp or import status.

---

## Step 9 -- Process journals

Before generating reports, Clams needs to process the raw synced data into
double-entry accounting journal entries:

```bash
clams journals process
```

**What this does:** Reads all synced/imported records across every connection
in the profile, classifies each event (receive, send, fee, channel open/close,
etc.), fetches historical exchange rates, and produces double-entry journal
entries. This step must run after any new sync or import and before generating
reports.

---

## Step 10 -- View the consolidated portfolio summary in USD

Generate the portfolio summary report, which aggregates balances across all
three connections and displays them in the profile's configured fiat currency
(USD):

```bash
clams reports portfolio-summary
```

**What this does:** Computes and renders a consolidated portfolio summary across
all connections in the profile. It shows total BTC holdings broken down by
connection, the current USD value of each position (using live exchange rates),
and the aggregate portfolio value.

To get the output in different formats:

```bash
# JSON (for programmatic consumption)
clams reports portfolio-summary --format json

# YAML
clams reports portfolio-summary --format yaml

# CSV (for spreadsheets)
clams reports portfolio-summary --format csv
```

---

## Complete Command Summary

For quick reference, here are all the commands in order (assuming you are
already logged in and have a workspace/profile set in context):

```bash
# 1. Set fiat currency to USD
clams profiles set --fiat-currency USD

# 2. Create an onchain data source for xpub address resolution
clams onchain create \
  --label electrum-public \
  --kind Electrum \
  --url ssl://electrum.blockstream.info:50002 \
  --select

# 3. Connect Coldcard xpub
clams connections create \
  --label coldcard \
  --kind XPub \
  --configuration '{
    "xpub": "xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz",
    "address_types": ["bech32"],
    "gap_limit": 20,
    "network": "bitcoin"
  }'

# 4. Connect LND node via LNC
clams connections create \
  --label lnd-node \
  --kind Lnd \
  --configuration '{
    "transport": "lnc",
    "config": {
      "pairing_phrase": "uncle obvious bean future drastic gossip gate exhaust media faith"
    }
  }'

# 5. Create Phoenix connection and import CSV
clams connections create \
  --label phoenix \
  --kind Phoenix

clams connections import \
  --label phoenix \
  --input-format csv \
  --file ~/Downloads/phoenix-export.csv

# 6. Sync all live connections
clams connections sync --all

# 7. Verify connections
clams connections list

# 8. Process journals for accounting
clams journals process

# 9. View consolidated portfolio in USD
clams reports portfolio-summary
```
