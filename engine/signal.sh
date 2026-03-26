#!/usr/bin/env bash

set -u

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${ENGINE_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/paths.sh"
source "${PROJECT_ROOT}/lib/output.sh"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/session.sh"

if [[ -f "${PROJECT_ROOT}/lib/config.sh" ]]; then
    # shellcheck source=../lib/config.sh
    source "${PROJECT_ROOT}/lib/config.sh"
fi

SIGNAL_TYPE="${1:-}"
shift || true
SIGNAL_DETAILS="${*:-}"

sentinel_ensure_directories
touch "${SENTINEL_MAIN_LOG}"

sentinel_require_initialization

case "${SIGNAL_TYPE}" in
    command|error|note)
        ;;
    *)
        sentinel_error "Invalid signal type."
        echo "Usage: sentinel signal [command|error|note] [details]"
        exit 1
        ;;
esac

SESSION_TARGET="no_active_session"
SESSION_MODE="system"
DETAILS="${SIGNAL_DETAILS}"

if [[ -f "${SENTINEL_ACTIVE_SESSION_FILE}" ]]; then
    if sentinel_load_session_file "${SENTINEL_ACTIVE_SESSION_FILE}"; then
        SESSION_TARGET="${session_id}"
        SESSION_MODE="${session_mode}"

        if [[ -n "${context_type:-}" && "${context_type}" != "none" ]]; then
            DETAILS="context_type=${context_type};context_value=${context_value};${SIGNAL_DETAILS}"
        fi
    fi
fi

sentinel_log_event \
    "${SESSION_MODE}" \
    "signal_${SIGNAL_TYPE}" \
    "${SESSION_TARGET}" \
    "success" \
    "${DETAILS}"

sentinel_info "Recorded ${SIGNAL_TYPE} signal."
echo "Target: ${SESSION_TARGET}"
echo "Mode: ${SESSION_MODE}"
