# Multi-Source Bitcoin Portfolio in USD -- Command Transcript

This transcript walks through connecting three Bitcoin sources (Coldcard xpub,
LND via LNC, and Phoenix CSV export) to Clams and viewing a consolidated
portfolio summary in USD.

---

## 1. Verify CLI State

Check whether you are already authenticated and have a workspace/profile
configured.

```bash
scripts/verify-state.sh
```

If `summary.all_ok` is `true` and you already have a workspace and profile,
skip ahead to step 5 (Configure Profile Settings). Otherwise, continue below.

---

## 2. Log In

Authenticate with Clams. This opens a browser for login.

```bash
clams login
```

Verify authentication succeeded:

```bash
clams status --machine --format json
```

Confirm `auth.status` is `"authenticated"` in the response.

---

## 3. Create a Workspace

Create a workspace to hold your profile and connections.

```bash
clams workspaces create --label "my-bitcoin" --machine --format json
```

Note the workspace ID returned in the response (under `.data`). You will need
it in the next step.

---

## 4. Create a Profile and Set Context

Create a profile inside the workspace.

```bash
clams profiles create --workspace <WORKSPACE_ID> --label "main" --machine --format json
```

Replace `<WORKSPACE_ID>` with the ID returned in step 3.

Set this profile as the active context so subsequent commands do not need `-w`
and `-p` flags:

```bash
clams context set --profile main
```

Confirm the context is set:

```bash
clams context current --machine --format json
```

---

## 5. Configure Profile Settings

Set USD as the fiat currency and choose a cost-basis algorithm (FIFO is the
most common for US tax reporting):

```bash
clams profiles set --fiat-currency USD --gains-algorithm FIFO --machine --format json
```

---

## 6. Sync Exchange Rates

Pull the BTC-USD rate cache so reports have exchange rate data:

```bash
clams rates sync --machine --format json
```

---

## 7. Create an Onchain Source

The Coldcard xpub is an on-chain wallet. On-chain connection types (`XPub`,
`Descriptor`, `Address`) require an onchain data source before they can sync.
Create one using a public Esplora instance:

```bash
clams onchain create \
  --label blockstream \
  --kind Esplora \
  --url https://blockstream.info/api \
  --select \
  --machine --format json
```

The `--select` flag automatically assigns this source as the active onchain
source in the profile settings.

---

## 8. Create the Coldcard XPub Connection

Add the Coldcard xpub as an `XPub` connection:

```bash
clams connections create \
  --label coldcard \
  --kind XPub \
  --configuration '{
    "xpub": "xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz",
    "address_types": ["bech32"],
    "gap_limit": 20,
    "wallet_first_tx_block_height": 1,
    "network": "bitcoin"
  }' \
  --machine --format json
```

---

## 9. Create the LND (LNC) Connection

Add the LND node using the Lightning Node Connect pairing phrase:

```bash
clams connections create \
  --label lnd-node \
  --kind Lnd \
  --configuration '{
    "transport": "lnc",
    "config": {
      "pairing_phrase": "uncle obvious bean future drastic gossip gate exhaust media faith"
    }
  }' \
  --machine --format json
```

---

## 10. Create the Phoenix Connection

Phoenix is a CSV-import-only connection. Create the connection first (no
configuration is needed):

```bash
clams connections create \
  --label phoenix \
  --kind Phoenix \
  --machine --format json
```

---

## 11. Sync the Coldcard and LND Connections

Sync the two connections that support live sync (XPub and LND). Phoenix does
not support sync -- it uses CSV import instead.

```bash
clams connections sync --label coldcard --machine --format json
```

```bash
clams connections sync --label lnd-node --machine --format json
```

Alternatively, sync both at once:

```bash
clams connections sync --all --machine --format json
```

---

## 12. Import the Phoenix CSV Export

Import the Phoenix wallet CSV file:

```bash
clams connections import \
  --label phoenix \
  --input-format csv \
  --file ~/Downloads/phoenix-export.csv \
  --machine --format json
```

---

## 13. Process Journals

This is the critical step that builds the double-entry ledger from all synced
and imported data. **Reports will be empty without this.**

```bash
clams journals process --machine --format json
```

---

## 14. Check for Quarantined Events

Quarantined events are ambiguous transactions the processor could not classify.
They are excluded from reports until resolved.

```bash
clams journals quarantined --machine --format json
```

If quarantined events are returned, inspect and resolve each one before
continuing. For example:

```bash
# Inspect a quarantined event
clams journals quarantine show --event-id <EVENT_ID> --machine --format json

# Resolve a collaborative/shared-spend event
clams journals quarantine resolve collaborative \
  --event-id <EVENT_ID> --fee-sats <SATS> --mode send \
  --machine --format json

# Resolve a missing-address event
clams journals quarantine resolve missing-address \
  --event-id <EVENT_ID> --machine --format json
```

After resolving any quarantined events, re-process journals:

```bash
clams journals process --machine --format json
```

If no quarantined events were returned, continue to the next step.

---

## 15. View the Consolidated Portfolio Summary in USD

Display the portfolio summary in the terminal. This shows all three sources
(Coldcard, LND, Phoenix) consolidated into a single USD-denominated view:

```bash
clams reports portfolio-summary --format plain
```

This prints the portfolio summary directly to the terminal. Do not reformat or
summarize the output -- the CLI handles all amount formatting and currency
conversion.

---

## Summary of the Full Command Sequence

```text
1.  scripts/verify-state.sh
2.  clams login
3.  clams workspaces create --label "my-bitcoin" --machine --format json
4.  clams profiles create --workspace <WORKSPACE_ID> --label "main" --machine --format json
5.  clams context set --profile main
6.  clams profiles set --fiat-currency USD --gains-algorithm FIFO --machine --format json
7.  clams rates sync --machine --format json
8.  clams onchain create --label blockstream --kind Esplora --url https://blockstream.info/api --select --machine --format json
9.  clams connections create --label coldcard --kind XPub --configuration '{"xpub":"xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz","address_types":["bech32"],"gap_limit":20,"wallet_first_tx_block_height":1,"network":"bitcoin"}' --machine --format json
10. clams connections create --label lnd-node --kind Lnd --configuration '{"transport":"lnc","config":{"pairing_phrase":"uncle obvious bean future drastic gossip gate exhaust media faith"}}' --machine --format json
11. clams connections create --label phoenix --kind Phoenix --machine --format json
12. clams connections sync --all --machine --format json
13. clams connections import --label phoenix --input-format csv --file ~/Downloads/phoenix-export.csv --machine --format json
14. clams journals process --machine --format json
15. clams journals quarantined --machine --format json
16. clams reports portfolio-summary --format plain
```
