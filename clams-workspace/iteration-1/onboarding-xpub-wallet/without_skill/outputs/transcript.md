# Clams Cold-Storage Onboarding Transcript

Goal: Set up Clams to track a Coldcard xpub via an Electrum server and view the balance.

**xpub:** `xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz`
**Electrum server:** `ssl://electrum.blockstream.info:50002`

---

## Step 1: Initialize Clams (login + workspace + profile creation)

Run the guided init flow. This handles authentication, workspace creation, and
profile creation in one interactive command. We supply labels so this can run
non-interactively.

```bash
clams init --workspace-label "cold-storage" --profile-label "coldcard"
```

This will:
- Launch the browser-based login/authentication flow.
- Create a workspace labelled "cold-storage".
- Create a profile labelled "coldcard" inside that workspace.
- Set the new profile as the active context.

---

## Step 2: Verify the current context

Confirm that the workspace and profile created above are now the active context.

```bash
clams context current
```

If the context was not automatically set by `init`, set it explicitly:

```bash
clams context set --profile coldcard
```

---

## Step 3: Configure the Electrum onchain data source

Register the Blockstream Electrum server as the on-chain backend. The `--select`
flag makes it the active onchain source for the profile.

```bash
clams onchain create \
  --label "blockstream-electrum" \
  --kind Electrum \
  --url "ssl://electrum.blockstream.info:50002" \
  --select
```

---

## Step 4: Create an XPub connection for the Coldcard

Create a connection of kind `XPub` and pass the extended public key via the
`--configuration` flag as JSON.

```bash
clams connections create \
  --label "coldcard-xpub" \
  --kind XPub \
  --configuration '{"xpub":"xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz"}'
```

---

## Step 5: Sync the connection to pull on-chain data

Trigger a sync for the newly created xpub connection. This queries the Electrum
server for all addresses derived from the xpub and fetches their transaction
history and UTXO set.

```bash
clams connections sync --label "coldcard-xpub"
```

---

## Step 6: Process journals

Build the accounting journals from the synced transaction data so that reports
can be generated.

```bash
clams journals process
```

---

## Step 7: View the balance sheet

Display the balance sheet report, which will show the BTC balance held by the
cold-storage xpub.

```bash
clams reports balance-sheet
```

---

## Step 8 (optional): View the portfolio summary

For a higher-level overview including fiat-denominated values:

```bash
clams reports portfolio-summary
```

---

## Step 9 (optional): View the balance sheet as JSON

For programmatic consumption or detailed inspection:

```bash
clams reports balance-sheet --format json
```

---

## Command Summary (in order)

| # | Command | Purpose |
|---|---------|---------|
| 1 | `clams init --workspace-label "cold-storage" --profile-label "coldcard"` | Login, create workspace and profile |
| 2 | `clams context current` | Verify active workspace/profile context |
| 3 | `clams context set --profile coldcard` | Set context if not already set |
| 4 | `clams onchain create --label "blockstream-electrum" --kind Electrum --url "ssl://electrum.blockstream.info:50002" --select` | Register Electrum server as onchain source |
| 5 | `clams connections create --label "coldcard-xpub" --kind XPub --configuration '{"xpub":"xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz"}'` | Create xpub connection for Coldcard |
| 6 | `clams connections sync --label "coldcard-xpub"` | Sync transaction data from Electrum |
| 7 | `clams journals process` | Build accounting journals from synced data |
| 8 | `clams reports balance-sheet` | Display the balance sheet with BTC balance |
| 9 | `clams reports portfolio-summary` | (Optional) Show portfolio overview with fiat values |
