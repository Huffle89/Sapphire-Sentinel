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

sentinel_ensure_directories
touch "${SENTINEL_MAIN_LOG}"

sentinel_require_initialization

SESSION_MODE=""
CONTEXT_TYPE="none"
CONTEXT_VALUE=""
CONTEXT_STATUS="set"
LABEL=""
RECOVERY_REASON=""
INTEGRITY_STATUS="normal"

print_header() {
    echo "========================================"
    echo "      Sapphire Sentinel Personal"
    echo "========================================"
    echo
}

pause_continue() {
    read -r -p "Press Enter to continue..."
}

start_session_now() {
    local session_id start_time host_name device_id operator_user effective_user

    session_id="$(date '+%Y%m%d%H%M%S')"
    start_time="$(sentinel_timestamp)"
    host_name="$(hostname)"
    device_id="$(hostname)"
    operator_user="${USER:-unknown}"
    effective_user="${USER:-unknown}"

    cat > "${SENTINEL_ACTIVE_SESSION_FILE}" <<SESSION
session_id=$(printf '%q' "${session_id}")
session_mode=$(printf '%q' "${SESSION_MODE}")
session_state=$(printf '%q' "active")
start_time=$(printf '%q' "${start_time}")
end_time=$(printf '%q' "")
duration=$(printf '%q' "")
host_name=$(printf '%q' "${host_name}")
device_id=$(printf '%q' "${device_id}")
operator_user=$(printf '%q' "${operator_user}")
effective_user=$(printf '%q' "${effective_user}")
context_type=$(printf '%q' "${CONTEXT_TYPE}")
context_value=$(printf '%q' "${CONTEXT_VALUE}")
context_status=$(printf '%q' "${CONTEXT_STATUS}")
label=$(printf '%q' "${LABEL}")
recovery_reason=$(printf '%q' "${RECOVERY_REASON}")
integrity_status=$(printf '%q' "${INTEGRITY_STATUS}")
SESSION

    sentinel_log_event "session" "start" "${session_id}" "active" \
        "mode=${SESSION_MODE};context_type=${CONTEXT_TYPE};context_value=${CONTEXT_VALUE};label=${LABEL}"

    sentinel_info "Started new Sentinel session."
    echo "Session ID: ${session_id}"
    echo "Mode: ${SESSION_MODE}"
    echo "Context Type: ${CONTEXT_TYPE}"
    echo "Context Value: ${CONTEXT_VALUE}"
    echo "Label: ${LABEL}"
    echo "State file: ${SENTINEL_ACTIVE_SESSION_FILE}"
}

run_noninteractive_start() {
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
            project|ticket|classwork|label|none)
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

    if [[ -f "${SENTINEL_ACTIVE_SESSION_FILE}" ]]; then
        sentinel_warn "A Sentinel session is already active."
        echo "State file: ${SENTINEL_ACTIVE_SESSION_FILE}"
        exit 1
    fi

    start_session_now
}

choose_log_or_skip() {
    local choice=""

    while true; do
        print_header
        cat <<'TEXT'
Choose what you want to do:

1) Start logged session
   Begin a Personal Sentinel work session now

2) Skip logging this shell
   Do not start a Sentinel session right now

x) Exit
TEXT
        echo
        read -r -p "Select an option: " choice

        case "${choice}" in
            1) return 0 ;;
            2)
                echo
                echo "Logging skipped for this shell."
                exit 0
                ;;
            x|X)
                echo
                echo "Start cancelled."
                exit 0
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

choose_mode() {
    local choice=""

    while true; do
        print_header
        cat <<'TEXT'
Choose session mode:

1) Development
   Building, writing, or creating something

2) Maintenance
   Updates, installs, cleanup, routine system work

3) Troubleshooting
   Fixing a problem or something not working

4) Investigation
   Learning, exploring, testing, or researching

5) Unclear
   Not sure yet

Tip: For school or labs, choose the mode that best matches the work,
then select "Classwork" as the context in the next step.

