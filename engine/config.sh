#!/usr/bin/env bash

set -u

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${ENGINE_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/paths.sh"
source "${PROJECT_ROOT}/lib/output.sh"

if [[ -f "${PROJECT_ROOT}/lib/config.sh" ]]; then
    # shellcheck source=../lib/config.sh
    source "${PROJECT_ROOT}/lib/config.sh"
fi

sentinel_require_initialization

CONFIG_FILE="$(sentinel_config_file)"

print_header() {
    clear
    echo "========================================"
    echo "      Sapphire Sentinel Config"
    echo "========================================"
    echo
}

pause_continue() {
    read -r -p "Press Enter to continue..."
}

get_default_storage_root() {
    if [[ -n "${SENTINEL_STORAGE_ROOT:-}" ]]; then
        echo "${SENTINEL_STORAGE_ROOT}"
    else
        echo "${HOME}/.local/share/sapphire-sentinel"
    fi
}

show_current_settings() {
    print_header
    echo "Current settings"
    echo
    echo "Prompt style:        $(sentinel_config_get prompt_style 2>/dev/null || echo guided)"
    echo "Storage location:    $(sentinel_config_get storage_root 2>/dev/null || echo "$(get_default_storage_root)")"
    echo "Context reminders:   $(sentinel_config_get feature_context_reminders 2>/dev/null || echo enabled)"
    echo "Session notes:       $(sentinel_config_get feature_session_notes 2>/dev/null || echo enabled)"
    echo "Reports:             $(sentinel_config_get feature_reports 2>/dev/null || echo enabled)"
    echo
    echo "Config file:"
    echo "${CONFIG_FILE}"
    echo
    pause_continue
}

set_prompt_style() {
    local choice=""

    while true; do
        print_header
        cat <<'TEXT'
Choose prompt style:

1) Guided
   Clearer prompts and explanations

2) Minimal
   Shorter prompts with less explanation

x) Back
TEXT
        echo
        read -r -p "Select an option: " choice

        case "${choice}" in
            1)
                sentinel_config_set "prompt_style" "guided"
                sentinel_info "Prompt style set to guided."
                pause_continue
                return 0
                ;;
            2)
                sentinel_config_set "prompt_style" "minimal"
                sentinel_info "Prompt style set to minimal."
                pause_continue
                return 0
                ;;
            x|X)
                return 0
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

set_storage_location() {
    local choice=""
    local custom_path=""
    local default_root

    default_root="$(get_default_storage_root)"

    while true; do
        print_header
        cat <<TEXT
Choose storage location:

1) Default
   ${default_root}

2) Custom
   Enter a custom storage path

x) Back
TEXT
        echo
        read -r -p "Select an option: " choice

        case "${choice}" in
            1)
                sentinel_config_set "storage_root" "${default_root}"
                sentinel_info "Storage location set to default."
                pause_continue
                return 0
                ;;
            2)
                echo
                read -r -p "Enter full storage path: " custom_path
                if [[ -z "${custom_path}" ]]; then
                    echo "Path cannot be empty."
                    pause_continue
                else
                    sentinel_config_set "storage_root" "${custom_path}"
                    sentinel_info "Storage location updated."
                    pause_continue
                    return 0
                fi
                ;;
            x|X)
                return 0
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

toggle_feature() {
    local key="$1"
    local title="$2"
    local current choice new_value

    current="$(sentinel_config_get "${key}" 2>/dev/null || echo enabled)"

    while true; do
        print_header
        echo "${title}"
        echo
        echo "Current value: ${current}"
        echo
        echo "1) Enable"
        echo "2) Disable"
        echo
        echo "x) Back"
        echo
        read -r -p "Select an option: " choice

        case "${choice}" in
            1)
                new_value="enabled"
                sentinel_config_set "${key}" "${new_value}"
                sentinel_info "${title} set to ${new_value}."
                pause_continue
                return 0
                ;;
            2)
                new_value="disabled"
                sentinel_config_set "${key}" "${new_value}"
                sentinel_info "${title} set to ${new_value}."
                pause_continue
                return 0
                ;;
            x|X)
                return 0
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

main() {
    local choice=""

    while true; do
        print_header
        cat <<'TEXT'
1) View current settings
2) Change prompt style
3) Change storage location
4) Toggle context reminders
5) Toggle session notes
6) Toggle reports

x) Exit
TEXT
        echo
        read -r -p "Select an option: " choice

        case "${choice}" in
            1) show_current_settings ;;
            2) set_prompt_style ;;
            3) set_storage_location ;;
            4) toggle_feature "feature_context_reminders" "Context reminders" ;;
            5) toggle_feature "feature_session_notes" "Session notes" ;;
            6) toggle_feature "feature_reports" "Reports" ;;
            x|X)
                echo
                echo "Config closed."
                exit 0
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

main "$@"
