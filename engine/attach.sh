#!/usr/bin/env bash

set -u

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${ENGINE_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/paths.sh"
source "${PROJECT_ROOT}/lib/output.sh"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/session.sh"
source "${PROJECT_ROOT}/lib/history.sh"

CONTEXT_TYPE="${1:-}"
CONTEXT_VALUE="${2:-}"

if [[ ! -f "${SENTINEL_ACTIVE_SESSION_FILE}" ]]; then
    sentinel_error "No active session to attach context to."
    exit 1
fi

if ! sentinel_load_session_file "${SENTINEL_ACTIVE_SESSION_FILE}"; then
    sentinel_error "Active session file unreadable."
    exit 1
fi

case "${CONTEXT_TYPE}" in
    project|ticket|label)
        ;;
    *)
        sentinel_error "Invalid context type."
        sentinel_error "Allowed: project, ticket, label"
        exit 1
        ;;
esac

if [[ -z "${CONTEXT_VALUE}" ]]; then
    sentinel_error "Context value required."
    exit 1
fi

PREVIOUS_CONTEXT="none"
if [[ -n "${context_value:-}" && "${context_type:-none}" != "none" ]]; then
    PREVIOUS_CONTEXT="${context_type}:${context_value}"
fi

context_type="${CONTEXT_TYPE}"
context_value="${CONTEXT_VALUE}"
context_status="set"

cat > "${SENTINEL_ACTIVE_SESSION_FILE}" <<SESSION
session_id=$(printf '%q' "${session_id}")
session_mode=$(printf '%q' "${session_mode}")
session_state=$(printf '%q' "${session_state}")
start_time=$(printf '%q' "${start_time}")
end_time=$(printf '%q' "${end_time}")
duration=$(printf '%q' "${duration}")
host_name=$(printf '%q' "${host_name}")
device_id=$(printf '%q' "${device_id}")
operator_user=$(printf '%q' "${operator_user}")
effective_user=$(printf '%q' "${effective_user}")
context_type=$(printf '%q' "${context_type}")
context_value=$(printf '%q' "${context_value}")
context_status=$(printf '%q' "${context_status}")
label=$(printf '%q' "${label}")
recovery_reason=$(printf '%q' "${recovery_reason}")
integrity_status=$(printf '%q' "${integrity_status}")
SESSION

sentinel_append_history \
    "${SENTINEL_ACTIVE_HISTORY_FILE}" \
    "$(sentinel_timestamp)" \
    "context_attach" \
    "${PREVIOUS_CONTEXT}->${context_type}:${context_value}"

sentinel_log_event \
    "${session_mode}" \
    "context_attach" \
    "${session_id}" \
    "success" \
    "context=${context_type}:${context_value}"

sentinel_info "Context attached to active session."
sentinel_info "Type: ${context_type}"
sentinel_info "Value: ${context_value}"
