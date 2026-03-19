# Onboarding: Login, Workspace, Profile Setup

All commands below require `--machine --format json` appended. Shown without for brevity.

## 1. Check Status

```bash
clams status
```

If `auth.status` is not `"authenticated"`, proceed to login.

## 2. Login

```bash
clams login
```

Opens browser for authentication. Stores credentials locally. Use `clams login` again to re-authenticate if tokens expire.

`clams init` is an interactive alternative that walks through login, workspace creation, and profile creation — but it does not support `--machine` mode. Use the individual commands below for automation.

## 3. Create Workspace

```bash
clams workspaces create --label <LABEL>
```

Returns workspace ID. Save it for subsequent commands.

List existing workspaces:

```bash
clams workspaces list
```

## 4. Create Profile

```bash
clams profiles create --workspace <WORKSPACE_ID> --label <LABEL>
```

Returns profile ID.

## 5. Set Context (Default Workspace/Profile)

```bash
clams context set --profile <PROFILE_ID_OR_LABEL>
```

Once set, `-w` and `-p` flags can be omitted from subsequent commands.

To verify current context:

```bash
clams context current
```

## 6. Configure Profile Settings

```bash
clams profiles set --fiat-currency <CODE> --gains-algorithm <ALGORITHM>
```

- `--fiat-currency`: `USD`, `EUR`, `GBP`, `CAD`, `AUD`, `JPY`, `CHF`, etc.
- `--gains-algorithm`: `FIFO`, `LIFO`, `HIFO`, `LOFO`, `AVG_COST`

View current settings:

```bash
clams profiles get
```

## 6b. Sync Exchange Rates

After configuring fiat currency, sync the rate cache so reports have exchange rate data:

```bash
clams rates sync
```

## 7. Create Onchain Source (Required for On-Chain Wallets)

If the user needs on-chain wallet tracking (`XPub`, `Descriptor`, or `Address` connections), create an onchain data source first:

```bash
clams onchain create --label <LABEL> --kind <KIND> --url <URL> --select
```

- `--kind`: `Electrum`, `Esplora`, or `BitcoinRpc`
- `--select`: automatically sets this source as the active onchain source in profile settings
- For `BitcoinRpc`, add `--rpc-cookie <PATH>` or `--rpc-user <USER> --rpc-password <PASS>`

Examples:

```bash
# Electrum
clams onchain create --label primary --kind Electrum --url ssl://electrum.example.invalid:50002 --select

# Esplora
clams onchain create --label blockstream --kind Esplora --url https://blockstream.info/api --select

# Bitcoin Core RPC with cookie
clams onchain create --label core-rpc --kind BitcoinRpc --url http://127.0.0.1:8332 --rpc-cookie /path/to/.cookie --select

# Bitcoin Core RPC with user/pass
clams onchain create --label core-rpc --kind BitcoinRpc --url http://127.0.0.1:8332 --rpc-user admin --rpc-password secret --select
```

Without `--select`, manually assign the source:

```bash
clams profiles set --onchain-source-id <ONCHAIN_SOURCE_ID>
```

List existing onchain sources:

```bash
clams onchain list
```

## 8. Optional: Tor Proxy

```bash
clams profiles set --tor-proxy 127.0.0.1:9050
```

Clear with `--no-tor-proxy`.

## What's Next

- **Add connections** → see [connections.md](connections.md)
- **Sync and process** → see [journal-processing.md](journal-processing.md)
- **Generate reports** → see [reports.md](reports.md)

## Notes

- `clams setup` is for **server administration only** — do NOT use it in CLI workflows.
- `clams login` can be used standalone if the user is already initialized but needs to re-authenticate.
