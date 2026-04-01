---
name: clams
description: >
  Use this skill when the user wants to do bookkeeping, accounting,
  or tax reporting for Bitcoin and Lightning. This includes tracking
  cost basis, generating capital gains reports, viewing balances, and
  managing journal entries. Applies even if they don't mention "Clams"
  directly — any request about BTC profit/loss, tax reports, portfolio
  value, cost basis tracking, or bitcoin accounting should use this skill.
metadata:
  author: clams-tech
  version: 1.0.0
---

## Skill Directory

All `scripts/` paths in this skill are relative to the directory containing this SKILL.md file. Before running any script, resolve the absolute path to this skill's directory first. For example, if this file is at `~/.claude/skills/clams/SKILL.md`, then scripts are at `~/.claude/skills/clams/scripts/`.

## Rules

1. **Before running any `clams` command**, source the user's shell profile to ensure PATH is set: `source ~/.zshenv 2>/dev/null; source ~/.bashrc 2>/dev/null`
2. **Always read the relevant reference file before running a command.** Do not guess flags or syntax — check the reference first
2. **Use `--machine --format json`** for commands whose output you need to parse or pipe to a script
2. **Use `--format plain`** when the user wants to see report output in the terminal — display the CLI output directly, do not reformat it
3. **Processing order**: sync → `clams rates sync` → `clams journals process` → reports
4. **For PDF reports**: pipe JSON through `<skill-dir>/scripts/render-<report>.sh --pdf <path>`
5. **For CSV reports**: use `--format csv --output <path>` on the report command itself (capital gains and journal entries only)
6. **Never** summarize or reformat amounts from CLI output — use render scripts, `--format plain`, or `--format csv` to let the CLI format them
7. **There is no `clams reports export` command** — PDF and CSV are produced as described above
8. **On errors**: read the error JSON (`code` and `message` fields) before diagnosing — do not guess the cause. If the error isn't clear, retry the command with `--debug` for more detailed output

## Gotchas

- **Empty reports?** You forgot `clams journals process`. This must run after every sync/import and before any report. It's the #1 mistake.
- **Amounts are in millisatoshis.** Never convert, round, summarize, or display raw JSON amounts. Always pipe through the render scripts or use `--format csv`.
- **`clams reports export` does not exist.** For PDF, pipe JSON through `<skill-dir>/scripts/render-*.sh`. For CSV, use `--format csv --output <path>` on the report command.
- **`clams init` is interactive-only.** It does not support `--machine` mode. Use the individual commands in [onboarding.md](references/onboarding.md) instead.
- **`clams setup` is for server admins.** Do not use it in CLI workflows — it configures the Clams server, not the client.
- **On-chain wallets need an onchain source first.** `XPub`, `Descriptor`, and `Address` connections will fail to sync without one. Create it during onboarding (step 7).
- **Re-process after metadata changes.** Notes, tags, exclusions, rate overrides, and account adjustments don't take effect until you run `clams journals process` again.
- **Omitting `--excluded` removes the exclusion.** `clams metadata records excluded set --event-id <ID>` without the `--excluded` flag un-excludes the event — this is intentional but counterintuitive.
- **Quarantine blocks accurate reports.** Unresolved quarantined events are omitted from reports. Always check `clams journals quarantined` if numbers look wrong.
- **All JSON responses are wrapped in a `data` envelope.** The shape is `{"kind": "...", "schema_version": 1, "data": ...}`. Always access `.data` to get the actual payload — lists may be at `.data` (array) or `.data.items` (paginated).
- **`--machine` requires `--format json`.** Never combine `--machine` with `--format csv` or `--format plain` — it will error. Use `--machine --format json` for scripting, or drop `--machine` and use `--format plain` / `--format csv` directly.
- **Not all reports support CSV.** Only capital gains and journal entries have CSV output. Balance sheet and portfolio summary support plain text and PDF only. See the format support table in [reports.md](references/reports.md).

## Data Hierarchy

```
workspace → profile → connections → journals → reports
                    → onchain sources (for on-chain wallets)
                    → metadata (notes, tags, exclusions)
```

## Workflow Routing

| User wants to... | Reference |
|---|---|
| Log in, create workspace/profile, configure settings, set up onchain source | [onboarding.md](references/onboarding.md) |
| Add wallets, list/update/delete connections, sync, import CSV/JSON | [connections.md](references/connections.md) |
| Manage onchain sources (Esplora, Electrum, Bitcoin RPC), Tor proxy | [onchain-sources.md](references/onchain-sources.md) |
| Import exchange CSV via custom mapping (csv_mapping), custom connections | [custom-connections.md](references/custom-connections.md) |
| Find/inspect a specific transaction by txid or event ID | [journal-processing.md](references/journal-processing.md) |
| Process journals, inspect quarantine, resolve quarantined events | [journal-processing.md](references/journal-processing.md) |
| Add notes, tags, exclusions, rate overrides, or account adjustments | [metadata.md](references/metadata.md) |
| Generate balance sheet, portfolio summary, capital gains, journal entries | [reports.md](references/reports.md) |
| Verify CLI readiness, check state before/after workflows | [verification.md](references/verification.md) |
| Diagnose errors or empty results | [troubleshooting.md](references/troubleshooting.md) |

## Fallback

```sh
clams --help
clams <subcommand> --help
```
