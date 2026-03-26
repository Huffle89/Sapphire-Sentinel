#!/usr/bin/env bash

set -u

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${ENGINE_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/paths.sh"
source "${PROJECT_ROOT}/lib/output.sh"
source "${PROJECT_ROOT}/lib/session.sh"
source "${PROJECT_ROOT}/lib/time.sh"

if [[ -f "${PROJECT_ROOT}/lib/config.sh" ]]; then
    # shellcheck source=../lib/config.sh
    source "${PROJECT_ROOT}/lib/config.sh"
fi


sentinel_require_initialization

if [[ ! -f "${SENTINEL_ACTIVE_SESSION_FILE}" ]]; then
    sentinel_warn "No active Sentinel session."
    exit 0
fi

if ! sentinel_load_session_file "${SENTINEL_ACTIVE_SESSION_FILE}"; then
    sentinel_error "Active session file is malformed or unreadable."
    sentinel_error "File: ${SENTINEL_ACTIVE_SESSION_FILE}"
    exit 1
fi

ELAPSED_DISPLAY="unknown"

if [[ -n "${start_time:-}" ]]; then
    START_EPOCH="$(sentinel_to_epoch "${start_time}")"
    NOW_EPOCH="$(sentinel_epoch)"

    if [[ "${START_EPOCH}" -gt 0 && "${NOW_EPOCH}" -ge "${START_EPOCH}" ]]; then
        ELAPSED_SECONDS=$((NOW_EPOCH - START_EPOCH))
        ELAPSED_DISPLAY="$(sentinel_format_duration "${ELAPSED_SECONDS}")"
    fi
fi

sentinel_section "Active Sentinel Session"

echo "Session ID: ${session_id:-unknown}"
echo "Mode: ${session_mode:-unknown}"
echo "State: ${session_state:-unknown}"
echo "Started: ${start_time:-unknown}"
echo "Elapsed: ${ELAPSED_DISPLAY}"
echo "Host: ${host_name:-unknown}"
echo "Device ID: ${device_id:-unknown}"
echo "Operator User: ${operator_user:-unknown}"
echo "Effective User: ${effective_user:-unknown}"
echo "Context Type: ${context_type:-none}"
echo "Context Value: ${context_value:-}"
echo "Context Status: ${context_status:-unset}"
echo "Label: ${label:-}"
echo "Recovery Reason: ${recovery_reason:-}"
echo "Integrity: ${integrity_status:-unknown}"