x) Exit
TEXT
        echo
        read -r -p "Select session mode: " choice

        case "${choice}" in
            1) SESSION_MODE="development"; return 0 ;;
            2) SESSION_MODE="maintenance"; return 0 ;;
            3) SESSION_MODE="troubleshooting"; return 0 ;;
            4) SESSION_MODE="investigation"; return 0 ;;
            5) SESSION_MODE="unclear"; return 0 ;;
            x|X)
                echo
                echo "Start cancelled."
                exit 0
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

choose_context() {
    local choice=""

    while true; do
        print_header
        cat <<'TEXT'
Choose work context:

1) Project
2) Ticket
3) Classwork
4) Label
5) None
x) Exit
TEXT
        echo
        read -r -p "Select context type: " choice

        case "${choice}" in
            1)
                CONTEXT_TYPE="project"
                read -r -p "Enter project name: " CONTEXT_VALUE
                if [[ -n "${CONTEXT_VALUE}" ]]; then
                    return 0
                fi
                echo
                echo "Project name cannot be empty."
                pause_continue
                ;;
            2)
                CONTEXT_TYPE="ticket"
                read -r -p "Enter ticket value: " CONTEXT_VALUE
                if [[ -n "${CONTEXT_VALUE}" ]]; then
                    return 0
                fi
                echo
                echo "Ticket value cannot be empty."
                pause_continue
                ;;
            3)
                CONTEXT_TYPE="classwork"
                read -r -p "Enter classwork value: " CONTEXT_VALUE
                if [[ -n "${CONTEXT_VALUE}" ]]; then
                    return 0
                fi
                echo
                echo "Classwork value cannot be empty."
                pause_continue
                ;;
            4)
                CONTEXT_TYPE="label"
                read -r -p "Enter label value: " CONTEXT_VALUE
                if [[ -n "${CONTEXT_VALUE}" ]]; then
                    return 0
                fi
                echo
                echo "Label value cannot be empty."
                pause_continue
                ;;
            5)
                CONTEXT_TYPE="none"
                CONTEXT_VALUE=""
                return 0
                ;;
            x|X)
                echo
                echo "Start cancelled."
                exit 0
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

choose_optional_label() {
    local choice=""
    local entered_value=""

    while true; do
        print_header
        cat <<'TEXT'
Optional session label or version note

Choose how you want to tag this session:

1) No label
   Start without any extra tag

2) Version note
   Use a version-style tag
   Examples:
   - v3
   - v3-beta2
   - patch-1

3) General label
   Use a normal session label
   Examples:
   - intake-flow
   - report-cleanup
   - school-demo

x) Exit
TEXT
        echo
        read -r -p "Select an option: " choice

        case "${choice}" in
            1)
                LABEL=""
                return 0
                ;;
            2)
                echo
                read -r -p "Enter version note: " entered_value
                if [[ -n "${entered_value}" ]]; then
                    LABEL="${entered_value}"
                    return 0
                fi
                echo
                echo "Version note cannot be empty."
                pause_continue
                ;;
            3)
                echo
                read -r -p "Enter session label: " entered_value
                if [[ -n "${entered_value}" ]]; then
                    LABEL="${entered_value}"
                    return 0
                fi
                echo
                echo "Session label cannot be empty."
                pause_continue
                ;;
            x|X)
                echo
                echo "Start cancelled."
                exit 0
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

run_guided_start() {
    if [[ -f "${SENTINEL_ACTIVE_SESSION_FILE}" ]]; then
        sentinel_warn "A Sentinel session is already active."
        echo "State file: ${SENTINEL_ACTIVE_SESSION_FILE}"
        echo
        echo "Use 'sentinel status' to review it or 'sentinel stop' to end it first."
        exit 1
    fi

    choose_log_or_skip
    choose_mode
    choose_context
    choose_optional_label
    start_session_now
}

main() {
    if [[ $# -gt 0 ]]; then
        run_noninteractive_start "$@"
        return 0
    fi

    run_guided_start
}

main "$@"
