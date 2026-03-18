# Onboarding a Coldcard xpub into Clams -- Complete Command Transcript

This document lists every CLI command, in order, that you would run to go
from a fresh Clams install to viewing your cold-storage balance.

Your inputs:
- **xpub**: `xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz`
- **Electrum server**: `ssl://electrum.blockstream.info:50002`

---

## Step 1 -- Authenticate and bootstrap the backend

`clams init` bundles login, backend setup, and workspace/profile creation
into a single guided flow. We pass labels so it runs non-interactively.

```bash
clams init --workspace-label "cold-storage" --profile-label "coldcard"
```

This command will:
1. Open the browser for authentication (`clams login` under the hood).
2. Initialize the local backend data root (`clams setup` under the hood).
3. Create a workspace labelled **cold-storage**.
4. Create a profile labelled **coldcard** inside that workspace.
5. Set the new profile as the active context.

---

## Step 2 -- Verify the active context

Confirm that the workspace and profile created above are now selected:

```bash
clams context current
```

If for any reason the context was not set automatically, set it explicitly:

```bash
clams context set --profile coldcard
```

---

## Step 3 -- Configure the Electrum onchain data source

Clams needs an onchain backend to look up addresses derived from the xpub.
Create an Electrum source pointing at Blockstream's public server and mark
it as the selected source for this profile (`--select`):

```bash
clams onchain create \
  --label "blockstream-electrum" \
  --kind Electrum \
  --url "ssl://electrum.blockstream.info:50002" \
  --select
```

---

## Step 4 -- Create the XPub connection

Register the Coldcard xpub as a connection. The `XPub` kind requires a
JSON `--configuration` string containing the extended public key:

```bash
clams connections create \
  --label "coldcard-xpub" \
  --kind XPub \
  --configuration '{"xpub":"xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz"}'
```

---

## Step 5 -- Sync the connection

Trigger a sync so Clams queries the Electrum server, derives addresses
from the xpub, and pulls transaction history:

```bash
clams connections sync --label "coldcard-xpub"
```

---

## Step 6 -- Process journals

After syncing, Clams needs to convert raw transaction data into accounting
journal entries:

```bash
clams journals process
```

---

## Step 7 -- View your balance

### 7a. Balance sheet (tree view)

```bash
clams reports balance-sheet
```

### 7b. Portfolio summary

```bash
clams reports portfolio-summary
```

### 7c. Machine-readable JSON balance sheet (optional)

```bash
clams reports balance-sheet --format json
```

---

## Quick-reference: all commands in order

```bash
# 1. One-shot init (login + setup + workspace + profile)
clams init --workspace-label "cold-storage" --profile-label "coldcard"

# 2. Verify context
clams context current

# 3. Add Electrum onchain source
clams onchain create \
  --label "blockstream-electrum" \
  --kind Electrum \
  --url "ssl://electrum.blockstream.info:50002" \
  --select

# 4. Register the Coldcard xpub
clams connections create \
  --label "coldcard-xpub" \
  --kind XPub \
  --configuration '{"xpub":"xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz"}'

# 5. Sync transactions from the Electrum server
clams connections sync --label "coldcard-xpub"

# 6. Build accounting journals
clams journals process

# 7. View balance
clams reports balance-sheet
clams reports portfolio-summary
```
