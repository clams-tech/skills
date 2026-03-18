# Clams CLI: Onboarding a Coldcard xpub for Cold Storage Tracking

This transcript walks through every command needed to go from a fresh Clams
install to seeing the balance of a Bitcoin cold-storage wallet tracked via an
extended public key (xpub).

---

## Step 1 -- Initialize Clams (login, backend setup, workspace, and profile)

The `clams init` command is an all-in-one guided flow. It handles
authentication, backend initialization, and creation of your first workspace
and profile. We provide labels so the command can run non-interactively.

```bash
clams init --workspace-label "Personal" --profile-label "Cold Storage"
```

**What happens:**
- Opens a browser for the OAuth login flow and stores credentials.
- Initializes the local backend data root.
- Creates a workspace called "Personal".
- Creates a profile called "Cold Storage" inside that workspace.
- Sets the new profile as the active context.

---

## Step 2 -- Verify the active context

Confirm that the CLI is now pointing at the workspace and profile you just
created.

```bash
clams context current
```

If the profile is not set (for example, if you skipped the init wizard), you
can set it explicitly:

```bash
clams context set --profile "Cold Storage"
```

---

## Step 3 -- Configure the Electrum onchain data source

Clams needs an onchain backend to look up transactions and balances derived
from your xpub. The `--select` flag makes this source the active one for the
profile so subsequent commands use it automatically.

```bash
clams onchain create \
  --label "Blockstream Electrum" \
  --kind Electrum \
  --url "ssl://electrum.blockstream.info:50002" \
  --select
```

---

## Step 4 -- Create the XPub connection

This registers your Coldcard xpub as a watch-only connection. The
`--configuration` flag takes inline JSON that matches the `XPub` connection
kind schema. Key fields:

| Field | Value | Why |
|---|---|---|
| `xpub` | Your Coldcard xpub | The extended public key to derive addresses from |
| `address_types` | `["bech32"]` | Coldcard default is native SegWit (bc1...) addresses |
| `gap_limit` | `20` | Standard BIP44 gap limit for address discovery |
| `network` | `"bitcoin"` | Mainnet |

```bash
clams connections create \
  --label "Coldcard" \
  --kind XPub \
  --configuration '{
    "xpub": "xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz",
    "address_types": ["bech32"],
    "gap_limit": 20,
    "network": "bitcoin"
  }'
```

---

## Step 5 -- Sync the connection

Trigger a sync so Clams scans the Electrum server for all transactions
associated with addresses derived from your xpub. This may take a moment
depending on the number of transactions.

```bash
clams connections sync --label "Coldcard"
```

---

## Step 6 -- Process journals

After syncing raw transaction data, Clams needs to process it into
double-entry journal entries that power the accounting reports.

```bash
clams journals process
```

---

## Step 7 -- View your balance

### Option A -- Balance sheet (full double-entry view)

The balance sheet shows assets, liabilities, and equity in a tree format.
Your cold-storage BTC balance will appear under assets.

```bash
clams reports balance-sheet
```

### Option B -- Portfolio summary (quick overview)

A more compact view focused on holdings and their current fiat value.

```bash
clams reports portfolio-summary
```

---

## Full command sequence (copy-paste ready)

```bash
# 1. Initialize: login, create workspace and profile
clams init --workspace-label "Personal" --profile-label "Cold Storage"

# 2. Verify context
clams context current

# 3. Point Clams at your Electrum server
clams onchain create \
  --label "Blockstream Electrum" \
  --kind Electrum \
  --url "ssl://electrum.blockstream.info:50002" \
  --select

# 4. Register your Coldcard xpub
clams connections create \
  --label "Coldcard" \
  --kind XPub \
  --configuration '{
    "xpub": "xpub6CUGRUonZSQ4TWtTMmzXdrXDtypWKiKrhko4egpiMZbpiaQL2jkwSB1icqYh2cfDfVxdx4df189oLKnC5fSwqPfgyP3hooxujYzAu3fDVmz",
    "address_types": ["bech32"],
    "gap_limit": 20,
    "network": "bitcoin"
  }'

# 5. Sync on-chain data from the Electrum server
clams connections sync --label "Coldcard"

# 6. Process raw data into accounting journals
clams journals process

# 7. View your balance
clams reports balance-sheet
clams reports portfolio-summary
```
