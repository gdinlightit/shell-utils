#!/bin/bash

# Logging functionality
UTILS_LOG_DIR="${HOME}/.logs/shell-utils"
mkdir -p "$UTILS_LOG_DIR"

cleanup_old_logs() {
    local days_to_keep="${1:-30}"
    log "INFO" "Cleaning up logs older than $days_to_keep days"
    find "$UTILS_LOG_DIR" -type f -name "*.log" -mtime "+${days_to_keep}" -delete
}

setup_logging() {
    local script_name="$1"

    local LOG_FILE
    LOG_FILE="${UTILS_LOG_DIR}/${script_name}_$(date +%Y%m%d_%H%M%S).log"

    exec 1> >(tee -ia "${LOG_FILE}")
    exec 2> >(tee -ia "${LOG_FILE}" >&2)
    log "DEBUG" "Logging to file $LOG_FILE"

    # Cleanup old logs when setting up new logging
    cleanup_old_logs 30
}

log() {
    local level="$1"
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*"
}

# Input validation
validate_path() {
    local path="$1"
    if [[ "$path" =~ [[:space:]] ]]; then
        log "ERROR" "Path cannot contain whitespace"
        return 1
    fi

    if [[ "$path" =~ [\\] ]]; then
        log "ERROR" "Path cannot contain backslashes"
        return 1
    fi
}

# Safe command execution
safe_exec() {
    local cmd="$1"
    local error_msg="${2:-Command failed}"

    if ! eval "$cmd"; then
        log "ERROR" "$error_msg"
        return 1
    fi
    return 0
}

# Directory operations
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log "INFO" "Creating directory: $dir"
        if ! mkdir -p "$dir"; then
            log "ERROR" "Failed to create directory: $dir"
            return 1
        fi
    fi
    return 0
}

# Shell detection and compatibility
is_bash() {
    [ -n "$BASH_VERSION" ]
}

is_zsh() {
    [ -n "$ZSH_VERSION" ]
}

setup_completion() {
    local command="$1"
    local completion_function="$2"

    if is_bash; then
        complete -F "$completion_function" "$command"
    elif is_zsh; then
        compdef "$completion_function" "$command"
    fi
}

