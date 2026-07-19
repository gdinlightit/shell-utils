#!/bin/bash

cf-tunnel() {
    setup_logging "cf-tunnel"

    local project="${1:?Usage: cf-tunnel <project>}"

    load-env ".env.${project}"

    local hostname="${CF_TUNNEL_HOSTNAME:?CF_TUNNEL_HOSTNAME is not set}"
    local local_port="${CF_TUNNEL_LOCAL_PORT:?CF_TUNNEL_LOCAL_PORT is not set}"
    local keychain_id="${CF_TUNNEL_KEYCHAIN_ID:?CF_TUNNEL_KEYCHAIN_ID is not set}"
    local keychain_secret="${CF_TUNNEL_KEYCHAIN_SECRET:?CF_TUNNEL_KEYCHAIN_SECRET is not set}"

    local token_id token_secret
    if ! token_id="$(get-secret "$keychain_id")"; then
        log "ERROR" "Could not resolve service token ID (name: ${keychain_id})"
        return 1
    fi

    if ! token_secret="$(get-secret "$keychain_secret")"; then
        log "ERROR" "Could not resolve service token secret (name: ${keychain_secret})"
        return 1
    fi

    log "INFO" "Opening Cloudflare tunnel: localhost:${local_port} -> ${hostname}"
    cloudflared access tcp \
        --hostname "$hostname" \
        --url "localhost:${local_port}" \
        --service-token-id "$token_id" \
        --service-token-secret "$token_secret"
}

_CF_TUNNEL_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/.."

_cf_tunnel_complete() {
    local env_dir="${_CF_TUNNEL_ENV_DIR}"
    local projects=()
    for f in "${env_dir}"/.env.*; do
        [[ -f "$f" ]] || continue
        local name="$(basename "$f" | sed 's/^\.env\.//')"
        # Only suggest projects that have CF_TUNNEL_HOSTNAME
        grep -q "CF_TUNNEL_HOSTNAME" "$f" 2>/dev/null && projects+=("$name")
    done

    if is_bash; then
        local cur="${COMP_WORDS[COMP_CWORD]}"
        mapfile -t COMPREPLY < <(compgen -W "${projects[*]}" -- "$cur")
    elif is_zsh; then
        _describe 'projects' projects
    fi
}

setup_completion "cf-tunnel" "_cf_tunnel_complete"
