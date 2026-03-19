#!/usr/bin/env bash

set -u

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${ENGINE_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/paths.sh"
source "${PROJECT_ROOT}/lib/output.sh"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/session.sh"
source "${PROJECT_ROOT}/lib/time.sh"

sentinel_ensure_directories
touch "${SENTINEL_MAIN_LOG}"

if [[ ! -f "${SENTINEL_ACTIVE_SESSION_FILE}" ]]; then
    sentinel_warn "No active Sentinel session to stop."

    sentinel_log_event \
        "system" \
        "session_stop" \
        "active_session" \
        "noop" \
        "stop requested with no active session"

    exit 0
fi

if ! sentinel_load_session_file "${SENTINEL_ACTIVE_SESSION_FILE}"; then
    sentinel_error "Active session file is malformed or unreadable."
    sentinel_error "File: ${SENTINEL_ACTIVE_SESSION_FILE}"
    exit 1
fi

END_TIME="$(sentinel_timestamp)"
START_EPOCH="$(sentinel_to_epoch "${start_time}")"
END_EPOCH="$(sentinel_to_epoch "${END_TIME}")"

if [[ "${START_EPOCH}" -gt 0 && "${END_EPOCH}" -ge "${START_EPOCH}" ]]; then
    DURATION_SECONDS=$((END_EPOCH - START_EPOCH))
else
    DURATION_SECONDS=0
fi

DURATION="$(sentinel_format_duration "${DURATION_SECONDS}")"

session_state="closed"
end_time="${END_TIME}"
duration="${DURATION}"

SESSION_ARCHIVE_FILE="${SENTINEL_SESSION_ARCHIVE_DIR}/${session_id}.session"

cat > "${SESSION_ARCHIVE_FILE}" <<SESSION
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

rm -f "${SENTINEL_RUNTIME_DIR}/${session_id}.session"
rm -f "${SENTINEL_ACTIVE_SESSION_FILE}"

sentinel_log_event \
    "${session_mode}" \
    "session_stop" \
    "${session_id}" \
    "success" \
    "session stopped by ${effective_user}; duration=${duration}"

sentinel_info "Stopped Sentinel session."
sentinel_info "Session ID: ${session_id}"
sentinel_info "Duration: ${duration}"
sentinel_info "Archived session: ${SESSION_ARCHIVE_FILE}"
