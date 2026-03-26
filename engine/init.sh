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

sentinel_ensure_directories
touch "${SENTINEL_MAIN_LOG}"

CONFIG_DIR="${HOME}/.config/sapphire-sentinel"
CONFIG_FILE="${CONFIG_DIR}/config"

init_existing_state="no"
init_mode_choice=""

prompt_style=""
storage_root=""
feature_context_reminders=""
feature_session_notes=""
feature_reports=""

changes_made="no"
feature_toggle_result=""

get_default_storage_root() {
    if [[ -n "${SENTINEL_STORAGE_ROOT:-}" ]]; then
        echo "${SENTINEL_STORAGE_ROOT}"
    else
        echo "${HOME}/.local/share/sapphire-sentinel"
    fi
}

print_header() {
    clear
    echo "========================================"
    echo "       Sapphire Sentinel Setup"
    echo "========================================"
    echo
}

pause_continue() {
    read -r -p "Press Enter to continue..."
}

config_initialized() {
    [[ -f "${CONFIG_FILE}" ]] || return 1
    grep -Eq '^initialized="?true"?$' "${CONFIG_FILE}" 2>/dev/null
}

prompt_yes_no() {
    local prompt_text="$1"
    local answer=""

    while true; do
        read -r -p "${prompt_text} " answer
        case "${answer}" in
            y|Y|yes|YES)
                return 0
                ;;
            n|N|no|NO)
                return 1
                ;;
            *)
                echo "Please enter y or n."
                ;;
        esac
    done
}

confirm_discard_changes() {
    if [[ "${changes_made}" != "yes" ]]; then
        return 0
    fi

    echo
    if prompt_yes_no "You have unsaved setup choices. Discard them? (y/n)"; then
        return 0
    fi

    return 1
}

show_intro() {
    print_header
    cat <<'TEXT'
Sapphire Sentinel helps you track and organize terminal work sessions.

In Personal mode, Sentinel is designed to help you:
- keep a record of what work was done
- attach work to a project, ticket, label, or general session
- build useful session stories and reports later
- keep your terminal work easier to review and understand

This setup will prepare Sentinel for Personal use.
TEXT
    echo
    pause_continue
}

handle_existing_init() {
    if config_initialized; then
        init_existing_state="yes"
        print_header
        echo "Sentinel appears to already be initialized."
        echo
        if prompt_yes_no "Do you want to run setup again? (y/n)"; then
            return 0
        fi
        echo
        echo "Setup cancelled."
        exit 0
    fi
}

reset_init_choices() {
    init_mode_choice=""
    prompt_style=""
    storage_root=""
    feature_context_reminders=""
    feature_session_notes=""
    feature_reports=""
    changes_made="no"
    feature_toggle_result=""
}

apply_quick_defaults() {
    init_mode_choice="quick"
    prompt_style="guided"
    storage_root="$(get_default_storage_root)"
    feature_context_reminders="enabled"
    feature_session_notes="enabled"
    feature_reports="enabled"
    changes_made="yes"
}

choose_install_type() {
    local choice=""

    while true; do
        print_header
        cat <<'TEXT'
Choose setup type:

1) Quick install
   Recommended defaults
   Guided prompts
   Default storage location
   Minimal decisions

2) Custom install
   Lets you choose each setup option
   Best if you want more control

x) Exit
TEXT
        echo
        read -r -p "Select an option: " choice

        case "${choice}" in
            1)
                apply_quick_defaults
                return 0
                ;;
            2)
                init_mode_choice="custom"
                changes_made="yes"
                return 0
                ;;
            x|X)
                if confirm_discard_changes; then
                    echo
                    echo "Setup cancelled."
                    exit 0
                fi
                ;;
            *)
                echo
                echo "Invalid selection. Please choose 1, 2, or x."
                pause_continue
                ;;
        esac
    done
}

choose_prompt_style() {
    local choice=""

    while true; do
        print_header
        cat <<'TEXT'
Prompt style controls how much guidance Sentinel shows during setup and future guided flows.

1) Guided
   Recommended
   Shows clearer explanations and safer prompts

2) Minimal
   Shorter prompts with less explanation

