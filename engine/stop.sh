#!/usr/bin/env bash

set -u

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${ENGINE_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/paths.sh"
source "${PROJECT_ROOT}/lib/output.sh"
source "${PROJECT_ROOT}/lib/logging.sh"
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

SESSION_ID="${session_id:-unknown}"
START_TIME="${start_time:-}"
END_TIME="$(sentinel_timestamp)"
DURATION_DISPLAY="unknown"
DURATION_SECONDS=""

if [[ -n "${START_TIME}" ]]; then
    START_EPOCH="$(sentinel_to_epoch "${START_TIME}")"
    END_EPOCH="$(sentinel_to_epoch "${END_TIME}")"

    if [[ "${START_EPOCH}" -gt 0 && "${END_EPOCH}" -ge "${START_EPOCH}" ]]; then
        DURATION_SECONDS=$((END_EPOCH - START_EPOCH))
        DURATION_DISPLAY="$(sentinel_format_duration "${DURATION_SECONDS}")"
    fi
fi

ARCHIVE_DIR="${SENTINEL_SESSION_ARCHIVE_DIR}"
ARCHIVE_FILE="${ARCHIVE_DIR}/${SESSION_ID}.session"
TRANSCRIPT_FILE="${SENTINEL_LOG_DIR}/transcripts/${SESSION_ID}.journal"

mkdir -p "${ARCHIVE_DIR}"

cat > "${ARCHIVE_FILE}" <<SESSION
session_id=$(printf '%q' "${session_id:-}")
session_mode=$(printf '%q' "${session_mode:-}")
session_state=$(printf '%q' "stopped")
start_time=$(printf '%q' "${start_time:-}")
end_time=$(printf '%q' "${END_TIME}")
duration=$(printf '%q' "${DURATION_SECONDS}")
host_name=$(printf '%q' "${host_name:-}")
device_id=$(printf '%q' "${device_id:-}")
operator_user=$(printf '%q' "${operator_user:-}")
effective_user=$(printf '%q' "${effective_user:-}")
context_type=$(printf '%q' "${context_type:-}")
context_value=$(printf '%q' "${context_value:-}")
context_status=$(printf '%q' "${context_status:-}")
label=$(printf '%q' "${label:-}")
recovery_reason=$(printf '%q' "${recovery_reason:-}")
integrity_status=$(printf '%q' "${integrity_status:-}")
SESSION

sentinel_log_event "session" "stop" "${SESSION_ID}" "stopped" \
    "duration=${DURATION_SECONDS};end_time=${END_TIME}"

if [[ -f "${TRANSCRIPT_FILE}" ]]; then
    {
        printf 'Ended: %s\n' "${END_TIME}"
        printf 'Duration: %s\n' "${DURATION_DISPLAY}"
        printf '========================================\n'
    } >> "${TRANSCRIPT_FILE}"
fi

rm -f "${SENTINEL_ACTIVE_SESSION_FILE}"

sentinel_info "Stopped Sentinel session."
echo "Session ID: ${SESSION_ID}"
echo "Duration: ${DURATION_DISPLAY}"
echo "Archived session: ${ARCHIVE_FILE}"
if [[ -f "${TRANSCRIPT_FILE}" ]]; then
    echo "Transcript: ${TRANSCRIPT_FILE}"
fi
