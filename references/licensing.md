# Licensing, Billing, and Profile Capacity

Clams v1 is a paid product: an annual **subject license** (per user account) plus per-instance
**profile capacity** (slots for profiles on a backend instance). Reports, syncs, and
profile/workspace creation are gated on an active license, and profile creation is additionally
gated on available capacity.

**Payment is always user-initiated.** Never start a checkout, renew a license, or buy capacity
unless the user explicitly asks. Before any checkout, show the user the amount the CLI prints and
let them complete payment themselves. Never accept checkout terms on the user's behalf — the
`--accept-*` flags exist for scripted use but must only be passed when the user has explicitly
confirmed acceptance of the exact documents shown.

## License Status

```bash
clams license status
clams license status --machine --format json
```

Shows state (`active` or inactive with a reason such as `revoked`), plan, validity window, and the
latest invoice (kind, payment method, status, total). This is the first command to run when any
paid workflow is rejected.

## Onboarding with Payment

`clams setup` initializes the backend data root, provisions service OAuth credentials, and walks
the license checkout when the account has no active license:

```bash
clams setup                      # prompts for payment method when a license is needed
clams setup --payment card       # hosted card checkout (opens browser)
clams setup --payment lightning  # BOLT11 invoice + QR code in the terminal
clams setup --rotate             # rotate existing credentials
```

`clams init` runs the same license gate before creating workspace/profile state, and accepts the
same `--payment` flag. Both commands, when payment is needed:

1. Print the checkout terms (terms of use, privacy policy, renewal policy) and prompt for
   acceptance.
2. Print the invoice: id, amount, payment URL (card) or BOLT11 invoice and QR (lightning).
3. Poll until the provider confirms payment and the license activates. Polling can take minutes —
   use a generous timeout and tell the user the CLI is waiting on payment confirmation.

Card checkout opens the user's browser. Lightning checkout stays in the terminal; the user pays
the displayed invoice from their own wallet.

## Renewal

```bash
clams license renew --payment card
clams license renew --payment lightning
clams license renew --payment card --license-only
```

Renewal bundles the subject license with any paid profile capacity on the current instance into
one invoice by default; both renewed entitlements share the new validity window. `--license-only`
renews just the subject license (support scenarios).

## Invoice Status

Non-interactive checkout tracking, using the invoice id printed at checkout:

```bash
clams license invoice status --invoice-id <INVOICE_ID>
clams license invoice status --invoice-id <INVOICE_ID> --machine --format json
```

## Instance Status

Each local backend data root registers as an **instance** with the auth service. Licenses belong
to the user (subject); capacity belongs to the instance.

```bash
clams instance status
```

Shows the instance id, logged-in subject, whether SVC credentials are bound to this instance,
the local admin, access mode, and the billing owner. `SVC credentials bound: yes` is required for
paid workflows; if binding is missing, `clams logout` then `clams login` usually repairs it.

## Profile Capacity

Profiles consume capacity slots on the instance. The license includes default capacity that is
assigned to the **first instance the subject ever enrolls** — a later instance (fresh data root,
reinstall, second machine) starts with zero capacity and needs a capacity purchase or a support
restore.

```bash
# Current capacity and usage for this instance
clams instance capacity status
clams instance capacity status --machine --format json

# Price extra slots without buying (graduated annual pricing, prorated to license expiry)
clams instance capacity quote --profiles <N>

# Buy slots (checkout flow, same payment methods and terms prompts as setup)
clams instance capacity add --profiles <N> --payment card
clams instance capacity add --profiles <N> --payment lightning
```

Quotes show capacity before/after, proration details, and the shared license/capacity expiry.
Always run `quote` and show the user the amount before they decide to `add`.

### Capacity errors at profile creation

`clams profiles create` (and `clams init`) fail when the instance is out of capacity:

```
Profile capacity limit reached: <used> of <limit> profiles are in use.
```

- If the user wants another profile, quote and (with their confirmation) buy capacity, then retry
  profile creation.
- **Right after a capacity purchase**, the stored credentials can briefly lag the new entitlement.
  The CLI refreshes automatically; if profile creation still reports a stale capacity
  entitlement, retry the command once, and run `clams login` if it persists.
- A `0 of 0` limit on a freshly set-up root usually means this is not the subject's first
  instance (see above), not a billing failure.

## Billing Owner and Local Admin

```bash
clams instance billing-owner status      # who pays for this instance's capacity
clams instance billing-owner transfer    # transfer billing ownership to another subject
clams instance local-admin --help        # local instance administrator management
```

Billing-owner transfer is a guarded, owner-authorized operation — surface the CLI's prompts to the
user rather than automating them.

## Support Enrollment Artifact

```bash
clams instance enrollment request --request-id <SUPPORT_REQUEST_ID>
```

Emits a root-key-signed, non-secret artifact for support-led backfill of an existing local root
(e.g., restoring included capacity to a reinstalled instance). Only needed when support asks
for it.

## Troubleshooting Paid Workflows

| Symptom | Likely cause | Fix |
|---|---|---|
| `login required` / `E401-REAUTH-REQUIRED` | No or expired credentials | `clams login` |
| "issue authorizing this Clams instance with the stored login" | SVC credentials not bound to this instance | `clams logout`, `clams login`, retry |
| `license status` shows inactive/`revoked` | Lapsed or refunded license | `clams license renew` (user decision) |
| `Profile capacity limit reached` | Instance out of slots | `instance capacity quote`, then `add` with user confirmation |
| Stale capacity right after purchase | Entitlement refresh lag | Retry once; `clams login` if it persists |
