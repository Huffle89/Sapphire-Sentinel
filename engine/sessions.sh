#!/usr/bin/env bash

set -u

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${ENGINE_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/paths.sh"
source "${PROJECT_ROOT}/lib/output.sh"
if [[ -f "${PROJECT_ROOT}/lib/config.sh" ]]; then
    # shellcheck source=../lib/config.sh
    source "${PROJECT_ROOT}/lib/config.sh"
fi


source "${PROJECT_ROOT}/lib/session.sh"

OPTION="${1:---last}"

sentinel_ensure_directories
touch "${SENTINEL_MAIN_LOG}"

sentinel_require_initialization

list_session_files() {
    if [[ ! -d "${SENTINEL_SESSION_ARCHIVE_DIR}" ]]; then
        return
    fi

    find "${SENTINEL_SESSION_ARCHIVE_DIR}" -maxdepth 1 -type f -name '*.session' | sort -r
}

count_session_signals() {
    local session_id="$1"
    local signal_type="$2"
    local log_file="${SENTINEL_MAIN_LOG}"

    [[ -f "${log_file}" ]] || {
        echo "0"
        return
    }

    awk -F'|' -v sid="${session_id}" -v stype="${signal_type}" '
        $3 == stype && $4 == sid { count++ }
        END { print count + 0 }
    ' "${log_file}"
}

show_session_summary() {
    local session_file="$1"

    if ! sentinel_load_session_file "${session_file}"; then
        return
    fi

    local command_count
    local error_count
    local note_count

    command_count="$(count_session_signals "${session_id}" "signal_command")"
    error_count="$(count_session_signals "${session_id}" "signal_error")"
    note_count="$(count_session_signals "${session_id}" "signal_note")"

    echo "Session ID: ${session_id}"
    echo "Mode: ${session_mode}"
    echo "State: ${session_state}"
    echo "Started: ${start_time}"
    echo "Ended: ${end_time:-}"
    echo "Duration: ${duration:-}"
    echo "Context: ${context_type:-none} ${context_value:-}"
    echo "Signals: commands=${command_count}, errors=${error_count}, notes=${note_count}"
}

show_last_session() {
    local last_session
    last_session="$(list_session_files | head -n 1)"

    if [[ -z "${last_session}" ]]; then
        sentinel_warn "No archived sessions found."
        exit 0
    fi

    sentinel_section "Most Recent Sentinel Session"
    show_session_summary "${last_session}"
}

show_today_sessions() {
    local today
    local found=0

    today="$(date '+%Y-%m-%d')"

    sentinel_section "Today's Sentinel Sessions"

    while IFS= read -r session_file; do
        [[ -n "${session_file}" ]] || continue

        if ! sentinel_load_session_file "${session_file}"; then
            continue
        fi

        if [[ "${start_time:-}" == "${today}"* ]]; then
            found=1
            echo
            show_session_summary "${session_file}"
        fi
    done < <(list_session_files)

    if [[ "${found}" -eq 0 ]]; then
        sentinel_warn "No archived sessions found for today."
    fi
}

case "${OPTION}" in
    --last)
        show_last_session
        ;;
    --today)
        show_today_sessions
        ;;
    *)
        sentinel_error "Invalid option: ${OPTION}"
        echo "Usage: sentinel sessions [--last|--today]"
        exit 1
        ;;
esac
