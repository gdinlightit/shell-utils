#!/bin/bash

cf-tunnel() {
    setup_logging "cf-tunnel"

    local project="${1:?Usage: cf-tunnel <project>}"
    local item="cf-tunnel-${project}"

    local hostname local_port
    if ! hostname="$(op read "op://Private/${item}/hostname" 2>/dev/null)" || [[ -z "$hostname" ]]; then
        log "ERROR" "Could not resolve hostname (op://Private/${item}/hostname)"
        return 1
    fi

    if ! local_port="$(op read "op://Private/${item}/local_port" 2>/dev/null)" || [[ -z "$local_port" ]]; then
        log "ERROR" "Could not resolve local port (op://Private/${item}/local_port)"
        return 1
    fi

    local token_id token_secret
    if ! token_id="$(get-secret "${item}-id")"; then
        log "ERROR" "Could not resolve service token ID (name: ${item}-id)"
        return 1
    fi

    if ! token_secret="$(get-secret "${item}-secret")"; then
        log "ERROR" "Could not resolve service token secret (name: ${item}-secret)"
        return 1
    fi

    log "INFO" "Opening Cloudflare tunnel: localhost:${local_port} -> ${hostname}"
    cloudflared access tcp \
        --hostname "$hostname" \
        --url "localhost:${local_port}" \
        --service-token-id "$token_id" \
        --service-token-secret "$token_secret"
}
