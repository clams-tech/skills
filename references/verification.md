# Verification: Checking CLI State

Use `<skill-dir>/scripts/verify-state.sh` to confirm the CLI is ready before running workflows, or to diagnose what's wrong after unexpected results.

## Full Check

```bash
<skill-dir>/scripts/verify-state.sh
```

Returns JSON with a section for each check (`auth`, `context`, `connections`, `journals`, `quarantine`) and a `summary.all_ok` boolean.

## Single Section

```bash
<skill-dir>/scripts/verify-state.sh --section auth
<skill-dir>/scripts/verify-state.sh --section context
<skill-dir>/scripts/verify-state.sh --section connections
<skill-dir>/scripts/verify-state.sh --section journals
<skill-dir>/scripts/verify-state.sh --section quarantine
```

## When to Run

- **Before a workflow**: Run a full check before sync → process → report to catch setup issues early.
- **After sync/import**: Run `--section journals` and `--section quarantine` to confirm data landed.
- **When reports are empty or wrong**: Run a full check — the `summary.issues` array tells you exactly what's broken.
- **After resolving quarantine**: Run `--section quarantine` to confirm no unresolved items remain.

## Reading the Output

Each section has an `ok` field:

| Section | `ok: true` means | `ok: false` means |
|---|---|---|
| `auth` | Authenticated | Token expired or never logged in → `clams login` |
| `context` | Workspace + profile set | Context not configured → `clams context set` |
| `connections` | At least one connection exists | No connections → see [connections.md](connections.md) |
| `journals` | Journal events exist | No events → sync then `clams journals process` |
| `quarantine` | No unresolved quarantine items | Unresolved items → see [journal-processing.md](journal-processing.md) |

The top-level `summary.all_ok` is `true` only when every section passes.
