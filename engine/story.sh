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

TARGET="${1:---last}"

sentinel_ensure_directories
touch "${SENTINEL_MAIN_LOG}"

sentinel_require_initialization

list_session_files() {
    if [[ ! -d "${SENTINEL_SESSION_ARCHIVE_DIR}" ]]; then
        return
    fi

    find "${SENTINEL_SESSION_ARCHIVE_DIR}" -maxdepth 1 -type f -name '*.session' | sort
}

find_last_session_file() {
    list_session_files | tail -n 1
}

find_session_file_by_id() {
    local session_id="$1"
    local session_file="${SENTINEL_SESSION_ARCHIVE_DIR}/${session_id}.session"

    if [[ -f "${session_file}" ]]; then
        printf '%s\n' "${session_file}"
    fi
}

count_session_signals() {
    local session_id="$1"
    local signal_type="$2"

    [[ -f "${SENTINEL_MAIN_LOG}" ]] || {
        echo "0"
        return
    }

    awk -F'|' -v sid="${session_id}" -v stype="${signal_type}" '
        $3 == stype && $4 == sid { count++ }
        END { print count + 0 }
    ' "${SENTINEL_MAIN_LOG}"
}

latest_signal_details() {
    local session_id="$1"
    local signal_type="$2"

    [[ -f "${SENTINEL_MAIN_LOG}" ]] || return 0

    awk -F'|' -v sid="${session_id}" -v stype="${signal_type}" '
        $3 == stype && $4 == sid { last = $6 }
        END {
            if (last != "") {
                print last
            }
        }
    ' "${SENTINEL_MAIN_LOG}"
}

recent_session_signals() {
    local session_id="$1"

    [[ -f "${SENTINEL_MAIN_LOG}" ]] || return 0

    awk -F'|' -v sid="${session_id}" '
        $4 == sid && $3 ~ /^signal_/ {
            print $1 "|" $3 "|" $6
        }
    ' "${SENTINEL_MAIN_LOG}" | tail -n 5
}

print_story() {
    local session_file="$1"

    if ! sentinel_load_session_file "${session_file}"; then
        sentinel_error "Could not load session file."
        sentinel_error "File: ${session_file}"
        exit 1
    fi

    local command_count error_count note_count
    local latest_command latest_error latest_note
    local context_display

    command_count="$(count_session_signals "${session_id}" "signal_command")"
    error_count="$(count_session_signals "${session_id}" "signal_error")"
    note_count="$(count_session_signals "${session_id}" "signal_note")"

    latest_command="$(latest_signal_details "${session_id}" "signal_command")"
    latest_error="$(latest_signal_details "${session_id}" "signal_error")"
    latest_note="$(latest_signal_details "${session_id}" "signal_note")"

    if [[ "${context_type:-none}" == "none" || -z "${context_type:-}" ]]; then
        context_display="none"
    else
        context_display="${context_type}: ${context_value:-}"
    fi

    sentinel_section "Sentinel Story"
    echo "Session ID:      ${session_id:-unknown}"
    echo "Mode:            ${session_mode:-unknown}"
    echo "State:           ${session_state:-unknown}"
    echo "Started:         ${start_time:-unknown}"
    echo "Ended:           ${end_time:-}"
    echo "Duration:        ${duration:-}"
    echo "Host:            ${host_name:-unknown}"
    echo "Operator User:   ${operator_user:-unknown}"
    echo "Effective User:  ${effective_user:-unknown}"
    echo "Context:         ${context_display}"
    echo "Context Status:  ${context_status:-unset}"
    echo "Integrity:       ${integrity_status:-unknown}"
    echo
    echo "Signal Summary"
    echo "--------------"
    echo "Commands: ${command_count}"
    echo "Errors:   ${error_count}"
    echo "Notes:    ${note_count}"

    if [[ -n "${latest_command}" || -n "${latest_error}" || -n "${latest_note}" ]]; then
        echo
        echo "Latest Signal Details"
        echo "---------------------"
        [[ -n "${latest_command}" ]] && echo "Latest command: ${latest_command}"
        [[ -n "${latest_error}" ]] && echo "Latest error:   ${latest_error}"
        [[ -n "${latest_note}" ]] && echo "Latest note:    ${latest_note}"
    fi

    local recent_signals
    recent_signals="$(recent_session_signals "${session_id}")"

    if [[ -n "${recent_signals}" ]]; then
        echo
        echo "Recent Signals"
        echo "--------------"
        while IFS='|' read -r timestamp action details; do
            [[ -n "${timestamp}" ]] || continue
            echo "[${timestamp}] ${action} - ${details}"
        done <<< "${recent_signals}"
    fi
}

case "${TARGET}" in
    --last)
        SESSION_FILE="$(find_last_session_file)"
        if [[ -z "${SESSION_FILE:-}" ]]; then
            sentinel_warn "No archived sessions found."
            exit 0
        fi
        print_story "${SESSION_FILE}"
        ;;
    *)
        SESSION_FILE="$(find_session_file_by_id "${TARGET}")"
        if [[ -z "${SESSION_FILE:-}" ]]; then
            sentinel_error "Session not found: ${TARGET}"
            exit 1
        fi
        print_story "${SESSION_FILE}"
        ;;
esac
