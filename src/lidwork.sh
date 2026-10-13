#!/bin/bash

_LIDWORK_GUARD_PID_FILE="/tmp/.lidwork-guard.pid"
_LIDWORK_DEADLINE_FILE="/tmp/.lidwork-guard.deadline"
_LIDWORK_DEFAULT_HOURS=10

_lidwork_kill_guard() {
    if [[ -f "$_LIDWORK_GUARD_PID_FILE" ]]; then
        local pid
        pid="$(cat "$_LIDWORK_GUARD_PID_FILE")"
        kill "$pid" 2>/dev/null
        rm -f "$_LIDWORK_GUARD_PID_FILE"
    fi
    rm -f "$_LIDWORK_DEADLINE_FILE"
}

lidwork() {
    setup_logging "lidwork"

    case "$1" in
        on)
            local hours="${2:-$_LIDWORK_DEFAULT_HOURS}"
            local secs=$((hours * 3600))

            _lidwork_kill_guard
            sudo pmset -b disablesleep 1

            nohup bash -c "sleep ${secs}; sudo pmset -b disablesleep 0; rm -f ${_LIDWORK_GUARD_PID_FILE} ${_LIDWORK_DEADLINE_FILE}" \
                >/tmp/.lidwork-guard.log 2>&1 &
            disown
            echo $! > "$_LIDWORK_GUARD_PID_FILE"
            echo $(( $(date +%s) + secs )) > "$_LIDWORK_DEADLINE_FILE"

            log "INFO" "Lid-close sleep disabled on battery. Auto re-enables in ${hours}h unless you run 'lidwork off' first."
            ;;
        off)
            _lidwork_kill_guard
            sudo pmset -b disablesleep 0
            log "INFO" "Lid-close sleep re-enabled."
            ;;
        status)
            # `disablesleep` is write-only: it never appears in any `pmset -g` output
            # on modern macOS, so the guard PID file is the only ground truth we have.
            if [[ -f "$_LIDWORK_GUARD_PID_FILE" ]] && kill -0 "$(cat "$_LIDWORK_GUARD_PID_FILE")" 2>/dev/null; then
                local remaining=""
                if [[ -f "$_LIDWORK_DEADLINE_FILE" ]]; then
                    local left=$(( $(cat "$_LIDWORK_DEADLINE_FILE") - $(date +%s) ))
                    (( left < 0 )) && left=0
                    remaining=" ($((left / 3600))h $((left % 3600 / 60))m left)"
                fi
                log "INFO" "lidwork is ON — lid-close sleep disabled on battery. Guard armed, will auto re-enable${remaining}."
            else
                log "INFO" "lidwork is OFF — lid-close sleep behaves normally."
            fi
            ;;
        *)
            echo "Usage: lidwork on [hours=${_LIDWORK_DEFAULT_HOURS}] | off | status"
            return 1
            ;;
    esac
}
