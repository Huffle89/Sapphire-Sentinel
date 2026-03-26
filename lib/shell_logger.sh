#!/usr/bin/env bash

[[ $- != *i* ]] && return 0

if [[ -n "${SENTINEL_SHELL_LOGGER_LOADED:-}" ]]; then
    return 0
fi
export SENTINEL_SHELL_LOGGER_LOADED=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT/lib/paths.sh"
source "$ROOT/lib/logging.sh"
source "$ROOT/lib/session.sh"
source "$ROOT/lib/time.sh"

sentinel_shell_logger_load_active() {
    [[ -f "$SENTINEL_ACTIVE_SESSION_FILE" ]] || return 1
    sentinel_load_session_file "$SENTINEL_ACTIVE_SESSION_FILE"
}

sentinel_shell_logger_transcript_file() {
    echo "$SENTINEL_LOG_DIR/transcripts/${session_id}.journal"
}

sentinel_shell_logger_init_transcript() {
    local file
    file="$(sentinel_shell_logger_transcript_file)"
    mkdir -p "$(dirname "$file")"

    if [[ ! -f "$file" ]]; then
        {
            echo "========================================"
            echo "Sapphire Sentinel Session Transcript"
            echo "========================================"
            echo "Session ID: $session_id"
            echo "Mode: $session_mode"
            if [[ -z "${context_type:-}" || "${context_type}" == "none" ]]; then
                echo "Context: none"
            else
                echo "Context: $context_type: $context_value"
            fi
            echo "Label: ${label:-none}"
            echo "Started: $start_time"
            echo "Host: $host_name"
            echo "User: $operator_user"
            echo "========================================"
            echo
        } >> "$file"
    fi
}

sentinel_shell_logger_capture_debug() {
    case "$BASH_COMMAND" in
        sentinel_shell_logger_capture_debug*|\
        sentinel_shell_logger_postcmd*|\
        sentinel_shell_logger_load_active*|\
        sentinel_shell_logger_init_transcript*|\
        sentinel_shell_logger_transcript_file*|\
        history\ -a*|\
        trap*|\
        source\ *shell_logger.sh*|\
        PROMPT_COMMAND=*|\
        unset\ SENTINEL_SHELL_LOGGER_*|\
        declare\ -p\ PROMPT_COMMAND*|\
        type\ sentinel_shell_logger_postcmd*)
            return
            ;;
    esac

    SENTINEL_LAST_CMD="$BASH_COMMAND"
}

trap 'sentinel_shell_logger_capture_debug' DEBUG

sentinel_shell_logger_postcmd() {
    local exit_code=$?
    local cmd file timestamp

    [[ $- != *i* ]] && return "$exit_code"

    if sentinel_shell_logger_load_active; then
        cmd="${SENTINEL_LAST_CMD:-}"

        [[ -z "$cmd" ]] && return "$exit_code"

        sentinel_log_event \
            "$session_mode" \
            "signal_command" \
            "$session_id" \
            "$([[ $exit_code -eq 0 ]] && echo success || echo failed)" \
            "exit_code=$exit_code;command=$cmd"

        if [[ $exit_code -ne 0 ]]; then
            sentinel_log_event \
                "$session_mode" \
                "signal_error" \
                "$session_id" \
                "failed" \
                "exit_code=$exit_code;command=$cmd"
        fi

        sentinel_shell_logger_init_transcript
        file="$(sentinel_shell_logger_transcript_file)"
        timestamp="$(sentinel_timestamp)"

        {
            echo "[$timestamp]"
            echo "  run: $cmd"
            echo "  exit: $exit_code"
            echo
        } >> "$file"
    fi

    return "$exit_code"
}

PROMPT_COMMAND="sentinel_shell_logger_postcmd"
export PROMPT_COMMAND
