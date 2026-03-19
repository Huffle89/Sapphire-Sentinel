#!/usr/bin/env bash
# Load shared paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/paths.sh"


set -u

echo "Sapphire Sentinel Update"
echo "────────────────────────"

# --- APT ---
if command -v apt >/dev/null 2>&1; then
    echo "[APT] Updating system packages..."
    sudo apt update && sudo apt upgrade -y
else
    echo "[APT] Not available, skipping."
fi

echo

# --- Flatpak ---
if command -v flatpak >/dev/null 2>&1; then
    echo "[Flatpak] Updating applications..."
    flatpak update -y
else
    echo "[Flatpak] Not installed, skipping."
fi

echo

# --- Snap ---
if command -v snap >/dev/null 2>&1; then
    echo "[Snap] Refreshing packages..."
    sudo snap refresh
else
    echo "[Snap] Not installed, skipping."
fi

echo
echo "Update run complete."
