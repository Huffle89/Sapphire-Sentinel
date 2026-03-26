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

# shellcheck source=engine/analytics_engine.sh
source "${ENGINE_DIR}/analytics_engine.sh"

sentinel_ensure_directories

require_initialization
touch "${SENTINEL_MAIN_LOG}"

print_divider() {
    printf '%s\n' "────────────────────────────────────────"
}

print_section() {
    printf '\n%s\n' "$1"
    print_divider
}

format_context() {
    local context_type="$1"
    local context_value="$2"

    if [[ -z "${context_type:-}" || "$context_type" == "none" ]]; then
        printf '%s\n' "none"
    else
        printf '%s:%s\n' "$context_type" "$context_value"
    fi
}

print_mode_breakdown() {
    local start_epoch="$1"
    local end_epoch="$2"
    local data

    data="$(mode_breakdown_in_window "$start_epoch" "$end_epoch")"

    if [[ -z "$data" ]]; then
        echo "No mode activity found."
        return
    fi

    while IFS='|' read -r mode count; do
        printf '%-16s %s\n' "$mode" "$count"
    done <<< "$data"
}

print_session_breakdown() {
    local start_epoch="$1"
    local end_epoch="$2"
    local data

    data="$(session_breakdown_in_window "$start_epoch" "$end_epoch")"

    if [[ -z "$data" ]]; then
        echo "No sessions found today."
        return
    fi

    printf '%-14s %-14s %-10s %-8s %-7s %-7s %-7s\n' \
        "Session ID" "Mode" "Context" "Commands" "Errors" "Notes" "Total"
    print_divider

    while IFS='|' read -r session_id mode context_type context_value end_time commands errors notes total scoreblob; do
        local context_display
        if [[ "$context_type" == "none" || -z "$context_type" ]]; then
            context_display="none"
        else
            context_display="${context_type}"
        fi

        printf '%-14s %-14s %-10s %-8s %-7s %-7s %-7s\n' \
            "$session_id" "$mode" "$context_display" "$commands" "$errors" "$notes" "$total"
    done <<< "$data"
}

print_top_session() {
    local label="$1"
    local line="$2"

    if [[ -z "$line" ]]; then
        echo "$label none"
        return
    fi

    local session_id mode context_type context_value end_time commands errors notes total scoreblob noise productive
    IFS='|' read -r session_id mode context_type context_value end_time commands errors notes total scoreblob <<< "$line"
    noise="${scoreblob%%|*}"
    productive="${scoreblob##*|}"

    echo "$label"
    print_divider
    printf 'Session ID:   %s\n' "$session_id"
    printf 'Mode:         %s\n' "$mode"
    printf 'Context:      %s\n' "$(format_context "$context_type" "$context_value")"
    printf 'Ended:        %s\n' "$end_time"
    printf 'Commands:     %s\n' "$commands"
    printf 'Errors:       %s\n' "$errors"
    printf 'Notes:        %s\n' "$notes"
    printf 'Signals:      %s\n' "$total"
    printf 'Noise Score:  %s\n' "$noise"
    printf 'Prod Score:   %s\n' "$productive"
}

print_recent_excerpts() {
    local start_epoch="$1"
    local end_epoch="$2"
    local data

    data="$(recent_excerpts_in_window "$start_epoch" "$end_epoch" 5)"

    if [[ -z "$data" ]]; then
        echo "No recent signal excerpts found."
        return
    fi

    while IFS='|' read -r timestamp mode action target status details; do
        printf '[%s] %s | %s | %s | %s\n' \
            "$timestamp" "$mode" "$action" "$status" "$details"
    done <<< "$data"
}

main() {
    local window start_epoch end_epoch
    local counts commands errors notes total
    local sessions_count

    window="$(window_today)"
    IFS='|' read -r start_epoch end_epoch <<< "$window"

    counts="$(count_signals_in_window "$start_epoch" "$end_epoch")"
    IFS='|' read -r commands errors notes total <<< "$counts"

    sessions_count="$(session_ids_in_window "$start_epoch" "$end_epoch" | awk 'NF{c++} END{print c+0}')"

    echo "Sapphire Sentinel Daily Report"
    print_divider
    printf 'Window:        Today\n'
    printf 'Sessions:      %s\n' "$sessions_count"
    printf 'Commands:      %s\n' "$commands"
    printf 'Errors:        %s\n' "$errors"
    printf 'Notes:         %s\n' "$notes"
    printf 'Total Signals: %s\n' "$total"

    print_section "Mode Breakdown"
    print_mode_breakdown "$start_epoch" "$end_epoch"

    print_section "Session Breakdown"
    print_session_breakdown "$start_epoch" "$end_epoch"

    print_section "Top Noisy Session"
    print_top_session "Most noisy session:" "$(top_noisy_session_in_window "$start_epoch" "$end_epoch")"

    print_section "Top Productive Session"
    print_top_session "Most productive session:" "$(top_productive_session_in_window "$start_epoch" "$end_epoch")"

    print_section "Recent Signal Excerpts"
    print_recent_excerpts "$start_epoch" "$end_epoch"
}

main "$@"
