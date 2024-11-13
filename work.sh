#!/bin/bash

# Base path for all your projects
export BASE_PATH="${HOME}/Desktop/work"

work() {
    if [ -z "$1" ]; then
        echo "Usage: work <relative_path>"
        echo "Opens VSCode in BASE_PATH/relative_path"
        return 1
    fi

    local project_path="${BASE_PATH}/${1}"

    if [ ! -d "$project_path" ]; then
        echo "Error: Directory does not exist: $project_path"
        return 1
    fi

    code "$project_path"
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