b) Back
m) Main menu
x) Exit
TEXT
        echo
        read -r -p "Select prompt style: " choice

        case "${choice}" in
            1)
                prompt_style="guided"
                changes_made="yes"
                return 0
                ;;
            2)
                prompt_style="minimal"
                changes_made="yes"
                return 0
                ;;
            b|B)
                return 10
                ;;
            m|M)
                if confirm_discard_changes; then
                    reset_init_choices
                    return 20
                fi
                ;;
            x|X)
                if confirm_discard_changes; then
                    echo
                    echo "Setup cancelled."
                    exit 0
                fi
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

choose_storage_location() {
    local choice=""
    local custom_path=""
    local default_root

    default_root="$(get_default_storage_root)"

    while true; do
        print_header
        cat <<TEXT
Storage location controls where Sentinel keeps its working data.

1) Default location
   ${default_root}

2) Custom location
   Choose your own storage path

b) Back
m) Main menu
x) Exit
TEXT
        echo
        read -r -p "Select storage location: " choice

        case "${choice}" in
            1)
                storage_root="${default_root}"
                changes_made="yes"
                return 0
                ;;
            2)
                echo
                read -r -p "Enter full storage path: " custom_path
                if [[ -z "${custom_path}" ]]; then
                    echo "Path cannot be empty."
                    pause_continue
                else
                    storage_root="${custom_path}"
                    changes_made="yes"
                    return 0
                fi
                ;;
            b|B)
                return 10
                ;;
            m|M)
                if confirm_discard_changes; then
                    reset_init_choices
                    return 20
                fi
                ;;
            x|X)
                if confirm_discard_changes; then
                    echo
                    echo "Setup cancelled."
                    exit 0
                fi
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

choose_feature_toggle() {
    local feature_name="$1"
    local feature_description="$2"
    local current_value="$3"
    local choice=""

    feature_toggle_result=""

    while true; do
        print_header
        echo "${feature_name}"
        echo
        echo "${feature_description}"
        echo
        echo "1) Enable"
        echo "2) Disable"
        echo
        echo "b) Back"
        echo "m) Main menu"
        echo "x) Exit"
        echo
        if [[ -n "${current_value}" ]]; then
            echo "Current selection: ${current_value}"
            echo
        fi

        read -r -p "Select an option: " choice

        case "${choice}" in
            1)
                feature_toggle_result="enabled"
                return 0
                ;;
            2)
                feature_toggle_result="disabled"
                return 0
                ;;
            b|B)
                return 10
                ;;
            m|M)
                return 20
                ;;
            x|X)
                return 30
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

choose_custom_features() {
    local status=0

    while true; do
        choose_feature_toggle \
            "Context reminders" \
            "When enabled, Sentinel can keep reminding you to attach work to useful context such as a project, ticket, label, or general session." \
            "${feature_context_reminders}"
        status=$?

        case "${status}" in
            0)
                feature_context_reminders="${feature_toggle_result}"
                changes_made="yes"
                ;;
            10)
                return 10
                ;;
            20)
                if confirm_discard_changes; then
                    reset_init_choices
                    return 20
                fi
                ;;
            30)
                if confirm_discard_changes; then
                    echo
                    echo "Setup cancelled."
                    exit 0
                fi
                ;;
        esac
        break
    done

    while true; do
        choose_feature_toggle \
            "Session notes" \
            "When enabled, Sentinel can support adding useful notes to a work session so the session story is easier to understand later." \
            "${feature_session_notes}"
        status=$?

        case "${status}" in
            0)
                feature_session_notes="${feature_toggle_result}"
                changes_made="yes"
                ;;
            10)
                return 10
                ;;
            20)
                if confirm_discard_changes; then
                    reset_init_choices
                    return 20
                fi
                ;;
            30)
                if confirm_discard_changes; then
                    echo
                    echo "Setup cancelled."
                    exit 0
                fi
                ;;
        esac
        break
    done

    while true; do
        choose_feature_toggle \
            "Reports" \
            "When enabled, Sentinel keeps report-related features available so you can review session activity through summary views later." \
            "${feature_reports}"
        status=$?

        case "${status}" in
            0)
                feature_reports="${feature_toggle_result}"
                changes_made="yes"
                return 0
                ;;
            10)
                return 10
                ;;
            20)
                if confirm_discard_changes; then
                    reset_init_choices
                    return 20
                fi
                ;;
            30)
                if confirm_discard_changes; then
                    echo
                    echo "Setup cancelled."
                    exit 0
                fi
                ;;
        esac
    done
}

