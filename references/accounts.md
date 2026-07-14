# Accounts (Chart of Accounts)

Accounts are the ledger categories journal entries post to (the structure you see in the balance
sheet: Assets → On-chain / Lightning / Liquid / Managed, Liabilities, Equity, …). The engine
provides the built-in accounts; users can add **custom accounts** under an existing parent to
categorize activity their way.

All commands below require `--machine --format json` appended for scripting. Shown without for
brevity.

**Where accounts matter in other workflows:**

- `clams metadata records adjustments add … --account-id <ACCOUNT_ID>` — reassign a journal
  entry to a different account ([metadata.md](metadata.md)). Use `accounts list` to find the id.
- `clams journals events list --account <ACCOUNT_LABEL_OR_ID>` — filter events by account.
- `clams reports balance-history --account <…>` — per-account balance trends.

## List and Inspect

```bash
# All accounts (built-in and custom) with ids, labels, and hierarchy
clams accounts list

# One account (selector is a positional UUID, or --id)
clams accounts get <ACCOUNT_ID>
```

Run `accounts list` before any adjustment workflow — never guess an account id.

## Create a Custom Account

Custom accounts attach under an existing parent account:

```bash
clams accounts create --parent-id <PARENT_ACCOUNT_ID> --label "Cash"
clams accounts create --parent-id <PARENT_ACCOUNT_ID> --label "Cash" --description "Wallet float"
```

Choose the parent from `accounts list` — the new account inherits its place in the balance-sheet
hierarchy from the parent. Ask the user which parent fits their intent if it's ambiguous
(e.g., an asset vs. an expense bucket); do not silently pick one.

## Update or Delete a Custom Account

Only custom accounts can be updated or deleted (built-in accounts are engine-managed):

```bash
clams accounts update <ACCOUNT_ID> --label "New Label"
clams accounts update <ACCOUNT_ID> --description "New description"
clams accounts update <ACCOUNT_ID> --parent-id <NEW_PARENT_ID>

clams accounts delete <ACCOUNT_ID>
```

If a delete is rejected, read the error — an account referenced by adjustments or postings may
need those references removed first. Surface the error to the user rather than force-removing
their categorization.

## After Changing Accounts

Account changes affect how journal entries are categorized. Re-process before reporting:

```bash
clams journals process
```
