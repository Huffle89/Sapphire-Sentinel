#!/usr/bin/env bash

# ============================================================================
# Sapphire Sentinel - Analytics Engine
# Shared analytics helpers for sentinel.log + archived session metadata
# ============================================================================

set -u

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${ENGINE_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/lib/paths.sh"

sentinel_ensure_directories
touch "${SENTINEL_MAIN_LOG}"

to_epoch() {
    date -d "$1" +%s 2>/dev/null
}

between_epochs() {
    local ts="$1"
    local start_epoch="$2"
    local end_epoch="$3"
    local ts_epoch

    ts_epoch="$(to_epoch "$ts")" || return 1
    [[ "$ts_epoch" -ge "$start_epoch" && "$ts_epoch" -le "$end_epoch" ]]
}

window_today() {
    printf '%s|%s\n' \
        "$(to_epoch "$(date '+%Y-%m-%d 00:00:00')")" \
        "$(to_epoch "$(date '+%Y-%m-%d 23:59:59')")"
}

window_last_7_days() {
    printf '%s|%s\n' \
        "$(to_epoch "$(date -d '6 days ago 00:00:00' '+%Y-%m-%d %H:%M:%S')")" \
        "$(to_epoch "$(date '+%Y-%m-%d 23:59:59')")"
}

window_last_30_days() {
    printf '%s|%s\n' \
        "$(to_epoch "$(date -d '29 days ago 00:00:00' '+%Y-%m-%d %H:%M:%S')")" \
        "$(to_epoch "$(date '+%Y-%m-%d 23:59:59')")"
}

window_week() {
    window_last_7_days
}

window_month() {
    window_last_30_days
}

read_session_value() {
    local file="$1"
    local key="$2"

    awk -F'=' -v wanted="$key" '
        $1 == wanted {
            val = substr($0, index($0, "=") + 1)
            gsub(/\\ /, " ", val)
            gsub(/^'\''|'\''$/, "", val)
            print val
            exit
        }
    ' "$file"
}

session_file_for_id() {
    local session_id="$1"
    local file="${SENTINEL_SESSION_ARCHIVE_DIR}/${session_id}.session"
    [[ -f "$file" ]] && printf '%s\n' "$file"
}

session_ids_in_window() {
    local start_epoch="$1"
    local end_epoch="$2"

    [[ -d "${SENTINEL_SESSION_ARCHIVE_DIR}" ]] || return 0

    local file end_time session_id
    for file in "${SENTINEL_SESSION_ARCHIVE_DIR}"/*.session; do
        [[ -f "$file" ]] || continue
        end_time="$(read_session_value "$file" "end_time")"
        session_id="$(read_session_value "$file" "session_id")"

        [[ -z "${end_time:-}" || -z "${session_id:-}" ]] && continue

        if between_epochs "$end_time" "$start_epoch" "$end_epoch"; then
            printf '%s\n' "$session_id"
        fi
    done | sort
}

signal_stream_in_window() {
    local start_epoch="$1"
    local end_epoch="$2"

    [[ -f "${SENTINEL_MAIN_LOG}" ]] || return 0

    while IFS='|' read -r timestamp mode action target status details; do
        [[ -z "${timestamp:-}" ]] && continue

        case "$action" in
            signal_command|signal_error|signal_note)
                if between_epochs "$timestamp" "$start_epoch" "$end_epoch"; then
                    printf '%s|%s|%s|%s|%s|%s\n' \
                        "$timestamp" "$mode" "$action" "$target" "$status" "$details"
                fi
                ;;
        esac
    done < "${SENTINEL_MAIN_LOG}"
}

signals_for_session() {
    local session_id="$1"
    [[ -f "${SENTINEL_MAIN_LOG}" ]] || return 0

    awk -F'|' -v sid="$session_id" '
        $4 == sid && ($3 == "signal_command" || $3 == "signal_error" || $3 == "signal_note")
    ' "${SENTINEL_MAIN_LOG}"
}

count_signals_in_window() {
    local start_epoch="$1"
    local end_epoch="$2"
    local data
    local commands errors notes total

    data="$(signal_stream_in_window "$start_epoch" "$end_epoch")"

    commands="$(printf '%s\n' "$data" | awk -F'|' '$3=="signal_command"{c++} END{print c+0}')"
    errors="$(printf '%s\n' "$data" | awk -F'|' '$3=="signal_error"{c++} END{print c+0}')"
    notes="$(printf '%s\n' "$data" | awk -F'|' '$3=="signal_note"{c++} END{print c+0}')"
    total=$((commands + errors + notes))

    printf '%s|%s|%s|%s\n' "$commands" "$errors" "$notes" "$total"
}

count_signals_today() {
    local window start_epoch end_epoch
    window="$(window_today)"
    IFS='|' read -r start_epoch end_epoch <<< "$window"
    count_signals_in_window "$start_epoch" "$end_epoch"
}

count_signals_week() {
    local window start_epoch end_epoch
    window="$(window_last_7_days)"
    IFS='|' read -r start_epoch end_epoch <<< "$window"
    count_signals_in_window "$start_epoch" "$end_epoch"
}

count_signals_month() {
    local window start_epoch end_epoch
    window="$(window_last_30_days)"
    IFS='|' read -r start_epoch end_epoch <<< "$window"
    count_signals_in_window "$start_epoch" "$end_epoch"
}

mode_breakdown_in_window() {
    local start_epoch="$1"
    local end_epoch="$2"

    signal_stream_in_window "$start_epoch" "$end_epoch" | \
    awk -F'|' '
        NF { mode[$2]++ }
        END {
            for (m in mode) {
                printf "%s|%s\n", m, mode[m]
            }
        }
    ' | sort
}

session_metrics() {
    local session_id="$1"
    local file

    file="$(session_file_for_id "$session_id")"
    [[ -z "${file:-}" ]] && return 0

    local mode context_type context_value end_time
    local commands errors notes total noise productive

    mode="$(read_session_value "$file" "session_mode")"
    context_type="$(read_session_value "$file" "context_type")"
    context_value="$(read_session_value "$file" "context_value")"
    end_time="$(read_session_value "$file" "end_time")"

    commands="$(signals_for_session "$session_id" | awk -F'|' '$3=="signal_command"{c++} END{print c+0}')"
    errors="$(signals_for_session "$session_id" | awk -F'|' '$3=="signal_error"{c++} END{print c+0}')"
    notes="$(signals_for_session "$session_id" | awk -F'|' '$3=="signal_note"{c++} END{print c+0}')"
    total=$((commands + errors + notes))
    noise=$(( (errors * 5) + (notes * 2) + commands ))
    productive=$(( (commands * 3) + notes - (errors * 2) ))

    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$session_id" "$mode" "$context_type" "$context_value" "$end_time" \
        "$commands" "$errors" "$notes" "$total" "$noise" "$productive"
}

session_breakdown_in_window() {
    local start_epoch="$1"
    local end_epoch="$2"
    local session_id

    session_ids_in_window "$start_epoch" "$end_epoch" | while IFS= read -r session_id; do
        [[ -n "${session_id:-}" ]] && session_metrics "$session_id"
    done
}

daily_breakdown_in_window() {
    local start_epoch="$1"
    local end_epoch="$2"

    awk -F'|' -v start="$start_epoch" -v end="$end_epoch" '
        function to_epoch_wrap(cmd, result) {
            cmd | getline result
            close(cmd)
            return result + 0
        }
        {
            next
        }
    ' /dev/null >/dev/null 2>&1

    local days
    days="$(session_breakdown_in_window "$start_epoch" "$end_epoch")"

    if [[ -z "$days" ]]; then
        return 0
    fi

    while IFS='|' read -r session_id mode context_type context_value end_time commands errors notes total noise productive; do
        [[ -n "${end_time:-}" ]] || continue
        local day
        day="${end_time%% *}"
        printf '%s|%s|%s|%s|%s\n' "$day" "$commands" "$errors" "$notes" "$total"
    done <<< "$days" | \
    awk -F'|' '
        {
            day=$1
            sessions[day]++
            commands[day]+=$2
            errors[day]+=$3
            notes[day]+=$4
            total[day]+=$5
        }
        END {
            for (d in sessions) {
                printf "%s|%s|%s|%s|%s|%s\n",
                    d, sessions[d], commands[d], errors[d], notes[d], total[d]
            }
        }
    ' | sort
}

top_noisy_session_in_window() {
    local start_epoch="$1"
    local end_epoch="$2"

    session_breakdown_in_window "$start_epoch" "$end_epoch" | \
    awk -F'|' '
        NF {
            noise = $10
            if (!found || noise > best_noise) {
                best_noise = noise
                best = $0
                found = 1
            }
        }
        END {
            if (found) print best
        }
    '
}

top_productive_session_in_window() {
    local start_epoch="$1"
    local end_epoch="$2"

    session_breakdown_in_window "$start_epoch" "$end_epoch" | \
    awk -F'|' '
        NF {
            productive = $11
            if (!found || productive > best_productive) {
                best_productive = productive
                best = $0
                found = 1
            }
        }
        END {
            if (found) print best
        }
    '
}

recent_excerpts_in_window() {
    local start_epoch="$1"
    local end_epoch="$2"
    local limit="${3:-5}"

    signal_stream_in_window "$start_epoch" "$end_epoch" | tail -n "$limit"
}
