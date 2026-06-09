# Troubleshooting Runbook

All CLI errors in `--machine --format json` mode return structured JSON with `code` and `message` fields. **Always read the actual error output** before diagnosing — do not guess the cause from the symptom alone.

When a command fails and the error JSON doesn't give enough context, re-run with `--debug` appended to get verbose diagnostic output.

Start with the symptom, run the diagnostic commands, and follow the branch that matches.

## Quick State Check

Before diving into a specific symptom, run the verification script for an overview:

```bash
<skill-dir>/scripts/verify-state.sh
```

If `summary.all_ok` is `true`, the issue is likely in your command arguments or date ranges, not in setup state.

---

## Symptom: Empty or Missing Reports

**Diagnostic:**

```bash
clams journals events list --limit 1 --machine --format json
```

### → No events returned (empty array)

Journals haven't been processed. If the user confirms they already synced, skip re-syncing — the most likely cause is that `clams journals process` was never run afterward.

```bash
clams journals process --machine --format json
```

If processing succeeds but still returns no events, the connections have no data:

```bash
clams connections list --machine --format json
```

- **No connections** → create one: see [connections.md](connections.md)
- **Connections exist but no data** → sync first:

```bash
clams connections sync --all --machine --format json
```

Then re-process: `clams journals process --machine --format json`

### → Events exist but report is empty

Check if the report's date range excludes all events. For capital gains, the `--start` and `--end` must span a period with disposals.

Also check for quarantined events that may be hiding data:

```bash
clams journals quarantined --machine --format json
```

If quarantined items exist → see [Quarantine Backlog](#symptom-quarantine-backlog) below.

---

## Symptom: Auth Error

**Diagnostic:**

```bash
clams status --machine --format json
```

### → `auth.status` is not `"authenticated"`

```bash
clams login
```

This opens a browser. After login, verify:

```bash
clams status --machine --format json
```

### → Auth succeeds but commands still fail

Check that context is set:

```bash
clams context current --machine --format json
```

If workspace or profile is missing → `clams context set --profile <ID>`. See [onboarding.md](onboarding.md).

---

## Symptom: Sync Failure

**Diagnostic:** Run the sync and read the error JSON.

```bash
clams connections sync --label <LABEL> --machine --format json
```

### → Error mentions onchain source / electrum / esplora

On-chain connection types (`XPub`, `Descriptor`, `Address`) need an onchain source.

```bash
clams onchain list --machine --format json
```

- **No sources** → create one: see [onboarding.md](onboarding.md) step 7
- **Source exists but not assigned** → assign it:

```bash
clams profiles set --onchain-source-id <ID> --machine --format json
```

### → Error mentions "Liquid chain source does not satisfy the connection requirement"

A `LiquidDescriptor` connection needs a **Liquid-family** source (`LiquidEsplora`/`LiquidElectrum`); a Bitcoin source will not work. Create and select one, then re-sync and `clams journals process`. See [liquid.md](liquid.md).

```bash
clams onchain create --label liquid-blockstream --kind LiquidEsplora --url https://blockstream.info/liquid/api --select --machine --format json
```

### → Connection timeout or network error

Check that the endpoint is reachable. For Lightning nodes, verify the node is online. For Tor connections, confirm the proxy is running (`--tor-proxy`).

### → Error mentions authentication / rune / macaroon

The connection credentials may be expired or revoked. Update the connection configuration:

```bash
clams connections update --label <LABEL> --configuration '<NEW_JSON>' --machine --format json
```

---

## Symptom: Missing Exchange Rates

**Diagnostic:**

```bash
clams rates latest BTC-USD --machine --format json
```

### → Error or stale rate

Sync the rate cache:

```bash
clams rates sync --machine --format json
```

Then re-process journals (rates feed into cost basis calculations):

```bash
clams journals process --machine --format json
```

### → Rate exists but reports show wrong fiat values

Check the profile's fiat currency:

```bash
clams profiles get --machine --format json
```

If the currency is wrong, update it:

```bash
clams profiles set --fiat-currency <CODE> --machine --format json
```

Then re-process journals.

---

## Symptom: Quarantine Backlog

**Diagnostic:**

```bash
clams journals quarantined --machine --format json
```

### → Quarantined events exist

Inspect each one:

```bash
clams journals quarantine show --event-id <EVENT_ID> --machine --format json
```

Resolve based on the quarantine reason:

- **Collaborative (shared spend / coinjoin):**

```bash
clams journals quarantine resolve collaborative \
  --event-id <EVENT_ID> --fee-sats <SATS> --mode <send|transfer> \
  --machine --format json
```

- **Missing address:**

```bash
clams journals quarantine resolve missing-address \
  --event-id <EVENT_ID> --machine --format json
```

After resolving all items, re-process:

```bash
clams journals process --machine --format json
```

Verify the quarantine is clear:

```bash
clams journals quarantined --machine --format json
```

---

## Symptom: Stale Reports After Metadata Changes

If you added notes, tags, exclusions, rate overrides, or account adjustments but reports haven't changed:

```bash
clams journals process --machine --format json
```

Journals must be re-processed after any metadata change. Then regenerate the report.

---

## Symptom: Context Not Set

**Diagnostic:**

```bash
clams context current --machine --format json
```

### → Missing workspace or profile

List available options:

```bash
clams workspaces list --machine --format json
clams profiles list --machine --format json
```

Set the context:

```bash
clams context set --profile <PROFILE_ID_OR_LABEL> --machine --format json
```

---

## Symptom: PDF Won't Generate / WeasyPrint Not Found

**Diagnostic:** the render script exited non-zero. Check the exit code and message.

```bash
clams reports capital-gains --start ... --end ... --machine --format json \
  | <skill-dir>/scripts/render-capital-gains.sh --pdf out.pdf
echo "exit=$?"
```

### → Exit code 3, message "WeasyPrint is required ..."

No working WeasyPrint was found. The render scripts already search PATH, Homebrew, pip-user locations, and `python3 -m weasyprint`, and they functionally verify the candidate can render — so this means none works, not merely that it's off PATH.

**Do not run an unprompted install.** Instead:

1. Generate the report without PDF so the user isn't blocked:

```bash
# data report
clams reports capital-gains --start ... --end ... --format csv --output out.csv
# display report
clams reports balance-sheet --format plain
```

2. Tell the user PDF needs WeasyPrint and offer the one-time install, then retry **after they confirm**:

```bash
# macOS
brew install weasyprint
# Linux (Debian/Ubuntu)
sudo apt install weasyprint
```

**Never** `pip install weasyprint` into the system Python — it imports but fails to render (missing Pango/cairo/GDK-PixBuf).

### → WeasyPrint is installed but still not found

It's likely in a non-standard location. Point the skill at it directly and retry:

```bash
CLAMS_WEASYPRINT=/full/path/to/weasyprint \
  <skill-dir>/scripts/render-capital-gains.sh --pdf out.pdf < ...
```

Confirm the resolver sees it:

```bash
<skill-dir>/scripts/find-weasyprint.sh   # prints the resolved command, or exits 1
```

---

## Still Stuck?

If the error JSON doesn't match any symptom above:

```bash
clams <subcommand> --help
```

Read the `code` and `message` fields from the error output — they often contain the exact fix.
