#!/usr/bin/env bash

# ============================================================================
# Sapphire Sentinel
# Session history helpers
# ============================================================================

sentinel_append_history() {
    local history_file="$1"
    local event_time="$2"
    local event_type="$3"
    local event_value="$4"

    mkdir -p "$(dirname "$history_file")"
    printf '%s|%s|%s\n' "$event_time" "$event_type" "$event_value" >> "$history_file"
}
