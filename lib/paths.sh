#!/usr/bin/env bash

# ============================================================================
# Sapphire Sentinel
# Shared path resolution
# Supports:
#   - project mode
#   - installed mode
# Includes compatibility aliases for current beta 2 engine/dispatcher scripts
# ============================================================================

# shellcheck disable=SC2034

SENTINEL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SENTINEL_BASE_DIR="$(cd "${SENTINEL_LIB_DIR}/.." && pwd)"

# Load config helpers
# shellcheck source=../lib/config.sh
source "${SENTINEL_BASE_DIR}/lib/config.sh"

# ----------------------------------------------------------------------------
# Mode detection
# ----------------------------------------------------------------------------
if [[ -x "${SENTINEL_BASE_DIR}/bin/sentinel" && -d "${SENTINEL_BASE_DIR}/engine" ]]; then
    SENTINEL_LAYOUT_MODE="project"
else
    SENTINEL_LAYOUT_MODE="installed"
fi

# Legacy compatibility alias expected by older scripts
SENTINEL_MODE="${SENTINEL_LAYOUT_MODE}"

# ----------------------------------------------------------------------------
# Project mode paths
# ----------------------------------------------------------------------------
if [[ "${SENTINEL_LAYOUT_MODE}" == "project" ]]; then
    SENTINEL_PROJECT_ROOT="${SENTINEL_BASE_DIR}"

    SENTINEL_BIN_DIR="${SENTINEL_PROJECT_ROOT}/bin"
    SENTINEL_ENGINE_DIR="${SENTINEL_PROJECT_ROOT}/engine"
    SENTINEL_LIB_SHARED_DIR="${SENTINEL_PROJECT_ROOT}/lib"
    SENTINEL_CONFIG_DIR="${SENTINEL_PROJECT_ROOT}/config"
    SENTINEL_DOCS_DIR="${SENTINEL_PROJECT_ROOT}/docs"
    SENTINEL_LOG_DIR="${SENTINEL_PROJECT_ROOT}/logs"

    # Writable state for project/dev mode
    SENTINEL_DATA_DIR="${SENTINEL_CONFIG_DIR}"
    SENTINEL_STATE_DIR="${SENTINEL_CONFIG_DIR}/state"
    SENTINEL_SESSION_ARCHIVE_DIR="${SENTINEL_STATE_DIR}/sessions"

    sentinel_config_init_file
    SENTINEL_STORAGE_ROOT="${SENTINEL_PROJECT_ROOT}"
    sentinel_storage_root_override="$(sentinel_config_get storage_root 2>/dev/null || true)"
    if [[ -n "${sentinel_storage_root_override:-}" ]]; then
        SENTINEL_STORAGE_ROOT="${sentinel_storage_root_override}"
    fi

# ----------------------------------------------------------------------------
# Installed mode paths
# ----------------------------------------------------------------------------
else
    SENTINEL_INSTALL_ROOT="${SENTINEL_BASE_DIR}"

    SENTINEL_BIN_DIR="/usr/local/bin"
    SENTINEL_ENGINE_DIR="${SENTINEL_INSTALL_ROOT}/engine"
    SENTINEL_LIB_SHARED_DIR="${SENTINEL_INSTALL_ROOT}/lib"
    SENTINEL_CONFIG_DIR="/etc/sapphire-sentinel"
    SENTINEL_DOCS_DIR="${SENTINEL_INSTALL_ROOT}/docs"
    SENTINEL_LOG_DIR="/var/log/sapphire-sentinel"

    # Writable system state
    SENTINEL_DATA_DIR="/var/lib/sapphire-sentinel"
    SENTINEL_STATE_DIR="${SENTINEL_DATA_DIR}/state"
    SENTINEL_SESSION_ARCHIVE_DIR="${SENTINEL_STATE_DIR}/sessions"

    sentinel_config_init_file
    SENTINEL_STORAGE_ROOT="${SENTINEL_DATA_DIR}"
    sentinel_storage_root_override="$(sentinel_config_get storage_root 2>/dev/null || true)"
    if [[ -n "${sentinel_storage_root_override:-}" ]]; then
        SENTINEL_STORAGE_ROOT="${sentinel_storage_root_override}"
    fi
fi

# ----------------------------------------------------------------------------
# Canonical files
# ----------------------------------------------------------------------------
SENTINEL_ACTIVE_SESSION_FILE="${SENTINEL_STATE_DIR}/active_session"
SENTINEL_ACTIVE_HISTORY_FILE="${SENTINEL_STATE_DIR}/active_session.history"
SENTINEL_CANONICAL_LOG_FILE="${SENTINEL_LOG_DIR}/sentinel.log"

# ----------------------------------------------------------------------------
# Compatibility aliases
# ----------------------------------------------------------------------------
SENTINEL_SESSION_STATE_FILE="${SENTINEL_ACTIVE_SESSION_FILE}"
SENTINEL_SESSION_HISTORY_FILE="${SENTINEL_ACTIVE_HISTORY_FILE}"
SENTINEL_LOG_FILE="${SENTINEL_CANONICAL_LOG_FILE}"

# Older beta names still referenced in engine scripts
SENTINEL_MAIN_LOG="${SENTINEL_CANONICAL_LOG_FILE}"
SENTINEL_STATE_FILE="${SENTINEL_ACTIVE_SESSION_FILE}"
SENTINEL_HISTORY_FILE="${SENTINEL_ACTIVE_HISTORY_FILE}"
SENTINEL_SESSIONS_DIR="${SENTINEL_SESSION_ARCHIVE_DIR}"

# ----------------------------------------------------------------------------
# Directory bootstrap
# ----------------------------------------------------------------------------
sentinel_ensure_paths() {
    mkdir -p \
        "${SENTINEL_CONFIG_DIR}" \
        "${SENTINEL_LOG_DIR}" \
        "${SENTINEL_STATE_DIR}" \
        "${SENTINEL_SESSION_ARCHIVE_DIR}"
}

# Legacy helper name expected by older scripts
sentinel_ensure_directories() {
    sentinel_ensure_paths
}

# ----------------------------------------------------------------------------
# Exported variables
# ----------------------------------------------------------------------------
export SENTINEL_LAYOUT_MODE
export SENTINEL_MODE
export SENTINEL_LIB_DIR
export SENTINEL_BASE_DIR
export SENTINEL_BIN_DIR
export SENTINEL_ENGINE_DIR
export SENTINEL_LIB_SHARED_DIR
export SENTINEL_CONFIG_DIR
export SENTINEL_DOCS_DIR
export SENTINEL_LOG_DIR
export SENTINEL_DATA_DIR
export SENTINEL_STATE_DIR
export SENTINEL_SESSION_ARCHIVE_DIR
export SENTINEL_STORAGE_ROOT

export SENTINEL_ACTIVE_SESSION_FILE
export SENTINEL_ACTIVE_HISTORY_FILE
export SENTINEL_CANONICAL_LOG_FILE

export SENTINEL_SESSION_STATE_FILE
export SENTINEL_SESSION_HISTORY_FILE
export SENTINEL_LOG_FILE

export SENTINEL_MAIN_LOG
export SENTINEL_STATE_FILE
export SENTINEL_HISTORY_FILE
export SENTINEL_SESSIONS_DIR

# ----------------------------------------------------------------------------
# Runtime compatibility (legacy engine support)
# ----------------------------------------------------------------------------
# Older engine scripts expect a runtime directory.
# In v3 architecture, runtime == state layer.
SENTINEL_RUNTIME_DIR="${SENTINEL_STATE_DIR}"

export SENTINEL_RUNTIME_DIR
