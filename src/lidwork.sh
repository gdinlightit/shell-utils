#!/bin/bash

_LIDWORK_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/lidwork"
_LIDWORK_GUARD_PID_FILE="$_LIDWORK_STATE_DIR/guard.pid"
_LIDWORK_DEADLINE_FILE="$_LIDWORK_STATE_DIR/guard.deadline"
_LIDWORK_GUARD_LOG_FILE="$_LIDWORK_STATE_DIR/guard.log"
_LIDWORK_DEFAULT_HOURS=10

_lidwork_init_state_dir() {
    mkdir -p "$_LIDWORK_STATE_DIR" && chmod 700 "$_LIDWORK_STATE_DIR"
}

# Echoes the file's content only when it is a plain unsigned integer, so values
# read back from disk can never reach arithmetic expansion or `kill` as code.
_lidwork_read_number() {
    local value
    [[ -f "$1" && ! -L "$1" ]] || return 1
    value="$(<"$1")"
    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    echo "$value"
}

_lidwork_guard_pid() {
    local pid
    pid="$(_lidwork_read_number "$_LIDWORK_GUARD_PID_FILE")" || return 1
    ps -o command= -p "$pid" 2>/dev/null | grep -q "pmset -b disablesleep 0" || return 1
    echo "$pid"
}

_lidwork_kill_guard() {
    local pid
    if pid="$(_lidwork_guard_pid)"; then
        kill "$pid" 2>/dev/null
    fi
    rm -f "$_LIDWORK_GUARD_PID_FILE" "$_LIDWORK_DEADLINE_FILE"
}

lidwork() {
    setup_logging "lidwork"

    case "$1" in
        on)
            local hours="${2:-$_LIDWORK_DEFAULT_HOURS}"
            if [[ ! "$hours" =~ ^[0-9]+$ ]]; then
                echo "hours must be a positive integer"
                return 1
            fi
            local secs=$((hours * 3600))

            _lidwork_init_state_dir || return 1
            _lidwork_kill_guard
            sudo pmset -b disablesleep 1

            nohup bash -c "sleep ${secs}; sudo pmset -b disablesleep 0; rm -f '${_LIDWORK_GUARD_PID_FILE}' '${_LIDWORK_DEADLINE_FILE}'" \
                >"$_LIDWORK_GUARD_LOG_FILE" 2>&1 &
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
            if _lidwork_guard_pid >/dev/null; then
                local remaining="" deadline left
                if deadline="$(_lidwork_read_number "$_LIDWORK_DEADLINE_FILE")"; then
                    left=$(( deadline - $(date +%s) ))
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
