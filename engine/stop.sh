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

CONFIG_DIR="${HOME}/.config/sapphire-sentinel"
CONFIG_FILE="${CONFIG_DIR}/config"

config_initialized() {
    [[ -f "${CONFIG_FILE}" ]] || return 1
    grep -Eq '^initialized="?true"?$' "${CONFIG_FILE}" 2>/dev/null
}

require_initialization() {
    if config_initialized; then
        return 0
    fi

    sentinel_warn "Sapphire Sentinel has not been initialized yet."
    echo "Run: sentinel init"
    exit 1
}

require_initialization

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

rm -f "${SENTINEL_ACTIVE_SESSION_FILE}"

sentinel_info "Stopped Sentinel session."
echo "Session ID: ${SESSION_ID}"
echo "Duration: ${DURATION_DISPLAY}"
echo "Archived session: ${ARCHIVE_FILE}"
