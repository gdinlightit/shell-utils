#!/bin/bash

# Base path for all your projects
export BASE_PATH="${HOME}/Desktop/work"

work() {
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
        echo "Usage: work [-c] <relative_path>"
        echo "Options:"
        echo "  -c    Keep terminal alive after opening VSCode"
        echo "Opens VSCode in BASE_PATH/relative_path"
        return 1
    fi
    local project_path="${BASE_PATH}/${1}"

    if [ ! -d "$project_path" ]; then
        echo "Error: Directory does not exist: $project_path"
        return 1
    fi

    nohup code "$project_path" >/dev/null 2>&1 &
    disown %?code

    if $close_terminal; then
        kill -9 $$
    fi
}

# For bash and zsh compatibility
if [ -n "$BASH_VERSION" ]; then
    _work_complete() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local base_path="${BASE_PATH%/}" # Remove trailing slash if present

        # Generate completions for subdirectories relative to BASE_PATH
        mapfile -t COMPREPLY < <(cd "$base_path" && compgen -d -- "$cur")
    }
    complete -F _work_complete work
elif [ -n "$ZSH_VERSION" ]; then
    # zsh completion
    _work_complete() {
        local base_path="${BASE_PATH%/}"
        _files -W "$base_path" -/
    }
    compdef _work_complete work
fi
