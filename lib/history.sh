#!/usr/bin/env bash

# ============================================================================
# Sapphire Sentinel
# History helpers
# ============================================================================

set -u

SENTINEL_HISTORY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
source "${SENTINEL_HISTORY_LIB_DIR}/paths.sh"

sentinel_append_history() {
    local history_line="${1:-}"

    sentinel_ensure_paths
    touch "${SENTINEL_ACTIVE_HISTORY_FILE}"

    if [[ -n "${history_line}" ]]; then
        printf '%s\n' "${history_line}" >> "${SENTINEL_ACTIVE_HISTORY_FILE}"
    fi
}

sentinel_clear_active_history() {
    sentinel_ensure_paths
    : > "${SENTINEL_ACTIVE_HISTORY_FILE}"
}
