#!/bin/bash

aws-ssm-tunnel() {
    setup_logging "aws-ssm-tunnel"

    local project="${1:?Usage: aws-ssm-tunnel <project>}"

    load-env ".env.${project}"

    local local_port="${TUNNEL_LOCAL_PORT:?TUNNEL_LOCAL_PORT is not set}"
    local profile="${TUNNEL_AWS_PROFILE:?TUNNEL_AWS_PROFILE is not set}"
    local target="${TUNNEL_INSTANCE_ID:?TUNNEL_INSTANCE_ID is not set}"
    local host="${TUNNEL_DB_HOST:?TUNNEL_DB_HOST is not set}"
    local remote_port="${TUNNEL_DB_PORT:?TUNNEL_DB_PORT is not set}"
    local region="${TUNNEL_AWS_REGION:?TUNNEL_AWS_REGION is not set}"

    log "INFO" "Logging into AWS SSO (profile: ${profile})..."
    if ! aws sso login --profile "$profile"; then
        log "ERROR" "AWS SSO login failed"
        return 1
    fi

    log "INFO" "Opening SSM tunnel: localhost:${local_port} -> ${host}:${remote_port}"
    aws ssm start-session \
        --target "$target" \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters "{\"host\":[\"${host}\"],\"portNumber\":[\"${remote_port}\"],\"localPortNumber\":[\"${local_port}\"]}" \
        --profile "$profile" \
        --region "$region"
}

_AWS_SSM_TUNNEL_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/.."

_aws_ssm_tunnel_complete() {
    local env_dir="${_AWS_SSM_TUNNEL_ENV_DIR}"
    local projects=()
    for f in "${env_dir}"/.env.*; do
        [[ -f "$f" ]] && projects+=("$(basename "$f" | sed 's/^\.env\.//')")
    done

    if is_bash; then
        local cur="${COMP_WORDS[COMP_CWORD]}"
        mapfile -t COMPREPLY < <(compgen -W "${projects[*]}" -- "$cur")
    elif is_zsh; then
        _describe 'projects' projects
    fi
}

setup_completion "aws-ssm-tunnel" "_aws_ssm_tunnel_complete"
