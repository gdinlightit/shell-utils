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
