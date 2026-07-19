#!/bin/bash
#
# One-time migration: copy secrets from macOS Keychain into 1Password (Private vault).
# Run this yourself — it handles secret values, so it is never run by an automated agent.
#
# For each known keychain service name, reads the value from Keychain (never printed)
# and creates or updates a matching 1Password item (category=password, vault=Private,
# value stored in the `password` field). After migrating, get-secret() in src/utils.sh
# will read from 1Password first and fall back to Keychain automatically — nothing else
# to change.

set -euo pipefail

VAULT="Private"

SERVICE_NAMES=(
    "CLICKUP_API_TOKEN"
    "SLITE_API_TOKEN"
    "cf-tunnel-tshallandale-prod-id"
    "cf-tunnel-tshallandale-prod-secret"
    "cf-tunnel-tshallandale-stg-id"
    "cf-tunnel-tshallandale-stg-secret"
)

created=()
updated=()
skipped=()

echo "Checking 1Password CLI access..."
if ! op account list >/dev/null 2>&1; then
    echo "ERROR: 'op account list' failed. The 1Password CLI is not integrated with your desktop app." >&2
    echo "Enable it in the 1Password app: Settings -> Developer -> \"Integrate with 1Password CLI\", then re-run this script." >&2
    exit 1
fi
echo "1Password CLI OK."
echo

for name in "${SERVICE_NAMES[@]}"; do
    echo "==> ${name}"

    value="$(security find-generic-password -s "$name" -a "$USER" -w 2>/dev/null || true)"
    if [[ -z "$value" ]]; then
        echo "    skip: not found in Keychain (service: ${name}, account: ${USER})"
        skipped+=("$name")
        continue
    fi

    if op item get "$name" --vault "$VAULT" >/dev/null 2>&1; then
        if op item edit "$name" --vault "$VAULT" "password=${value}" >/dev/null 2>&1; then
            echo "    updated existing 1Password item"
            updated+=("$name")
        else
            echo "    ERROR: failed to update 1Password item" >&2
            skipped+=("$name")
        fi
    else
        if op item create --category=password --title="$name" --vault="$VAULT" "password=${value}" >/dev/null 2>&1; then
            echo "    created new 1Password item"
            created+=("$name")
        else
            echo "    ERROR: failed to create 1Password item" >&2
            skipped+=("$name")
        fi
    fi

    unset value
done

echo
echo "=== Summary ==="
echo "Created (${#created[@]}): ${created[*]:-none}"
echo "Updated (${#updated[@]}): ${updated[*]:-none}"
echo "Skipped (${#skipped[@]}): ${skipped[*]:-none}"
echo
echo "Note: no secret values were printed above. Verify with, e.g.:"
echo "  op read \"op://${VAULT}/CLICKUP_API_TOKEN/password\" | wc -c"
