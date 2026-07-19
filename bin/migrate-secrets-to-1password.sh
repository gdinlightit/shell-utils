#!/bin/bash
#
# One-time (or one-off) migration: copy secrets from macOS Keychain into 1Password
# (Private vault). Run this yourself — it handles secret values, so it is never run
# by an automated agent.
#
# Thin wrapper around secret-migrate() in src/utils.sh — pass the Keychain service
# name(s) you want migrated. After migrating, get-secret() in the same file will
# read them from 1Password first and fall back to Keychain automatically — nothing
# else to change.
#
# Usage:
#   ./bin/migrate-secrets-to-1password.sh CLICKUP_API_TOKEN SLITE_API_TOKEN ...

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=../src/utils.sh
source "${SCRIPT_DIR}/../src/utils.sh"

secret-migrate "$@"
