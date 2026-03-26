#!/usr/bin/env bash

# ============================================================================
# Sapphire Sentinel
# Shared path resolution
# Supports:
# - project mode -> run from repo checkout
# - installed mode -> run from /usr/local/bin with system paths
# ============================================================================

# ----------------------------------------------------------------------------
# Detect where this file lives
# ----------------------------------------------------------------------------
SENTINEL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SENTINEL_PROJECT_ROOT="$(cd "${SENTINEL_LIB_DIR}/.." && pwd)"

# ----------------------------------------------------------------------------
# Environment override support
# These allow manual forcing during testing or packaging.
# ----------------------------------------------------------------------------
SENTINEL_FORCE_MODE="${SENTINEL_FORCE_MODE:-}"
SENTINEL_INSTALL_PREFIX="${SENTINEL_INSTALL_PREFIX:-/usr/local}"
SENTINEL_SYSTEM_CONFIG_DIR="${SENTINEL_SYSTEM_CONFIG_DIR:-/etc/sapphire-sentinel}"
SENTINEL_SYSTEM_DATA_DIR="${SENTINEL_SYSTEM_DATA_DIR:-/var/lib/sapphire-sentinel}"
SENTINEL_SYSTEM_LOG_DIR="${SENTINEL_SYSTEM_LOG_DIR:-/var/log/sapphire-sentinel}"

# Optional explicit storage override from environment
SENTINEL_STORAGE_ROOT_OVERRIDE="${SENTINEL_STORAGE_ROOT_OVERRIDE:-}"

# ----------------------------------------------------------------------------
# User config lookup
# This is intentionally self-contained so paths can load storage_root early
# without depending on lib/config.sh and creating a circular dependency.
# ----------------------------------------------------------------------------
SENTINEL_USER_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SENTINEL_USER_CONFIG_DIR="${SENTINEL_USER_CONFIG_HOME}/sapphire-sentinel"
SENTINEL_USER_CONFIG_FILE="${SENTINEL_USER_CONFIG_DIR}/config"

sentinel_read_user_config_value() {
    local key="$1"

    [[ -f "${SENTINEL_USER_CONFIG_FILE}" ]] || return 1

    awk -F'=' -v wanted="${key}" '
        $1 == wanted {
            print substr($0, index($0, "=") + 1)
            exit
        }
    ' "${SENTINEL_USER_CONFIG_FILE}"
}

if [[ -z "${SENTINEL_STORAGE_ROOT_OVERRIDE}" ]]; then
    SENTINEL_STORAGE_ROOT_OVERRIDE="$(sentinel_read_user_config_value storage_root 2>/dev/null || true)"
fi

# ----------------------------------------------------------------------------
# Path model detection
# installed mode is assumed when running from a system lib path, or when forced
# ----------------------------------------------------------------------------
sentinel_detect_mode() {
    if [[ -n "$SENTINEL_FORCE_MODE" ]]; then
        printf '%s\n' "$SENTINEL_FORCE_MODE"
        return
    fi

    case "$SENTINEL_LIB_DIR" in
        /usr/local/lib/sapphire-sentinel/lib|/usr/lib/sapphire-sentinel/lib)
            printf '%s\n' "installed"
            ;;
        *)
            printf '%s\n' "project"
            ;;
    esac
}

SENTINEL_MODE="$(sentinel_detect_mode)"

# ----------------------------------------------------------------------------
# Resolve paths by mode
# ----------------------------------------------------------------------------
if [[ "$SENTINEL_MODE" == "installed" ]]; then
    SENTINEL_BIN_DIR="${SENTINEL_INSTALL_PREFIX}/bin"
    SENTINEL_APP_DIR="${SENTINEL_INSTALL_PREFIX}/lib/sapphire-sentinel"
    SENTINEL_ENGINE_DIR="${SENTINEL_APP_DIR}/engine"
    SENTINEL_LIB_SHARED_DIR="${SENTINEL_APP_DIR}/lib"
    SENTINEL_DOCS_DIR="${SENTINEL_APP_DIR}/docs"
    SENTINEL_CONFIG_DIR="${SENTINEL_SYSTEM_CONFIG_DIR}"

    if [[ -n "${SENTINEL_STORAGE_ROOT_OVERRIDE}" ]]; then
        SENTINEL_STORAGE_ROOT="${SENTINEL_STORAGE_ROOT_OVERRIDE}"
        SENTINEL_STATE_DIR="${SENTINEL_STORAGE_ROOT}/state"
        SENTINEL_RUNTIME_DIR="${SENTINEL_STORAGE_ROOT}/logs/runtime"
        SENTINEL_LOG_DIR="${SENTINEL_STORAGE_ROOT}/logs"
    else
        SENTINEL_STORAGE_ROOT="${SENTINEL_SYSTEM_DATA_DIR}"
        SENTINEL_STATE_DIR="${SENTINEL_SYSTEM_DATA_DIR}/state"
        SENTINEL_RUNTIME_DIR="${SENTINEL_SYSTEM_LOG_DIR}/runtime"
        SENTINEL_LOG_DIR="${SENTINEL_SYSTEM_LOG_DIR}"
    fi

    SENTINEL_MAIN_LOG="${SENTINEL_LOG_DIR}/sentinel.log"
    SENTINEL_ACTIVE_SESSION_FILE="${SENTINEL_STATE_DIR}/active_session"
    SENTINEL_SESSION_ARCHIVE_DIR="${SENTINEL_STATE_DIR}/sessions"
