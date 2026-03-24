#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_PREFIX="/usr/local"
APP_DIR="${INSTALL_PREFIX}/lib/sapphire-sentinel"
BIN_DIR="${INSTALL_PREFIX}/bin"
CONFIG_DIR="/etc/sapphire-sentinel"
DATA_DIR="/var/lib/sapphire-sentinel"
LOG_DIR="/var/log/sapphire-sentinel"

INSTALL_USER="${SUDO_USER:-$USER}"
INSTALL_GROUP="$(id -gn "${INSTALL_USER}")"

print_divider() {
    printf '%s\n' "────────────────────────────────────────"
}

info() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*"
}

error() {
    printf '[ERROR] %s\n' "$*" >&2
}

require_sudo() {
    if command -v sudo >/dev/null 2>&1; then
        return 0
    fi

    error "sudo is required for installation."
    exit 1
}

copy_dir_clean() {
    local src="$1"
    local dst="$2"

    sudo mkdir -p "$dst"
    sudo rm -rf "${dst:?}/"*
    sudo cp -R "${src}/." "$dst/"
}

main() {
    require_sudo

    print_divider
    echo "Sapphire Sentinel Installer"
    print_divider

    info "Installing Sapphire Sentinel into system paths..."
    info "Project root: ${PROJECT_ROOT}"
    info "Install user: ${INSTALL_USER}"

    if [[ ! -f "${PROJECT_ROOT}/bin/sentinel" ]]; then
        error "Could not find bin/sentinel from project root."
        exit 1
    fi

    if [[ ! -d "${PROJECT_ROOT}/engine" || ! -d "${PROJECT_ROOT}/lib" ]]; then
        error "Required project directories are missing."
        exit 1
    fi

    info "Creating target directories..."
    sudo mkdir -p "${BIN_DIR}" "${APP_DIR}" "${CONFIG_DIR}" "${DATA_DIR}" "${LOG_DIR}"
    sudo mkdir -p "${DATA_DIR}/state" "${DATA_DIR}/state/sessions"
    sudo mkdir -p "${LOG_DIR}/runtime"
    sudo touch "${LOG_DIR}/sentinel.log"

    info "Removing stale installed application files..."
    sudo rm -rf "${APP_DIR}"
    sudo mkdir -p "${APP_DIR}"

    info "Copying application files..."
    copy_dir_clean "${PROJECT_ROOT}/engine" "${APP_DIR}/engine"
    copy_dir_clean "${PROJECT_ROOT}/lib" "${APP_DIR}/lib"

    if [[ -d "${PROJECT_ROOT}/docs" ]]; then
        copy_dir_clean "${PROJECT_ROOT}/docs" "${APP_DIR}/docs"
    else
        warn "docs/ directory not found. Skipping docs install."
    fi

    if [[ -d "${PROJECT_ROOT}/assets" ]]; then
        copy_dir_clean "${PROJECT_ROOT}/assets" "${APP_DIR}/assets"
    else
        warn "assets/ directory not found. Skipping assets install."
    fi

    info "Installing dispatcher..."
    sudo install -m 755 "${PROJECT_ROOT}/bin/sentinel" "${BIN_DIR}/sentinel"

    if [[ -f "${PROJECT_ROOT}/config/sentinel.conf" ]]; then
        if [[ ! -f "${CONFIG_DIR}/sentinel.conf" ]]; then
            info "Installing default config..."
            sudo install -m 644 "${PROJECT_ROOT}/config/sentinel.conf" "${CONFIG_DIR}/sentinel.conf"
        else
            warn "Config already exists at ${CONFIG_DIR}/sentinel.conf. Leaving it in place."
        fi
    else
        warn "config/sentinel.conf not found. Skipping config install."
    fi

    info "Setting permissions..."
    sudo chmod -R 755 "${APP_DIR}"
    sudo chmod 755 "${BIN_DIR}/sentinel"
    sudo chmod 755 "${CONFIG_DIR}"
    sudo chmod -R 775 "${DATA_DIR}" "${LOG_DIR}"
    sudo chown -R "${INSTALL_USER}:${INSTALL_GROUP}" "${DATA_DIR}" "${LOG_DIR}"

    info "Running post-install initialization..."
    sentinel init

    print_divider
    echo "Install complete."
    print_divider
    echo "Global command is now available:"
    echo "  sentinel"
    echo
    echo "Try:"
    echo "  sentinel status"
    echo "  sentinel start project sapphire_sentinel"
}

main "$@"
