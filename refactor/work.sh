#!/bin/bash

# Base path for all your projects
export BASE_PATH="${HOME}/Desktop/work"

work() {
    # Setup logging
    setup_logging "work"

    local close_terminal=true

    # Parse options
    while getopts "c" opt; do
        case $opt in
        c) close_terminal=false ;;
        *) ;;
        esac
    done
    shift $((OPTIND - 1))

    if [ -z "$1" ]; then
        log "ERROR" "No project path provided"
        cat <<EOF
Usage: work [-c] <relative_path>
Options:
  -c    Keep terminal alive after opening VSCode
Opens VSCode in BASE_PATH/relative_path
EOF
        return 1
    fi

    # Validate input path
    if ! validate_path "$1"; then
        return 1
    fi

    local project_path="${BASE_PATH}/${1}"

    if [ ! -d "$project_path" ]; then
        log "ERROR" "Directory does not exist: $project_path"
        return 1
    fi

    log "INFO" "Opening VSCode in: $project_path"
    if ! safe_exec "nohup code '$project_path' >/dev/null 2>&1 &" "Failed to launch VSCode"; then
        return 1
    fi
    disown %?code

    log "INFO" "VSCode launched successfully"

    if $close_terminal; then
        log "INFO" "Closing terminal..."
        kill -9 $$
    fi
}

# Shell completion
if is_bash; then
    _work_complete() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local base_path="${BASE_PATH%/}"
        mapfile -t COMPREPLY < <(cd "$base_path" && compgen -d -- "$cur")
    }
    complete -F _work_complete work
elif is_zsh; then
    _work_complete() {
        local base_path="${BASE_PATH%/}"
        _files -W "$base_path" -/
    }
    compdef _work_complete work
fi
