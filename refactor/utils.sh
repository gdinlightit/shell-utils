#!/bin/bash

# Logging functionality
UTILS_LOG_DIR="${HOME}/.logs/shell-utils"
mkdir -p "$UTILS_LOG_DIR"

setup_logging() {
    local script_name="$1"
    LOG_FILE="${UTILS_LOG_DIR}/${script_name}_$(date +%Y%m%d_%H%M%S).log"
    local LOG_FILE
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    echo "$LOG_FILE"
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

# Service health check
wait_for_service() {
    local url="${1:-http://localhost}"
    local max_attempts="${2:-30}"
    local attempt=1
    local wait_seconds="${3:-2}"

    log "INFO" "Waiting for ${url} to become available..."

    while ! curl -s "${url}" >/dev/null; do
        if [ "${attempt}" -eq "${max_attempts}" ]; then
            log "ERROR" "Service failed to start after ${max_attempts} attempts"
            return 1
        fi
        log "INFO" "Attempt ${attempt}/${max_attempts}: Service not ready yet..."
        sleep "$wait_seconds"
        attempt=$((attempt + 1))
    done

    log "INFO" "Service is available!"
    return 0
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
