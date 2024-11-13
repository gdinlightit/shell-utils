#!/bin/bash

# shellcheck disable=SC2120
_wait_for() {
    local url="${1:-http://localhost}"
    local max_attempts="${2:-30}"
    local attempt=1

    echo "⏳ Waiting for ${url} to become available..."

    while ! curl -s "${url}" >/dev/null; do
        if [ "${attempt}" -eq "${max_attempts}" ]; then
            echo "❌ Service failed to start after ${max_attempts} attempts"
            echo "💡 Try running 'sail down' and then 'sail up -d' manually"
            return 1
        fi
        echo "⏳ Attempt ${attempt}/${max_attempts}: Service not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done

    echo "✅ Service is available!"
}

sail-init() {
    # Check if project name was provided
    if [ -z "$1" ]; then
        echo "Usage: sail-init <project-name>"
        echo "Sets up a new Laravel project with Sail and runs initial setup"
        return 1
    fi

    local project_name="$1"

    echo "🚀 Creating new Laravel project: ${project_name}"

    # Create new Laravel project
    if ! curl -s "https://laravel.build/${project_name}" | bash; then
        echo "❌ Failed to download/install Laravel"
        return 1
    fi

    cd "${project_name}" || return 1

    echo "⚡ Starting Sail containers..."
    ./vendor/bin/sail up -d

    echo "⏳ Waiting for application to be ready..."
    if ! _wait_for; then
        return 1
    fi
    echo "✅ Application is up and running!"

    echo "🔄 Running migrations..."
    ./vendor/bin/sail artisan migrate

    echo "✅ Project setup complete!"
    echo "📂 Project location: $(pwd)"
    echo ""
    echo "Useful commands:"
    echo "  ./vendor/bin/sail up -d    # Start containers in background"
    echo "  ./vendor/bin/sail down     # Stop containers"
    echo "  ./vendor/bin/sail artisan  # Run artisan commands"
}