run_custom_setup() {
    local stage="prompt"
    local status=0

    while true; do
        case "${stage}" in
            prompt)
                choose_prompt_style
                status=$?
                case "${status}" in
                    0) stage="storage" ;;
                    10) stage="prompt" ;;
                    20) return 20 ;;
                esac
                ;;
            storage)
                choose_storage_location
                status=$?
                case "${status}" in
                    0) stage="features" ;;
                    10) stage="prompt" ;;
                    20) return 20 ;;
                esac
                ;;
            features)
                choose_custom_features
                status=$?
                case "${status}" in
                    0) return 0 ;;
                    10) stage="storage" ;;
                    20) return 20 ;;
                esac
                ;;
        esac
    done
}

show_summary() {
    local choice=""

    while true; do
        print_header
        echo "Review your setup choices"
        echo
        echo "Install type:        ${init_mode_choice}"
        echo "Prompt style:        ${prompt_style}"
        echo "Storage location:    ${storage_root}"
        echo "Context reminders:   ${feature_context_reminders}"
        echo "Session notes:       ${feature_session_notes}"
        echo "Reports:             ${feature_reports}"
        echo
        cat <<'TEXT'
1) Confirm
   Accept these settings and continue

2) Change
   Go back and edit setup choices

3) Cancel
   Exit setup without saving

b) Back
m) Main menu
x) Exit
TEXT
        echo
        read -r -p "Select an option: " choice

        case "${choice}" in
            1)
                return 0
                ;;
            2|b|B)
                return 10
                ;;
            3|x|X)
                if confirm_discard_changes; then
                    echo
                    echo "Setup cancelled."
                    exit 0
                fi
                ;;
            m|M)
                if confirm_discard_changes; then
                    reset_init_choices
                    return 20
                fi
                ;;
            *)
                echo
                echo "Invalid selection."
                pause_continue
                ;;
        esac
    done
}

ensure_config_dir() {
    mkdir -p "${CONFIG_DIR}"
}

write_config_file() {
    ensure_config_dir

    cat > "${CONFIG_FILE}" <<EOF_CONFIG
initialized=true
install_type=${init_mode_choice}
prompt_style=${prompt_style}
storage_root=${storage_root}
feature_context_reminders=${feature_context_reminders}
feature_session_notes=${feature_session_notes}
feature_reports=${feature_reports}
EOF_CONFIG
}

show_completion_screen() {
    print_header
    echo "Sapphire Sentinel setup is complete."
    echo
    echo "Saved settings:"
    echo "Install type:        ${init_mode_choice}"
    echo "Prompt style:        ${prompt_style}"
    echo "Storage location:    ${storage_root}"
    echo "Context reminders:   ${feature_context_reminders}"
    echo "Session notes:       ${feature_session_notes}"
    echo "Reports:             ${feature_reports}"
    echo
    echo "Configuration file:"
    echo "${CONFIG_FILE}"
    echo
    echo "Sentinel is now marked as initialized."
}

main() {
    local status=0

    handle_existing_init
    show_intro

    while true; do
        choose_install_type

        if [[ "${init_mode_choice}" == "quick" ]]; then
            show_summary
            status=$?
            case "${status}" in
                0)
                    write_config_file
                    changes_made="no"
                    show_completion_screen
                    return 0
                    ;;
                10|20)
                    reset_init_choices
                    continue
                    ;;
            esac
        fi

        if [[ "${init_mode_choice}" == "custom" ]]; then
            run_custom_setup
            status=$?

            case "${status}" in
                20)
                    reset_init_choices
                    continue
                    ;;
            esac

            show_summary
            status=$?
            case "${status}" in
                0)
                    write_config_file
                    changes_made="no"
                    show_completion_screen
                    return 0
                    ;;
                10|20)
                    reset_init_choices
                    continue
                    ;;
            esac
        fi
    done
}

main "$@"
