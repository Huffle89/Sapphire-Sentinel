#!/usr/bin/env bash

set -u

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${ENGINE_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/paths.sh"
source "${PROJECT_ROOT}/lib/output.sh"

sentinel_ensure_directories
touch "${SENTINEL_MAIN_LOG}"

sentinel_info "Initialized Sapphire Sentinel directories."
echo "Mode: ${SENTINEL_MODE}"
echo "Config dir: ${SENTINEL_CONFIG_DIR}"
echo "State dir: ${SENTINEL_STATE_DIR}"
echo "Runtime dir: ${SENTINEL_RUNTIME_DIR}"
echo "Log dir: ${SENTINEL_LOG_DIR}"
echo "Main log: ${SENTINEL_MAIN_LOG}"
echo "Session archive dir: ${SENTINEL_SESSION_ARCHIVE_DIR}"
