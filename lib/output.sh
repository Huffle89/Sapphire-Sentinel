#!/usr/bin/env bash

# ============================================================================
# Sapphire Sentinel
# Shared output and timestamp helpers
# ============================================================================

sentinel_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

sentinel_info() {
    echo "[INFO] $*"
}

sentinel_warn() {
    echo "[WARN] $*"
}

sentinel_error() {
    echo "[ERROR] $*" >&2
}

sentinel_section() {
    local title="$1"
    echo "$title"
    printf '%*s\n' "${#title}" '' | tr ' ' '-'
}
