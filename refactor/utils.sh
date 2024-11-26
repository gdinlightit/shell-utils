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
