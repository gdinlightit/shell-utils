#!/bin/bash

file-organizer() {
    setup_logging "file-organizer"

    usage() {
        cat <<EOF
Usage: file-organizer <base_name> <extension1> [extension2] ...

Organizes files with specified base name and extensions into a new directory.

Arguments:
    base_name   - The base name of the files to organize
    extension1  - First file extension (without dot)
    extension2+ - Additional file extensions (optional)

Example:
    file-organizer myfile txt pdf doc
    This will move myfile.txt, myfile.pdf, and myfile.doc into a directory named myfile/
EOF
        return 1
    }

    # Validate input arguments
    if [ "$#" -lt 2 ]; then
        log "ERROR" "Insufficient arguments provided"
        usage
        return 1
    fi

    local BASE_NAME="$1"
    shift
    local EXTENSIONS=("$@")

    # Validate base name
    if ! validate_path "$BASE_NAME"; then
        return 1
    fi

    # Check if any matching files exist
    local files_exist=false
    for ext in "${EXTENSIONS[@]}"; do
        if [ -f "${BASE_NAME}.${ext}" ]; then
            files_exist=true
            break
        fi
    done

    if [ "$files_exist" = false ]; then
        log "ERROR" "No matching files found for base name '${BASE_NAME}' with provided extensions"
        return 1
    fi

    # Create directory
    if ! ensure_dir "$BASE_NAME"; then
        return 1
    fi

    # Move matching files
    local moved_count=0
    for ext in "${EXTENSIONS[@]}"; do
        local source_file="${BASE_NAME}.${ext}"
        if [ -f "$source_file" ]; then
            log "INFO" "Moving file: $source_file"
            if safe_exec "mv '$source_file' '${BASE_NAME}/'" "Failed to move file: $source_file"; then
                ((moved_count++))
            fi
        else
            log "INFO" "File not found: $source_file"
        fi
    done

    if [ "$moved_count" -gt 0 ]; then
        log "INFO" "Successfully moved $moved_count file(s) to ${BASE_NAME}/"
        return 0
    else
        log "ERROR" "No files were moved"
        rmdir "$BASE_NAME" 2>/dev/null || true
        return 1
    fi
}

# Shell completion (same as before)
if is_bash; then
    _file_organizer_complete() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        if [ "$COMP_CWORD" -eq 1 ]; then
            mapfile -t COMPREPLY < <(compgen -f -- "$cur" | sed -n 's/\.[^.]*$//p' | sort -u)
        else
            local extensions="txt pdf doc docx jpg jpeg png gif mp3 mp4 zip"
            mapfile -t COMPREPLY < <(compgen -W "$extensions" -- "$cur")
        fi
    }
    complete -F _file_organizer_complete file-organizer
elif is_zsh; then
    _file_organizer_complete() {
        if [ "$CURRENT" -eq 2 ]; then
            _files -g "*.*(:r)"
        else
            local extensions=("css" "scss" "js" "tsx" "ts")
            _describe 'extensions' extensions
        fi
    }
    compdef _file_organizer_complete file-organizer
fi
