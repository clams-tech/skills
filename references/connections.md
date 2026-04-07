# Connections: Create, Sync, Import

All commands below require `--machine --format json` appended. Shown without for brevity.

## Connection Kinds

| Kind | Description | Sync | Import |
|---|---|---|---|
| `CoreLn` | Core Lightning via Commando RPC | Yes | JSON |
| `Lnd` | LND via LNC or gRPC | Yes | JSON |
| `Nwc` | Nostr Wallet Connect | Yes | No |
| `XPub` | On-chain via BIP32 xpub | Yes (needs onchain source) | No |
| `Descriptor` | On-chain via output descriptors | Yes (needs onchain source) | No |
| `Address` | On-chain via address list | Yes (needs onchain source) | No |
| `Phoenix` | Phoenix wallet CSV import | No | CSV |
| `River` | River CSV import | No | CSV |
| `Custom` | Manual/custom adapter | Varies | Varies |

On-chain types (`XPub`, `Descriptor`, `Address`) require an onchain source — see [onboarding.md](onboarding.md) step 7.

## List Available Kinds

```bash
clams connections kinds
```

Returns example configuration JSON for each kind.

## Create a Connection

```bash
clams connections create --label <LABEL> --kind <KIND> --configuration '<JSON>'
```

Or from a file:

```bash
clams connections create --label <LABEL> --kind <KIND> --configuration-file <PATH>
```

### Resolving Onchain Source and Network

Before creating an on-chain connection, resolve which onchain source to use and what `network` value to set. Do not ask the user unless genuinely ambiguous.

1. List sources: `clams onchain list --machine --format json`
2. **One source** → use it. No need to ask.
3. **Multiple sources** → infer the target network from the key or address prefix, then match to a source:
   - `xpub` / `vpub` / mainnet addresses (`bc1`, `1`, `3`) → mainnet → match sources whose label or URL indicate mainnet (e.g., `blockstream.info/api`, no `testnet`/`regtest`/`signet` in label or URL)
   - `tpub` / testnet addresses (`tb1`, `m`, `n`, `2`) → testnet-family → match sources whose label or URL contain `regtest`, `testnet`, or `signet`
4. **Still ambiguous** (e.g., multiple testnet-family sources) → ask the user.

Set the `network` configuration field based on what the matched source serves:

| Source indicator | `network` value |
|---|---|
| Default Esplora / mainnet URL | `"bitcoin"` |
| Label or URL contains `regtest` | `"regtest"` |
| Label or URL contains `testnet` | `"testnet"` |
| Label or URL contains `signet` | `"signet"` |

### On-Chain Wallets

**Descriptor**:

```bash
clams connections create --label my-wallet --kind Descriptor --configuration '{
  "descriptor": "wpkh([fingerprint/84h/0h/0h]xpub.../0/*)",
  "gap_limit": 20,
  "wallet_first_tx_block_height": 1,
  "network": "bitcoin"
}'
```

**XPub**:

```bash
clams connections create --label my-xpub --kind XPub --configuration '{
  "xpub": "xpub...",
  "address_types": ["bech32"],
  "gap_limit": 20,
  "wallet_first_tx_block_height": 1,
  "network": "bitcoin"
}'
```

**Address**:

```bash
clams connections create --label my-addrs --kind Address --configuration '{
  "addresses": ["bc1q..."],
  "wallet_first_tx_block_height": 1,
  "network": "bitcoin"
}'
```

### Lightning Wallets

**CoreLn (Commando)**:

```bash
clams connections create --label my-cln --kind CoreLn --configuration '{
  "transport": "commando",
  "config": {
    "address": "<pubkey>@127.0.0.1:9735",
    "rune": "<rune>"
  }
}'
```

**Lnd (LNC)**:

```bash
clams connections create --label my-lnd --kind Lnd --configuration '{
  "transport": "lnc",
  "config": {
    "pairing_phrase": "<10-word-phrase>"
  }
}'
```

**Lnd (gRPC)**:

```bash
clams connections create --label my-lnd --kind Lnd --configuration '{
  "transport": "grpc",
  "config": {
    "addr": "https://127.0.0.1:10009",
    "tls-cert": "<PEM>",
    "macaroon": "<HEX>"
  }
}'
```

**Nwc**:

```bash
clams connections create --label my-nwc --kind Nwc --configuration '{
  "uri": "nostr+walletconnect://<pubkey>?relay=wss%3A%2F%2Frelay.example&secret=<hex>",
  "timeout_secs": 10
}'
```

### Import-Only

```bash
# Phoenix (CSV import only, no config needed)
clams connections create --label phoenix --kind Phoenix

# River (CSV import only, no config needed)
clams connections create --label river --kind River

# Custom (manual, no config needed)
clams connections create --label manual --kind Custom
```

## List Connections

```bash
clams connections list
```

## Update a Connection

```bash
# Rename
clams connections update --label <LABEL> --new-label <NEW_LABEL>

# Update configuration
clams connections update --id <CONNECTION_ID> --configuration '<JSON>'
```

## Delete a Connection

```bash
clams connections delete --label <LABEL>
clams connections delete --id <CONNECTION_ID>
```

## Sync Connections

```bash
# Sync all connections
clams connections sync --all

# Sync one by label
clams connections sync --label <LABEL>

# Sync one by ID
clams connections sync --id <CONNECTION_ID>

# Increase parallelism for many connections
clams connections sync --all --sync-parallelism 8
```

## Import Data

```bash
# CSV file (e.g., Phoenix wallet export)
clams connections import --label phoenix --input-format csv --file phoenix.csv

# CSV folder (multiple files)
clams connections import --label phoenix --input-format csv --folder exports/

# JSON archive by type
clams connections import --id <ID> --archive-type Invoices --file invoices.json

# From stdin
cat pays.json | clams connections import --label core-ln --archive-type Pays --stdin
```

Archive types: `Invoices`, `Pays`, `Forwards`, `OpenChannels`, `ClosedChannels`, `Transactions`, `Utxos`, `Trades`

## After Creating/Syncing

Always process journals after syncing or importing — see [journal-processing.md](journal-processing.md).
