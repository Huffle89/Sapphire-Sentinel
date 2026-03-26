#!/usr/bin/env bash

set -u

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${ENGINE_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/paths.sh"
source "${PROJECT_ROOT}/lib/output.sh"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/session.sh"
source "${PROJECT_ROOT}/lib/history.sh"
source "${PROJECT_ROOT}/lib/detection.sh"

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

sentinel_ensure_directories
touch "${SENTINEL_MAIN_LOG}"

require_initialization

if [[ -f "${SENTINEL_ACTIVE_SESSION_FILE}" ]]; then
    sentinel_warn "A Sentinel session is already active."
    echo "State file: ${SENTINEL_ACTIVE_SESSION_FILE}"
    exit 1
fi

SESSION_MODE="${1:-development}"
shift || true

CONTEXT_TYPE="none"
CONTEXT_VALUE=""
CONTEXT_STATUS="set"
LABEL=""
RECOVERY_REASON=""
INTEGRITY_STATUS="normal"

if [[ $# -ge 1 ]]; then
    case "$1" in
        project|ticket|label|none)
            CONTEXT_TYPE="$1"
            shift || true

            if [[ "${CONTEXT_TYPE}" == "none" ]]; then
                CONTEXT_VALUE=""
            else
                CONTEXT_VALUE="${1:-}"
                shift || true
            fi
            ;;
    esac
fi

SESSION_ID="$(date '+%Y%m%d%H%M%S')"
START_TIME="$(sentinel_timestamp)"
HOST_NAME="$(hostname)"
DEVICE_ID="$(hostname)"
OPERATOR_USER="${USER:-unknown}"
EFFECTIVE_USER="${USER:-unknown}"

cat > "${SENTINEL_ACTIVE_SESSION_FILE}" <<SESSION
session_id=$(printf '%q' "${SESSION_ID}")
session_mode=$(printf '%q' "${SESSION_MODE}")
session_state=$(printf '%q' "active")
start_time=$(printf '%q' "${START_TIME}")
end_time=$(printf '%q' "")
duration=$(printf '%q' "")
host_name=$(printf '%q' "${HOST_NAME}")
device_id=$(printf '%q' "${DEVICE_ID}")
operator_user=$(printf '%q' "${OPERATOR_USER}")
effective_user=$(printf '%q' "${EFFECTIVE_USER}")
context_type=$(printf '%q' "${CONTEXT_TYPE}")
context_value=$(printf '%q' "${CONTEXT_VALUE}")
context_status=$(printf '%q' "${CONTEXT_STATUS}")
label=$(printf '%q' "${LABEL}")
recovery_reason=$(printf '%q' "${RECOVERY_REASON}")
integrity_status=$(printf '%q' "${INTEGRITY_STATUS}")
SESSION

sentinel_log_event "session" "start" "${SESSION_ID}" "active" \
    "mode=${SESSION_MODE};context_type=${CONTEXT_TYPE};context_value=${CONTEXT_VALUE}"

sentinel_info "Started new Sentinel session."
echo "Session ID: ${SESSION_ID}"
echo "Mode: ${SESSION_MODE}"
echo "Context Type: ${CONTEXT_TYPE}"
echo "Context Value: ${CONTEXT_VALUE}"
echo "State file: ${SENTINEL_ACTIVE_SESSION_FILE}"
