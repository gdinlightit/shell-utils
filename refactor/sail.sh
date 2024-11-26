#!/bin/bash

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

sail-init() {
    # Setup logging
    setup_logging "sail-init"

    # Check if project name was provided
    if [ -z "$1" ]; then
        log "ERROR" "Project name not provided"
        cat <<EOF
Usage: sail-init <project-name>
Sets up a new Laravel project with Sail and runs initial setup
EOF
        return 1
    fi

    local project_name="$1"

    if ! validate_path "$project_name"; then
        return 1
    fi

    log "INFO" "Creating new Laravel project: ${project_name}"

    # Create new Laravel project
    if ! safe_exec "curl -s 'https://laravel.build/${project_name}' | bash" "Failed to download/install Laravel"; then
        return 1
    fi

    if ! cd "${project_name}"; then
        log "ERROR" "Failed to change directory to ${project_name}"
        return 1
    fi

    log "INFO" "Starting Sail containers..."
    if ! safe_exec "./vendor/bin/sail up -d" "Failed to start Sail containers"; then
        return 1
    fi

    log "INFO" "Waiting for application to be ready..."
    if ! wait_for_service "http://localhost" 30 2; then
        log "INFO" "💡 Try running 'sail down' and then 'sail up -d' manually"
        return 1
    fi

    log "INFO" "Running migrations..."
    if ! safe_exec "./vendor/bin/sail artisan migrate" "Failed to run migrations"; then
        return 1
    fi

    log "SUCCESS" "Project setup complete!"
    log "INFO" "📂 Project location: $(pwd)"
    cat <<EOF

Useful commands:
  ./vendor/bin/sail up -d    # Start containers in background
  ./vendor/bin/sail down     # Stop containers
  ./vendor/bin/sail artisan  # Run artisan commands
  ./vendor/bin/sail shell    # Start a Bash session within your application's container
EOF
}