# File extension completion
setup_file_extension_completion() {
    local command="$1"
    shift
    local default_extensions=("$@")

    if is_bash; then
        eval "_${command}_complete() {
            local cur=\"\${COMP_WORDS[COMP_CWORD]}\"
            if [ \"\$COMP_CWORD\" -eq 1 ]; then
                mapfile -t COMPREPLY < <(compgen -f -- \"\$cur\" | sed -n 's/\\.[^.]*\$//p' | sort -u)
            else
                local extensions=\"${default_extensions[*]}\"
                mapfile -t COMPREPLY < <(compgen -W \"\$extensions\" -- \"\$cur\")
            fi
        }"
        setup_completion "$command" "_${command}_complete"
    elif is_zsh; then
        eval "_${command}_complete() {
            if [ \"\$CURRENT\" -eq 2 ]; then
                _files -g \"*.*(:r)\"
            else
                local extensions=(${default_extensions[*]})
                _describe 'extensions' extensions
            fi
        }"
        setup_completion "$command" "_${command}_complete"
    fi
}

# Directory completion with base path
setup_directory_completion() {
    local command="$1"
    local base_path_var="$2"

    if is_bash; then
        eval "_${command}_complete() {
            local cur=\"\${COMP_WORDS[COMP_CWORD]}\"
            local base_path=\"\${${base_path_var}%/}\"
            mapfile -t COMPREPLY < <(cd \"\$base_path\" && compgen -d -- \"\$cur\")
        }"
        setup_completion "$command" "_${command}_complete"
    elif is_zsh; then
        eval "_${command}_complete() {
            local base_path=\"\${${base_path_var}%/}\"
            _files -W \"\$base_path\" -/
        }"
        setup_completion "$command" "_${command}_complete"
    fi
}

# Secret resolution: 1Password CLI first, macOS Keychain as fallback.
# Usage: get-secret <name>   (prints the secret to stdout; returns 1 if not found anywhere)
# Set SECRETS_DEBUG=1 to log (to stderr) which backend served the secret.
get-secret() {
    local name="${1:?Usage: get-secret <name>}"
    local value

    value="$(op read "op://Private/${name}/password" 2>/dev/null)"
    if [[ -n "$value" ]]; then
        [[ -n "$SECRETS_DEBUG" ]] && log "DEBUG" "get-secret: served '${name}' from 1Password" >&2
        printf '%s' "$value"
        return 0
    fi

    value="$(security find-generic-password -s "$name" -a "$USER" -w 2>/dev/null)"
    if [[ -n "$value" ]]; then
        [[ -n "$SECRETS_DEBUG" ]] && log "DEBUG" "get-secret: served '${name}' from macOS Keychain (fallback)" >&2
        printf '%s' "$value"
        return 0
    fi

    log "ERROR" "Secret '${name}' not found in 1Password or Keychain" >&2
    log "INFO" "Add it to 1Password with: op item create --category=password --title=\"${name}\" --vault=Private password=\"<value>\"" >&2
    log "INFO" "Or add it to Keychain with: security add-generic-password -s \"${name}\" -a \"\$USER\" -w \"<value>\"" >&2
    return 1
}

# Migrate one or more secrets from macOS Keychain into 1Password (Private vault).
# Usage: secret-migrate <name> [<name>...]
# For each name: reads it from Keychain, then creates or updates a matching
# 1Password item (category=password, vault=Private, value in the `password` field).
# Never prints secret values. Requires the 1Password CLI to be integrated with the
# desktop app (Settings -> Developer -> "Integrate with 1Password CLI").
secret-migrate() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: secret-migrate <name> [<name>...]" >&2
        echo "  Reads each name from macOS Keychain and creates/updates a matching" >&2
        echo "  1Password item (Private vault, password field). Never prints values." >&2
        echo "Example (one-off future tokens, straight from the shell):" >&2
        echo "  secret-migrate CLICKUP_API_TOKEN SLITE_API_TOKEN cf-tunnel-tshallandale-prod-id cf-tunnel-tshallandale-prod-secret cf-tunnel-tshallandale-stg-id cf-tunnel-tshallandale-stg-secret" >&2
        return 1
    fi

    local vault="Private"

    echo "Checking 1Password CLI access..."
    if ! op account list >/dev/null 2>&1; then
        log "ERROR" "'op account list' failed. The 1Password CLI is not integrated with your desktop app." >&2
        log "INFO" "Enable it in the 1Password app: Settings -> Developer -> \"Integrate with 1Password CLI\", then re-run." >&2
        return 1
    fi
    echo "1Password CLI OK."
    echo

    local created=() updated=() skipped=()
    local name value

    for name in "$@"; do
        echo "==> ${name}"

        value="$(security find-generic-password -s "$name" -a "$USER" -w 2>/dev/null || true)"
        if [[ -z "$value" ]]; then
            echo "    skip: not found in Keychain (service: ${name}, account: ${USER})"
            skipped+=("$name")
            continue
        fi

        if op item get "$name" --vault "$vault" >/dev/null 2>&1; then
            if op item edit "$name" --vault "$vault" "password=${value}" >/dev/null 2>&1; then
                echo "    updated existing 1Password item"
                updated+=("$name")
            else
                echo "    ERROR: failed to update 1Password item" >&2
                skipped+=("$name")
            fi
        else
            if op item create --category=password --title="$name" --vault="$vault" "password=${value}" >/dev/null 2>&1; then
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
    echo "  op read \"op://${vault}/<name>/password\" | wc -c"
}

load-env() {
    local filename="${1:-.env}"
    local caller_dir
    if is_bash; then
        caller_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    elif is_zsh; then
        # funcfiletrace[1] = "filepath:lineno" of the call site
        caller_dir="$(cd "$(dirname "${funcfiletrace[1]%:*}")" && pwd)"
    fi
    local env_file="${caller_dir}/../${filename}"

    if [[ -f "$env_file" ]]; then
        source "$env_file"
    else
        log "WARNING" "No .env file found at: $env_file"
    fi
}
