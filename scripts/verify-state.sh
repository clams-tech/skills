#!/usr/bin/env bash
set -euo pipefail

# verify-state.sh — Checks Clams CLI readiness and data state.
# Outputs a JSON summary to stdout. Non-zero exit on critical failures.
#
# Usage:
#   ./clams/scripts/verify-state.sh
#   ./clams/scripts/verify-state.sh --section auth
#   ./clams/scripts/verify-state.sh --section connections
#
# Sections: auth, context, connections, journals, quarantine, all (default)

SECTION="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --section)
      SECTION="${2:?'--section requires a value: auth|context|connections|journals|quarantine|all'}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

RESULT="{}"
ERRORS=()

run_check() {
  local name="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "$output"
  else
    ERRORS+=("$name")
    echo "$output"
    return 1
  fi
}

check_auth() {
  local status_json
  if status_json=$(run_check "auth" clams status --machine --format json); then
    local auth_status
    auth_status=$(echo "$status_json" | jq -r '.data.auth.status // "unknown"')
    RESULT=$(echo "$RESULT" | jq --arg s "$auth_status" '.auth = {status: $s, ok: ($s == "authenticated")}')
    if [[ "$auth_status" != "authenticated" ]]; then
      ERRORS+=("auth")
    fi
  else
    RESULT=$(echo "$RESULT" | jq '.auth = {status: "error", ok: false, error: "clams status failed"}')
  fi
}

check_context() {
  local ctx_json
  if ctx_json=$(run_check "context" clams context current --machine --format json); then
    local has_workspace has_profile
    has_workspace=$(echo "$ctx_json" | jq '.data | has("selected_workspace_id") and .selected_workspace_id != null')
    has_profile=$(echo "$ctx_json" | jq '.data | has("selected_profile_id") and .selected_profile_id != null')
    RESULT=$(echo "$RESULT" | jq \
      --argjson w "$has_workspace" \
      --argjson p "$has_profile" \
      '.context = {workspace_set: $w, profile_set: $p, ok: ($w and $p)}')
    if [[ "$has_workspace" != "true" || "$has_profile" != "true" ]]; then
      ERRORS+=("context")
    fi
  else
    RESULT=$(echo "$RESULT" | jq '.context = {workspace_set: false, profile_set: false, ok: false, error: "clams context current failed"}')
  fi
}

check_connections() {
  local conn_json
  if conn_json=$(run_check "connections" clams connections list --machine --format json); then
    local count
    count=$(echo "$conn_json" | jq '.data | if type == "array" then length else 0 end')
    RESULT=$(echo "$RESULT" | jq --argjson c "$count" '.connections = {count: $c, ok: ($c > 0)}')
    if [[ "$count" == "0" ]]; then
      ERRORS+=("connections")
    fi
  else
    RESULT=$(echo "$RESULT" | jq '.connections = {count: 0, ok: false, error: "clams connections list failed"}')
  fi
}

check_journals() {
  local events_json
  if events_json=$(run_check "journals" clams journals events list --limit 1 --machine --format json); then
    local count
    count=$(echo "$events_json" | jq '.data.items | if type == "array" then length else 0 end')
    local has_events=$( [[ "$count" -gt 0 ]] && echo true || echo false )
    RESULT=$(echo "$RESULT" | jq --argjson h "$has_events" '.journals = {has_events: $h, ok: $h}')
    if [[ "$has_events" != "true" ]]; then
      ERRORS+=("journals")
    fi
  else
    RESULT=$(echo "$RESULT" | jq '.journals = {has_events: false, ok: false, error: "clams journals events list failed"}')
  fi
}

check_quarantine() {
  local q_json
  if q_json=$(run_check "quarantine" clams journals quarantined --machine --format json); then
    local count
    count=$(echo "$q_json" | jq '.data.items | if type == "array" then length else 0 end')
    RESULT=$(echo "$RESULT" | jq --argjson c "$count" '.quarantine = {unresolved_count: $c, ok: ($c == 0)}')
    if [[ "$count" -gt 0 ]]; then
      ERRORS+=("quarantine")
    fi
  else
    RESULT=$(echo "$RESULT" | jq '.quarantine = {unresolved_count: 0, ok: false, error: "clams journals quarantined failed"}')
  fi
}

case "$SECTION" in
  auth)        check_auth ;;
  context)     check_context ;;
  connections) check_connections ;;
  journals)    check_journals ;;
  quarantine)  check_quarantine ;;
  all)
    check_auth
    check_context
    check_connections
    check_journals
    check_quarantine
    ;;
  *)
    echo "Unknown section: $SECTION" >&2
    exit 1
    ;;
esac

# Add summary
ALL_OK=$( [[ ${#ERRORS[@]} -eq 0 ]] && echo true || echo false )
if [[ ${#ERRORS[@]} -eq 0 ]]; then
  ERRS_JSON="[]"
else
  ERRS_JSON=$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)
fi
RESULT=$(echo "$RESULT" | jq \
  --argjson ok "$ALL_OK" \
  --argjson errs "$ERRS_JSON" \
  '.summary = {all_ok: $ok, issues: $errs}')

echo "$RESULT" | jq .
