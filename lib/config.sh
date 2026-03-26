#!/usr/bin/env bash

# ============================================================================
# Sapphire Sentinel
# Config helpers
# ============================================================================

SENTINEL_USER_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SENTINEL_USER_CONFIG_DIR="${SENTINEL_USER_CONFIG_HOME}/sapphire-sentinel"
SENTINEL_USER_CONFIG_FILE="${SENTINEL_USER_CONFIG_DIR}/config"

sentinel_config_ensure_dir() {
    mkdir -p "${SENTINEL_USER_CONFIG_DIR}"
}

sentinel_config_file() {
    printf '%s\n' "${SENTINEL_USER_CONFIG_FILE}"
}

sentinel_config_exists() {
    [[ -f "$(sentinel_config_file)" ]]
}

sentinel_config_init_file() {
    sentinel_config_ensure_dir

    if [[ ! -f "$(sentinel_config_file)" ]]; then
        cat > "$(sentinel_config_file)" <<'CFG'
# Sapphire Sentinel user config
initialized=no
install_profile=
prompt_style=guided
storage_root=
CFG
    fi
}

sentinel_config_get() {
    local key="$1"
    local file
    file="$(sentinel_config_file)"

    [[ -f "${file}" ]] || return 1

    awk -F'=' -v wanted="${key}" '
        $1 == wanted {
            val = substr($0, index($0, "=") + 1)
            print val
            exit
        }
    ' "${file}"
}

sentinel_config_set() {
    local key="$1"
    local value="$2"
    local file tmp

    sentinel_config_init_file
    file="$(sentinel_config_file)"
    tmp="$(mktemp)"

    awk -F'=' -v wanted="${key}" -v replacement="${value}" '
        BEGIN { updated = 0 }
        $1 == wanted {
            print wanted "=" replacement
            updated = 1
            next
        }
        { print $0 }
        END {
            if (updated == 0) {
                print wanted "=" replacement
            }
        }
    ' "${file}" > "${tmp}"

    mv "${tmp}" "${file}"
}

sentinel_config_is_initialized() {
    [[ "$(sentinel_config_get initialized 2>/dev/null)" == "yes" ]]
}
