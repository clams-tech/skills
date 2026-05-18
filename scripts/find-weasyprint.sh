#!/usr/bin/env bash
# find-weasyprint.sh — Resolve a *working* WeasyPrint invocation.
#
# Prints the resolved command (one or more shell tokens) to stdout and exits 0
# when a candidate can actually produce a PDF in this environment. Prints
# nothing and exits 1 when none works.
#
# Why this exists: the common real-world failure is not "WeasyPrint is missing"
# but "WeasyPrint is installed (e.g. via Homebrew) yet not on the agent's
# non-interactive PATH", or "a pip install exists but can't import its native
# libraries". Existence is therefore not enough — every candidate is
# functionally smoke-tested by rendering a tiny HTML to a real PDF.
#
# Resolution order:
#   1. $CLAMS_WEASYPRINT  (explicit override — full path or command)
#   2. weasyprint on PATH
#   3. Known absolute locations (Homebrew arm64/x86, pip --user, framework py)
#   4. python3 -m weasyprint

set -u

_tmp="$(mktemp -t clams-weasy.XXXXXX 2>/dev/null || echo "/tmp/clams-weasy.$$.pdf")"
trap 'rm -f "$_tmp"' EXIT

# Returns 0 only if the candidate command actually renders a valid PDF.
_works() {
  printf '<html><body>.</body></html>' | "$@" -q - "$_tmp" >/dev/null 2>&1 || return 1
  [ -s "$_tmp" ] && [ "$(head -c 4 "$_tmp" 2>/dev/null)" = "%PDF" ]
}

# Emit candidate executables, one per line, best first.
_candidates() {
  [ -n "${CLAMS_WEASYPRINT:-}" ] && printf '%s\n' "$CLAMS_WEASYPRINT"
  command -v weasyprint 2>/dev/null || true
  local p
  for p in \
    /opt/homebrew/bin/weasyprint \
    /usr/local/bin/weasyprint \
    "${HOME:-}/.local/bin/weasyprint" \
    /usr/bin/weasyprint; do
    [ -n "$p" ] && [ -x "$p" ] && printf '%s\n' "$p"
  done
  for p in "${HOME:-}"/Library/Python/*/bin/weasyprint \
           /Library/Frameworks/Python.framework/Versions/*/bin/weasyprint; do
    [ -x "$p" ] && printf '%s\n' "$p"
  done
}

while IFS= read -r cand; do
  [ -n "$cand" ] || continue
  if _works "$cand"; then
    printf '%s\n' "$cand"
    exit 0
  fi
done < <(_candidates)

# Last resort: WeasyPrint as a Python module.
if command -v python3 >/dev/null 2>&1 && _works python3 -m weasyprint; then
  printf 'python3 -m weasyprint\n'
  exit 0
fi

exit 1
