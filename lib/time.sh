#!/usr/bin/env bash

# ============================================================================
# Sapphire Sentinel
# Shared time and duration helpers
# ============================================================================

sentinel_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

sentinel_epoch() {
    date +%s
}

sentinel_to_epoch() {
    local timestamp="$1"
    date -d "${timestamp}" +%s 2>/dev/null || echo 0
}

sentinel_format_duration() {
    local total_seconds="${1:-0}"

    if [[ "${total_seconds}" -lt 0 ]]; then
        total_seconds=0
    fi

    local days hours minutes seconds
    days=$((total_seconds / 86400))
    hours=$(((total_seconds % 86400) / 3600))
    minutes=$(((total_seconds % 3600) / 60))
    seconds=$((total_seconds % 60))

    if [[ "${days}" -gt 0 ]]; then
        printf '%sd %sh %sm %ss\n' "${days}" "${hours}" "${minutes}" "${seconds}"
    elif [[ "${hours}" -gt 0 ]]; then
        printf '%sh %sm %ss\n' "${hours}" "${minutes}" "${seconds}"
    elif [[ "${minutes}" -gt 0 ]]; then
        printf '%sm %ss\n' "${minutes}" "${seconds}"
    else
        printf '%ss\n' "${seconds}"
    fi
}
