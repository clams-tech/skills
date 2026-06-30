# Liquid: Connections, Onchain Source, Assets

Liquid is a niche, opt-in workflow. Read this file only when the user mentions
Liquid, L-BTC, a Liquid CT descriptor (`ct(...)`), or a Liquid asset such as
USDt. Bitcoin-only sessions never need it.

All commands below require `--machine --format json` appended. Shown without for brevity.

## What Liquid support adds

- A connection kind, **`LiquidDescriptor`** — a watch-only Liquid wallet defined
  by confidential-transaction (CT) descriptors, with multi-asset accounting
  (L-BTC plus issued assets like USDt).
- Two new onchain source kinds, **`LiquidEsplora`** and **`LiquidElectrum`**.
- A second onchain-source *family*: a profile now keeps an independent default
  for **Bitcoin** and for **Liquid** (see below).

## Liquid needs its own onchain source

A Liquid connection will **not** sync against a Bitcoin Esplora/Electrum/Bitcoin
Core source. Liquid is a separate chain and needs a Liquid backend.

A profile keeps two independent chain-source selections, visible in
`clams profiles get` under `settings`:

- `bitcoin_chain_source_id` — used by `XPub`, `Descriptor`, `Address`
- `liquid_chain_source_id` — used by `LiquidDescriptor`

If `liquid_chain_source_id` is unset (or a Bitcoin source is selected), syncing a
`LiquidDescriptor` fails with an error containing:

> selected Liquid chain source does not satisfy the connection requirement

### Create and select a Liquid source

```bash
# Public Liquid Esplora (no auth) — the usual default
clams onchain create --label liquid-blockstream --kind LiquidEsplora \
  --url https://blockstream.info/liquid/api --select

# Liquid Electrum
clams onchain create --label liquid-electrum --kind LiquidElectrum \
  --url ssl://<host>:<port> --select
```

- The Liquid Esplora default endpoint is `https://blockstream.info/liquid/api`.
- `--select` (and `clams onchain select --id <id>`) sets the default **for that
  source's chain family**. Selecting a Liquid source sets the Liquid default and
  leaves the Bitcoin default untouched, and vice versa — both coexist.
- Use `LiquidEsplora` or `LiquidElectrum` for `LiquidDescriptor` sync. An
  `ElementsRpc` (Liquid/Elements Core RPC) kind is also exposed and can be created
  and selected as a Liquid source, but it is **not yet a `LiquidDescriptor` sync
  backend** — don't use it for wallet sync.

Manage the Liquid selection explicitly (parallel to the Bitcoin
`--onchain-source-id` / `--clear-onchain-source-id`):

```bash
clams profiles set --liquid-onchain-source-id <ONCHAIN_SOURCE_ID>
clams profiles set --clear-liquid-onchain-source-id
```

A `.onion` Liquid source needs the same Tor proxy setting as Bitcoin
(`clams profiles set --tor-proxy 127.0.0.1:9050`); it applies to all families.

## Create a Liquid connection

```bash
clams connections create --label my-liquid --kind LiquidDescriptor --configuration '{
  "descriptors": [
    "ct(slip77(<blinding-key>),elwpkh([fingerprint/84h/1776h/0h]xpub.../0/*))",
    "ct(slip77(<blinding-key>),elwpkh([fingerprint/84h/1776h/1h]xpub.../1/*))"
  ],
  "network": "liquid",
  "gap_limit": 20,
  "wallet_first_tx_block_height": 1
}'
```

For long CT descriptors, prefer `--configuration-file <PATH>` to avoid shell
quoting issues.

### Configuration fields

| Field | Required | Notes |
|---|---|---|
| `descriptors` | Yes | Array of Liquid CT descriptor strings. **Always plural**, even for one descriptor. Must be valid LWK `ct(...)` descriptors (not Bitcoin descriptors or xpubs) and unique. |
| `network` | No | `liquid` (default), `liquid_testnet`, or `liquid_regtest`. **Different values from Bitcoin** (`bitcoin`/`testnet`/`regtest`/`signet`). |
| `gap_limit` | No | Default `20`, range 1–1000. |
| `wallet_first_tx_block_height` | No | Earliest block height to scan; `>= 1` when present. |
| `asset_metadata` | No | Array of `{asset_id, ticker, name, precision}` registering non-policy Liquid assets as first-class assets during sync. `asset_id` is 64-char hex; `precision` is 0–18. |

Rejected fields (will error): the singular `descriptor`, the helper fields
`script_descriptor` / `slip77_blinding_key`, and the removed `asset_policy`.

**USDt is built in.** Liquid **mainnet** USDt is auto-registered on sync — do not
add it to `asset_metadata` (re-declaring it with different ticker/name/precision
is rejected). Use `asset_metadata` only for other issued assets you hold.

### Resolving network and source for a Liquid connection

- A `ct(...)` descriptor → a Liquid connection → match it to a **Liquid-family**
  source (`LiquidEsplora`/`LiquidElectrum`), never a Bitcoin source.
- Coin type `1776h` and a `liquid` source → `"network": "liquid"` (mainnet).
  Use `liquid_testnet` / `liquid_regtest` only when the source/descriptor clearly
  target those networks.

## Sync, process, report

```bash
clams connections sync --label my-liquid
clams rates sync
clams journals process
clams reports balance-sheet --format plain
```

Liquid balances appear under the **Liquid** account node (Assets → Liquid) and in
the portfolio summary, one row per asset (L-BTC and each issued asset).

## Multi-asset amounts

A Liquid connection tracks multiple assets: **L-BTC** (the policy asset) plus any
registered issued assets (e.g. **USDt**). Amounts are per-asset:

- L-BTC behaves like BTC.
- Issued assets carry their own precision (USDt mainnet uses precision 8).

As always, **do not convert or derive amounts yourself**. For display, use
`--format plain` (the engine formats every asset correctly) or `--format csv`,
or the bundled PDF render scripts. The "amounts are in millisatoshis" rule
applies to BTC and Liquid L-BTC (both sat-scaled); Liquid issued assets such as
USDt are denominated in their own units. You never hand-format these — let
`--format plain`/`--format csv` or the render scripts present them.

## Troubleshooting

- **Liquid sync fails / balances empty / "selected Liquid chain source does not
  satisfy the connection requirement"** → no Liquid-family source is selected (or
  a Bitcoin source was selected). Create a `LiquidEsplora`/`LiquidElectrum` source
  and `--select` it (or `clams profiles set --liquid-onchain-source-id`), then
  re-sync and `clams journals process`.
- **"descriptor is not supported" / "helper descriptor fields are not supported"**
  → use the plural `descriptors` array of full `ct(...)` descriptors.
- **"unsupported network"** → use `liquid`, `liquid_testnet`, or `liquid_regtest`.
