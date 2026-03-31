# Onboarding: Login, Workspace, Profile Setup

All commands below require `--machine --format json` appended. Shown without for brevity.

## 1. Check Status

```bash
clams status
```

If `auth.status` is not `"authenticated"`, proceed to onboarding.

## 2. Fresh Install Onboarding

On a fresh install, the CLI gates all commands behind `clams init`. Use non-interactive mode:

```bash
clams init --workspace-label default --profile-label default
```

This will open the user's browser for authentication. **Before running this command**, tell the user a browser window will open for login. Use a **5-minute timeout** since the user needs to complete browser authentication:

```bash
# Example with timeout (agent should use 300000ms / 5 minutes)
clams init --workspace-label default --profile-label default
```

Once init completes, the user is logged in with a workspace and profile created. Proceed to step 5.

**Important:** Do NOT use `clams login`, `clams workspaces create`, or `clams profiles create` as standalone commands on a fresh install. The CLI will reject them with "First run requires interactive onboarding; run `clams init`."

## 3. Re-authentication (Existing Install)

If the user was previously set up but their token expired:

```bash
clams login
```

Opens browser for authentication. Use a **5-minute timeout**.

## 4. Create Workspace (Existing Install Only)

Only needed if adding a new workspace after initial setup.

```bash
clams workspaces create --label <LABEL>
```

Returns workspace ID. Save it for subsequent commands.

List existing workspaces:

```bash
clams workspaces list
```

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

## 7. Create Onchain Source

An onchain source is required for Clams to function. All connection types (on-chain wallets, Lightning nodes, exchanges) depend on it. Always create one during onboarding.

Ask the user if they have their own Electrum server, Esplora instance, or Bitcoin Core RPC node. If they don't (or are unsure), use the public Blockstream Esplora API as the default:

```bash
clams onchain create --label blockstream --kind Esplora --url https://blockstream.info/api --select
```

Other examples if the user has their own infrastructure:

```bash
# Electrum
clams onchain create --label primary --kind Electrum --url ssl://electrum.example.invalid:50002 --select

# Bitcoin Core RPC with cookie
clams onchain create --label core-rpc --kind BitcoinRpc --url http://127.0.0.1:8332 --rpc-cookie /path/to/.cookie --select

# Bitcoin Core RPC with user/pass
clams onchain create --label core-rpc --kind BitcoinRpc --url http://127.0.0.1:8332 --rpc-user admin --rpc-password secret --select
```

- `--select`: automatically sets this source as the active onchain source in profile settings
- For `BitcoinRpc`, add `--rpc-cookie <PATH>` or `--rpc-user <USER> --rpc-password <PASS>`

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

- **Add connections** -> see [connections.md](connections.md)
- **Sync and process** -> see [journal-processing.md](journal-processing.md)
- **Generate reports** -> see [reports.md](reports.md)

## Notes

- `clams setup` is for **server administration only** -- do NOT use it in CLI workflows.
- `clams login` can be used standalone if the user is already initialized but needs to re-authenticate.
