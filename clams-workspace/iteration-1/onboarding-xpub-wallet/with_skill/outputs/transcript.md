# Transcript: Onboarding a Coldcard XPub Wallet in Clams

Below is the exact sequence of CLI commands to go from a fresh Clams install to viewing the balance of a Bitcoin cold storage wallet tracked via xpub, using a remote Electrum server.

---

## Step 1: Check current authentication status

```bash
clams status --machine --format json
```

This returns the current auth state. If `auth.status` is not `"authenticated"`, proceed to login.

---

## Step 2: Log in

```bash
clams login
```

This opens a browser for authentication and stores credentials locally. After the browser flow completes, verify authentication succeeded:

```bash
clams status --machine --format json
```

Confirm `auth.status` is `"authenticated"` before proceeding.

---

## Step 3: Create a workspace

```bash
clams workspaces create --label "My Bitcoin Workspace" --machine --format json
```

This returns a workspace ID in the response at `.data`. Save the workspace ID for the next step.

---

## Step 4: Create a profile

```bash
clams profiles create --workspace <WORKSPACE_ID> --label "Cold Storage" --machine --format json
```

Replace `<WORKSPACE_ID>` with the ID returned in Step 3. This returns a profile ID.

---

## Step 5: Set the context (default workspace and profile)

```bash
clams context set --profile "Cold Storage" --machine --format json
```

This sets the default profile so that `-w` and `-p` flags can be omitted from all subsequent commands.

Verify the context was set correctly:

```bash
clams context current --machine --format json
```

---

## Step 6: Configure profile settings

```bash
clams profiles set --fiat-currency USD --gains-algorithm FIFO --machine --format json
```

This sets the fiat reporting currency to USD and the capital gains algorithm to FIFO (first-in, first-out).

---

## Step 7: Create the onchain source (Electrum server)

On-chain wallet types (`XPub`, `Descriptor`, `Address`) require an onchain data source before they can sync. This step connects Clams to the Blockstream Electrum server.

```bash
clams onchain create --label "Blockstream Electrum" --kind Electrum --url ssl://electrum.blockstream.info:50002 --select --machine --format json
```

The `--select` flag automatically assigns this source as the active onchain source in the profile settings.

---

## Step 8: Create the XPub connection (Coldcard wallet)

```bash
clams connections create --label "Coldcard Cold Storage" --kind XPub --configuration '{
  "xpub": "xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz",
  "address_types": ["bech32"],
  "gap_limit": 20,
  "wallet_first_tx_block_height": 1,
  "network": "bitcoin"
}' --machine --format json
```

This registers the xpub as a tracked connection. The `address_types` field is set to `["bech32"]` for native SegWit addresses (the default for Coldcard). The `gap_limit` of 20 tells the scanner how many consecutive unused addresses to check before stopping. Setting `wallet_first_tx_block_height` to 1 scans from the beginning of the chain (use a higher block height if you know when the wallet was first used, to speed up the initial sync).

---

## Step 9: Run the verification script (pre-sync check)

```bash
scripts/verify-state.sh
```

Confirm that `auth`, `context`, and `connections` sections all show `ok: true`. The `journals` section will show `ok: false` at this point since we have not synced or processed yet -- that is expected.

---

## Step 10: Sync the wallet

```bash
clams connections sync --label "Coldcard Cold Storage" --machine --format json
```

This queries the Electrum server for all transactions associated with the xpub's derived addresses and pulls them into Clams. This may take some time depending on the wallet's transaction history.

---

## Step 11: Process journals

```bash
clams journals process --machine --format json
```

This builds the double-entry ledger from the synced transaction data. This step is mandatory after every sync and before generating any reports. Skipping it is the number one cause of empty reports.

---

## Step 12: Check for quarantined events

```bash
clams journals quarantined --machine --format json
```

Quarantined events are ambiguous transactions the processor could not classify automatically. If any exist, inspect and resolve them (see the journal-processing reference for resolution commands), then re-run `clams journals process`. If the list is empty, proceed to reports.

---

## Step 13: View the balance

```bash
clams reports balance-sheet --format plain
```

This displays the current balance sheet in the terminal in plain text. It shows the wallet's Bitcoin holdings and their fiat (USD) equivalent. The `--format plain` flag produces human-readable output that should be displayed directly without reformatting.

---

## Step 14: View the portfolio summary

```bash
clams reports portfolio-summary --format plain
```

This shows a portfolio-level overview including total holdings, cost basis, and unrealized gains/losses, also in plain text for direct terminal display.

---

## Step 15: Post-workflow verification

```bash
scripts/verify-state.sh
```

Confirm that all sections (`auth`, `context`, `connections`, `journals`, `quarantine`) show `ok: true` and `summary.all_ok` is `true`.

---

## Summary of Command Sequence

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `clams status --machine --format json` | Check auth state |
| 2 | `clams login` | Authenticate via browser |
| 3 | `clams workspaces create --label "My Bitcoin Workspace" --machine --format json` | Create workspace |
| 4 | `clams profiles create --workspace <WORKSPACE_ID> --label "Cold Storage" --machine --format json` | Create profile |
| 5 | `clams context set --profile "Cold Storage" --machine --format json` | Set default context |
| 6 | `clams profiles set --fiat-currency USD --gains-algorithm FIFO --machine --format json` | Configure profile |
| 7 | `clams onchain create --label "Blockstream Electrum" --kind Electrum --url ssl://electrum.blockstream.info:50002 --select --machine --format json` | Set up Electrum source |
| 8 | `clams connections create --label "Coldcard Cold Storage" --kind XPub --configuration '{"xpub":"xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz","address_types":["bech32"],"gap_limit":20,"wallet_first_tx_block_height":1,"network":"bitcoin"}' --machine --format json` | Add Coldcard xpub |
| 9 | `scripts/verify-state.sh` | Pre-sync verification |
| 10 | `clams connections sync --label "Coldcard Cold Storage" --machine --format json` | Sync wallet data |
| 11 | `clams journals process --machine --format json` | Build journal ledger |
| 12 | `clams journals quarantined --machine --format json` | Check for quarantined events |
| 13 | `clams reports balance-sheet --format plain` | View balance |
| 14 | `clams reports portfolio-summary --format plain` | View portfolio summary |
| 15 | `scripts/verify-state.sh` | Final verification |
