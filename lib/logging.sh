#!/usr/bin/env bash

# ============================================================================
# Sapphire Sentinel
# Canonical structured logging helpers
# ============================================================================

sentinel_log_write() {
    local timestamp="$1"
    local mode="$2"
    local action="$3"
    local target="$4"
    local status="$5"
    local details="$6"

    printf '%s|%s|%s|%s|%s|%s\n' \
        "$timestamp" \
        "$mode" \
        "$action" \
        "$target" \
        "$status" \
        "$details" \
        >> "${SENTINEL_MAIN_LOG}"
}

sentinel_log_event() {
    local mode="$1"
    local action="$2"
    local target="$3"
    local status="$4"
    local details="$5"

    sentinel_log_write "$(sentinel_timestamp)" "$mode" "$action" "$target" "$status" "$details"
}
