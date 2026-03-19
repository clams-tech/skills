# Onchain Sources

An onchain source is the blockchain backend that on-chain wallet connections (`XPub`, `Descriptor`, `Address`) use to sync data. Each profile has one active onchain source.

All commands below require `--machine --format json` appended. Shown without for brevity.

## Kinds

| Kind | URL example | Auth |
|---|---|---|
| `Esplora` | `https://blockstream.info/api` | None |
| `Electrum` | `ssl://electrum.example.invalid:50002` | None |
| `BitcoinRpc` | `http://127.0.0.1:8332` | Cookie file or user/pass |

The Clams CLI defaults to Blockstream's Esplora API (`https://blockstream.info/api`) during onboarding.

## List

```bash
clams onchain list
```

## Create

```bash
clams onchain create --label <LABEL> --kind <KIND> --url <URL> --select
```

- `--select`: automatically sets this source as the active onchain source in profile settings

### Examples

```bash
# Esplora (public, no auth)
clams onchain create --label blockstream --kind Esplora --url https://blockstream.info/api --select

# Electrum
clams onchain create --label my-electrum --kind Electrum --url ssl://electrum.example.invalid:50002 --select

# Bitcoin Core RPC with cookie
clams onchain create --label core-rpc --kind BitcoinRpc --url http://127.0.0.1:8332 --rpc-cookie /path/to/.cookie --select

# Bitcoin Core RPC with user/pass
clams onchain create --label core-rpc --kind BitcoinRpc --url http://127.0.0.1:8332 --rpc-user admin --rpc-password secret --select
```

Without `--select`, manually assign the source:

```bash
clams profiles set --onchain-source-id <ONCHAIN_SOURCE_ID>
```

## Update

```bash
clams onchain update --id <ONCHAIN_ID> --url <NEW_URL>
clams onchain update --id <ONCHAIN_ID> --label <NEW_LABEL>
clams onchain update --id <ONCHAIN_ID> --kind <NEW_KIND> --url <NEW_URL>
```

For `BitcoinRpc`, switch auth methods:

```bash
# Switch from user/pass to cookie
clams onchain update --id <ONCHAIN_ID> --clear-rpc-credentials --rpc-cookie /path/to/.cookie

# Switch from cookie to user/pass
clams onchain update --id <ONCHAIN_ID> --clear-rpc-cookie --rpc-user admin --rpc-password secret
```

## Delete

```bash
clams onchain delete --id <ONCHAIN_ID>
```

## Tor

If the onchain source URL is a `.onion` address (e.g. a Tor-hidden Electrum server), the profile must also have a Tor proxy configured:

```bash
clams profiles set --tor-proxy 127.0.0.1:9050
```

Clear with:

```bash
clams profiles set --no-tor-proxy
```

The Tor proxy applies to all onchain connections for that profile. Make sure a SOCKS5 proxy (e.g. Tor daemon) is running at the specified address.

## After Changing Onchain Source

After switching or updating an onchain source, re-sync affected connections and re-process journals:

```bash
clams connections sync --all
clams journals process
```
