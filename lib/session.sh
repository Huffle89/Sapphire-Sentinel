#!/usr/bin/env bash

# ============================================================================
# Sapphire Sentinel
# Defensive session loading helpers
# ============================================================================

sentinel_clear_session_vars() {
    unset session_id session_mode session_state start_time end_time duration
    unset host_name device_id operator_user effective_user
    unset context_type context_value context_status label
    unset recovery_reason integrity_status
}

sentinel_validate_session_file() {
    local session_file="$1"

    [[ -f "$session_file" ]] || return 1
    grep -q '^session_id=' "$session_file" || return 1
    grep -q '^session_mode=' "$session_file" || return 1
    grep -q '^session_state=' "$session_file" || return 1
    grep -q '^start_time=' "$session_file" || return 1

    return 0
}

sentinel_load_session_file() {
    local session_file="$1"

    sentinel_clear_session_vars

    if ! sentinel_validate_session_file "$session_file"; then
        return 1
    fi

    # shellcheck disable=SC1090
    if ! source "$session_file"; then
        sentinel_clear_session_vars
        return 1
    fi

    return 0
}
