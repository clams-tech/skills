# Onboarding an XPub Cold Storage Wallet in Clams

Complete command transcript for setting up Clams from scratch, connecting a Coldcard
xpub via an Electrum server, syncing, processing journals, and viewing the balance.

---

## Step 1: Check current authentication status

```bash
clams status --machine --format json
```

If `auth.status` is not `"authenticated"`, proceed to login.

---

## Step 2: Log in

```bash
clams login
```

Opens a browser for authentication. After completing login in the browser, verify:

```bash
clams status --machine --format json
```

Confirm `auth.status` is `"authenticated"` before continuing.

---

## Step 3: Create a workspace

```bash
clams workspaces create --label "My Bitcoin" --machine --format json
```

Note the workspace ID from the response (at `.data.id`).

---

## Step 4: Create a profile

```bash
clams profiles create --workspace <WORKSPACE_ID> --label "Personal" --machine --format json
```

Replace `<WORKSPACE_ID>` with the ID returned in Step 3. Note the profile ID from the response.

---

## Step 5: Set context (default workspace and profile)

```bash
clams context set --profile Personal --machine --format json
```

Verify the context is set:

```bash
clams context current --machine --format json
```

From this point on, `-w` and `-p` flags can be omitted.

---

## Step 6: Configure profile settings

```bash
clams profiles set --fiat-currency USD --gains-algorithm FIFO --machine --format json
```

---

## Step 6b: Sync exchange rates

```bash
clams rates sync --machine --format json
```

---

## Step 7: Create the onchain source (Electrum server)

This is required before any on-chain wallet (XPub, Descriptor, Address) can sync.

```bash
clams onchain create --label electrum-blockstream --kind Electrum --url ssl://electrum.blockstream.info:50002 --select --machine --format json
```

The `--select` flag automatically assigns this source as the active onchain source for the current profile.

---

## Step 8: Create the XPub connection (Coldcard wallet)

```bash
clams connections create --label coldcard-cold-storage --kind XPub --configuration '{
  "xpub": "xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz",
  "address_types": ["bech32"],
  "gap_limit": 20,
  "wallet_first_tx_block_height": 1,
  "network": "bitcoin"
}' --machine --format json
```

---

## Step 9: Run verification before syncing

```bash
scripts/verify-state.sh
```

Confirm `auth`, `context`, and `connections` sections all show `ok: true`.

---

## Step 10: Sync the connection

```bash
clams connections sync --label coldcard-cold-storage --machine --format json
```

This pulls all on-chain transaction history through the Electrum server.

---

## Step 11: Process journals

```bash
clams journals process --machine --format json
```

This builds the double-entry ledger from the synced data. Skipping this step is the #1 cause of empty reports.

---

## Step 12: Check for quarantined events

```bash
clams journals quarantined --machine --format json
```

If any quarantined events exist, inspect and resolve them per the quarantine workflow, then re-process journals. If the list is empty, proceed to reports.

---

## Step 13: View the balance

```bash
clams reports balance-sheet --format plain
```

This displays the current balance sheet directly in the terminal, showing the BTC holdings across all tracked wallets.

---

## Step 14: (Optional) View portfolio summary with fiat valuation

```bash
clams reports portfolio-summary --format plain
```

This shows the portfolio summary including current fiat (USD) valuation of all holdings.

---

## Step 15: Run final verification

```bash
scripts/verify-state.sh
```

Confirm `summary.all_ok` is `true` -- all sections (auth, context, connections, journals, quarantine) should pass.
