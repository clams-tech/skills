# Onboarding a Coldcard XPub Wallet in Clams

This transcript walks through every command needed to go from a fresh Clams install to seeing your Bitcoin cold storage balance, using an xpub from a Coldcard and a remote Electrum server.

---

## Step 1: Check authentication status

First, confirm whether Clams is already authenticated or needs a login.

```bash
clams status --machine --format json
```

If `auth.status` is not `"authenticated"`, proceed to Step 2. Otherwise skip to Step 3.

---

## Step 2: Log in

```bash
clams login
```

This opens a browser for authentication and stores credentials locally. After completing the browser flow, verify it worked:

```bash
clams status --machine --format json
```

Confirm `auth.status` is `"authenticated"` before continuing.

---

## Step 3: Create a workspace

Create a workspace to hold your profiles and data.

```bash
clams workspaces create --label "My Bitcoin" --machine --format json
```

This returns a workspace ID. Note it for the next step. (If you already have a workspace you want to use, run `clams workspaces list --machine --format json` to find its ID and skip this step.)

---

## Step 4: Create a profile

Create a profile inside the workspace. Replace `<WORKSPACE_ID>` with the ID returned in Step 3.

```bash
clams profiles create --workspace <WORKSPACE_ID> --label "Cold Storage" --machine --format json
```

This returns a profile ID. Note it for the next step.

---

## Step 5: Set the active context

Set the default workspace and profile so you do not need to pass `-w` and `-p` flags on every subsequent command.

```bash
clams context set --profile "Cold Storage" --machine --format json
```

Verify the context is active:

```bash
clams context current --machine --format json
```

Confirm both the workspace and profile are correctly set.

---

## Step 6: Configure profile settings

Set your fiat currency (USD) and cost-basis algorithm (FIFO is the most common default).

```bash
clams profiles set --fiat-currency USD --gains-algorithm FIFO --machine --format json
```

---

## Step 6b: Sync exchange rates

Pull down exchange rate data so reports can display fiat values.

```bash
clams rates sync --machine --format json
```

---

## Step 7: Create an Electrum onchain source

On-chain wallets (XPub, Descriptor, Address) require an onchain data source before they can sync. Create one pointing at your Electrum server and use `--select` to automatically assign it to your profile.

```bash
clams onchain create \
  --label "Blockstream Electrum" \
  --kind Electrum \
  --url ssl://electrum.blockstream.info:50002 \
  --select \
  --machine --format json
```

---

## Step 8: Create the XPub connection

Add your Coldcard's xpub as an XPub connection. This tells Clams which wallet to track.

```bash
clams connections create \
  --label "Coldcard Cold Storage" \
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

## Step 9: Sync the connection

Pull transaction data from the Electrum server for your xpub.

```bash
clams connections sync --label "Coldcard Cold Storage" --machine --format json
```

---

## Step 10: Process journals

Build the double-entry ledger from the synced transaction data. This step is required before any reports will work.

```bash
clams journals process --machine --format json
```

---

## Step 11: Check for quarantined events

Some transactions may be ambiguous and placed in quarantine. Check if any need attention.

```bash
clams journals quarantined --machine --format json
```

If quarantined events exist, inspect and resolve each one (see the Clams documentation on quarantine resolution), then re-run `clams journals process --machine --format json` before proceeding.

---

## Step 12: View your balance

Display the balance sheet in the terminal.

```bash
clams reports balance-sheet --format plain
```

This shows your current Bitcoin holdings and their fiat value across all connections. The output is pre-formatted by the CLI -- read it directly without reformatting.

---

## Step 13 (optional): View your portfolio summary

For a higher-level overview including cost basis and unrealized gains:

```bash
clams reports portfolio-summary --format plain
```

---

## Summary of the full command sequence

For quick reference, here is the complete sequence assuming a fresh install:

```bash
# 1. Authenticate
clams login

# 2. Create workspace and profile
clams workspaces create --label "My Bitcoin" --machine --format json
clams profiles create --workspace <WORKSPACE_ID> --label "Cold Storage" --machine --format json
clams context set --profile "Cold Storage" --machine --format json

# 3. Configure profile
clams profiles set --fiat-currency USD --gains-algorithm FIFO --machine --format json
clams rates sync --machine --format json

# 4. Set up onchain source (required for XPub wallets)
clams onchain create --label "Blockstream Electrum" --kind Electrum --url ssl://electrum.blockstream.info:50002 --select --machine --format json

# 5. Add the Coldcard xpub
clams connections create --label "Coldcard Cold Storage" --kind XPub --configuration '{"xpub":"xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz","address_types":["bech32"],"gap_limit":20,"wallet_first_tx_block_height":1,"network":"bitcoin"}' --machine --format json

# 6. Sync, process, and check quarantine
clams connections sync --label "Coldcard Cold Storage" --machine --format json
clams journals process --machine --format json
clams journals quarantined --machine --format json

# 7. View balance
clams reports balance-sheet --format plain
```