else
    SENTINEL_BIN_DIR="${SENTINEL_PROJECT_ROOT}/bin"
    SENTINEL_APP_DIR="${SENTINEL_PROJECT_ROOT}"
    SENTINEL_ENGINE_DIR="${SENTINEL_PROJECT_ROOT}/engine"
    SENTINEL_LIB_SHARED_DIR="${SENTINEL_PROJECT_ROOT}/lib"
    SENTINEL_CONFIG_DIR="${SENTINEL_PROJECT_ROOT}/config"
    SENTINEL_DOCS_DIR="${SENTINEL_PROJECT_ROOT}/docs"

    if [[ -n "${SENTINEL_STORAGE_ROOT_OVERRIDE}" ]]; then
        SENTINEL_STORAGE_ROOT="${SENTINEL_STORAGE_ROOT_OVERRIDE}"
        SENTINEL_STATE_DIR="${SENTINEL_STORAGE_ROOT}/state"
        SENTINEL_RUNTIME_DIR="${SENTINEL_STORAGE_ROOT}/logs/runtime"
        SENTINEL_LOG_DIR="${SENTINEL_STORAGE_ROOT}/logs"
    else
        SENTINEL_STORAGE_ROOT="${SENTINEL_PROJECT_ROOT}"
        SENTINEL_STATE_DIR="${SENTINEL_CONFIG_DIR}/state"
        SENTINEL_RUNTIME_DIR="${SENTINEL_PROJECT_ROOT}/logs/runtime"
        SENTINEL_LOG_DIR="${SENTINEL_PROJECT_ROOT}/logs"
    fi

    SENTINEL_MAIN_LOG="${SENTINEL_LOG_DIR}/sentinel.log"
    SENTINEL_ACTIVE_SESSION_FILE="${SENTINEL_STATE_DIR}/active_session"
    SENTINEL_SESSION_ARCHIVE_DIR="${SENTINEL_STATE_DIR}/sessions"
fi

# ----------------------------------------------------------------------------
# Common helpers
# ----------------------------------------------------------------------------
sentinel_ensure_directories() {
    mkdir -p \
        "$SENTINEL_ENGINE_DIR" \
        "$SENTINEL_LIB_SHARED_DIR" \
        "$SENTINEL_CONFIG_DIR" \
        "$SENTINEL_DOCS_DIR" \
        "$SENTINEL_STATE_DIR" \
        "$SENTINEL_RUNTIME_DIR" \
        "$SENTINEL_LOG_DIR" \
        "$SENTINEL_SESSION_ARCHIVE_DIR"
}

sentinel_debug_paths() {
    cat <<EOF_PATHS
SENTINEL_MODE=${SENTINEL_MODE}
SENTINEL_PROJECT_ROOT=${SENTINEL_PROJECT_ROOT}
SENTINEL_STORAGE_ROOT=${SENTINEL_STORAGE_ROOT}
SENTINEL_BIN_DIR=${SENTINEL_BIN_DIR}
SENTINEL_APP_DIR=${SENTINEL_APP_DIR}
SENTINEL_ENGINE_DIR=${SENTINEL_ENGINE_DIR}
SENTINEL_LIB_SHARED_DIR=${SENTINEL_LIB_SHARED_DIR}
SENTINEL_CONFIG_DIR=${SENTINEL_CONFIG_DIR}
SENTINEL_DOCS_DIR=${SENTINEL_DOCS_DIR}
SENTINEL_STATE_DIR=${SENTINEL_STATE_DIR}
SENTINEL_RUNTIME_DIR=${SENTINEL_RUNTIME_DIR}
SENTINEL_LOG_DIR=${SENTINEL_LOG_DIR}
SENTINEL_MAIN_LOG=${SENTINEL_MAIN_LOG}
SENTINEL_ACTIVE_SESSION_FILE=${SENTINEL_ACTIVE_SESSION_FILE}
SENTINEL_SESSION_ARCHIVE_DIR=${SENTINEL_SESSION_ARCHIVE_DIR}
EOF_PATHS
}
