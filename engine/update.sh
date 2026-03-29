#!/usr/bin/env bash
set -u

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${ENGINE_DIR}/.." && pwd)"

# shellcheck source=../lib/paths.sh
source "${PROJECT_ROOT}/lib/paths.sh"
# shellcheck source=../lib/output.sh
source "${PROJECT_ROOT}/lib/output.sh"
# shellcheck source=../lib/logging.sh
source "${PROJECT_ROOT}/lib/logging.sh"

sentinel_ensure_directories
touch "${SENTINEL_MAIN_LOG}"

HOST_NAME="$(hostname 2>/dev/null || echo unknown-host)"
OPERATOR_USER="${USER:-unknown-user}"

print_divider() {
  printf '%s\n' "────────────────────────────────────────"
}

print_header() {
  echo "Sapphire Sentinel Update"
  print_divider
}

print_status() {
  local label="$1"
  local message="$2"
  printf '%-12s %s\n' "$label" "$message"
}

run_step() {
  local label="$1"
  shift
  echo
  print_divider
  echo "$label"
  print_divider
  "$@"
  return $?
}

AVAILABLE_MANAGERS=()
SKIPPED_MANAGERS=()
FAILED_MANAGERS=()
SUCCESS_MANAGERS=()
DEFERRED_MANAGERS=()
NOCHANGE_MANAGERS=()

APT_RESULT_STATUS=""
APT_RESULT_DETAILS=""

DNF_RESULT_STATUS=""
DNF_RESULT_DETAILS=""

PACMAN_RESULT_STATUS=""
PACMAN_RESULT_DETAILS=""

ZYPPER_RESULT_STATUS=""
ZYPPER_RESULT_DETAILS=""

FLATPAK_RESULT_STATUS=""
FLATPAK_RESULT_DETAILS=""

SNAP_RESULT_STATUS=""
SNAP_RESULT_DETAILS=""

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

join_by_comma() {
  local IFS=','
  printf '%s' "$*"
}

require_sudo() {
  if has_cmd sudo; then
    return 0
  fi

  echo "sudo is required for privileged package manager operations."
  sentinel_log_event "maintenance" "update_privilege" "sudo" "missing" \
    "sudo not installed but privileged update was required"
  return 1
}

detect_managers() {
  if has_cmd apt-get; then
    AVAILABLE_MANAGERS+=("apt")
    sentinel_log_event "maintenance" "update_detect" "apt" "available" \
      "apt-get detected on ${HOST_NAME}"
  else
    SKIPPED_MANAGERS+=("apt")
    sentinel_log_event "maintenance" "update_detect" "apt" "missing" \
      "apt-get not installed on ${HOST_NAME}"
  fi

  if has_cmd dnf; then
    AVAILABLE_MANAGERS+=("dnf")
    sentinel_log_event "maintenance" "update_detect" "dnf" "available" \
      "dnf detected on ${HOST_NAME}"
  else
    SKIPPED_MANAGERS+=("dnf")
    sentinel_log_event "maintenance" "update_detect" "dnf" "missing" \
      "dnf not installed on ${HOST_NAME}"
  fi

  if has_cmd pacman; then
    AVAILABLE_MANAGERS+=("pacman")
    sentinel_log_event "maintenance" "update_detect" "pacman" "available" \
      "pacman detected on ${HOST_NAME}"
  else
    SKIPPED_MANAGERS+=("pacman")
    sentinel_log_event "maintenance" "update_detect" "pacman" "missing" \
      "pacman not installed on ${HOST_NAME}"
  fi

  if has_cmd zypper; then
    AVAILABLE_MANAGERS+=("zypper")
    sentinel_log_event "maintenance" "update_detect" "zypper" "available" \
      "zypper detected on ${HOST_NAME}"
  else
    SKIPPED_MANAGERS+=("zypper")
    sentinel_log_event "maintenance" "update_detect" "zypper" "missing" \
      "zypper not installed on ${HOST_NAME}"
  fi

  if has_cmd flatpak; then
    AVAILABLE_MANAGERS+=("flatpak")
    sentinel_log_event "maintenance" "update_detect" "flatpak" "available" \
      "flatpak detected on ${HOST_NAME}"
  else
    SKIPPED_MANAGERS+=("flatpak")
    sentinel_log_event "maintenance" "update_detect" "flatpak" "missing" \
      "flatpak not installed on ${HOST_NAME}"
  fi

  if has_cmd snap; then
    AVAILABLE_MANAGERS+=("snap")
    sentinel_log_event "maintenance" "update_detect" "snap" "available" \
      "snap detected on ${HOST_NAME}"
  else
    SKIPPED_MANAGERS+=("snap")
    sentinel_log_event "maintenance" "update_detect" "snap" "missing" \
      "snap not installed on ${HOST_NAME}"
  fi
}

classify_apt_result() {
  local output="$1"
  local not_upgraded upgraded_count

  not_upgraded="$(
    grep -Eo '0 upgraded, [0-9]+ newly installed, [0-9]+ to remove and [0-9]+ not upgraded\.' <<< "$output" \
      | tail -n1 \
      | grep -Eo '[0-9]+ not upgraded' \
      | awk '{print $1}'
  )"

  upgraded_count="$(
    grep -E '^[0-9]+ upgraded,' <<< "$output" \
      | tail -n1 \
      | awk '{print $1}'
  )"

  if grep -qi 'deferred due to phasing' <<< "$output"; then
    APT_RESULT_STATUS="deferred"
    if [[ -n "${not_upgraded:-}" && "${not_upgraded:-0}" -gt 0 ]]; then
      APT_RESULT_DETAILS="${not_upgraded} package(s) deferred due to phasing"
    else
      APT_RESULT_DETAILS="updates deferred due to phasing"
    fi
    return 0
  fi

  if [[ -n "${upgraded_count:-}" && "${upgraded_count:-0}" -gt 0 ]]; then
    APT_RESULT_STATUS="updated"
    APT_RESULT_DETAILS="${upgraded_count} package(s) upgraded"
    return 0
  fi

  if grep -q '0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded\.' <<< "$output"; then
    APT_RESULT_STATUS="none"
    APT_RESULT_DETAILS="no apt updates were needed"
    return 0
  fi

  if [[ -n "${not_upgraded:-}" && "${not_upgraded:-0}" -gt 0 ]]; then
    APT_RESULT_STATUS="deferred"
    APT_RESULT_DETAILS="${not_upgraded} package(s) available but not upgraded"
    return 0
  fi

  if grep -q '0 upgraded,' <<< "$output"; then
    APT_RESULT_STATUS="none"
    APT_RESULT_DETAILS="apt-get ran successfully but no packages were upgraded"
    return 0
  fi

  APT_RESULT_STATUS="updated"
  APT_RESULT_DETAILS="apt-get full-upgrade completed"
  return 0
}

classify_dnf_result() {
  local output="$1"

  if grep -Eqi 'Nothing to do\.|No packages marked for upgrade\.' <<< "$output"; then
    DNF_RESULT_STATUS="none"
    DNF_RESULT_DETAILS="no dnf updates were needed"
    return 0
  fi

  DNF_RESULT_STATUS="updated"
  DNF_RESULT_DETAILS="dnf upgrade completed"
  return 0
}

classify_pacman_result() {
  local output="$1"

  if grep -qi ' there is nothing to do' <<< "$output"; then
    PACMAN_RESULT_STATUS="none"
    PACMAN_RESULT_DETAILS="no pacman updates were needed"
    return 0
  fi

  PACMAN_RESULT_STATUS="updated"
  PACMAN_RESULT_DETAILS="pacman -Syu completed"
  return 0
}

classify_zypper_result() {
  local output="$1"

  if grep -Eqi 'Nothing to do\.|No updates found\.' <<< "$output"; then
    ZYPPER_RESULT_STATUS="none"
    ZYPPER_RESULT_DETAILS="no zypper updates were needed"
    return 0
  fi

  ZYPPER_RESULT_STATUS="updated"
  ZYPPER_RESULT_DETAILS="zypper update completed"
  return 0
}

run_apt_updates() {
  sentinel_log_event "maintenance" "update_run" "apt" "started" \
    "running sudo apt-get update && sudo apt-get full-upgrade -y"

  if ! require_sudo; then
    APT_RESULT_STATUS="failed"
    APT_RESULT_DETAILS="sudo unavailable for apt operations"
    sentinel_log_event "maintenance" "update_run" "apt" "failed" "$APT_RESULT_DETAILS"
    return 1
  fi

  local tmp_update tmp_upgrade update_output upgrade_output combined_output
  tmp_update="$(mktemp)"
  tmp_upgrade="$(mktemp)"

  if ! sudo apt-get update 2>&1 | tee "$tmp_update"; then
    APT_RESULT_STATUS="failed"
    APT_RESULT_DETAILS="sudo apt-get update failed"
    sentinel_log_event "maintenance" "update_run" "apt" "failed" "$APT_RESULT_DETAILS"
    rm -f "$tmp_update" "$tmp_upgrade"
    return 1
  fi

  if ! sudo apt-get full-upgrade -y 2>&1 | tee "$tmp_upgrade"; then
    APT_RESULT_STATUS="failed"
    APT_RESULT_DETAILS="sudo apt-get full-upgrade -y failed"
    sentinel_log_event "maintenance" "update_run" "apt" "failed" "$APT_RESULT_DETAILS"
    rm -f "$tmp_update" "$tmp_upgrade"
    return 1
  fi

  update_output="$(cat "$tmp_update")"
  upgrade_output="$(cat "$tmp_upgrade")"
  combined_output="${update_output}"$'\n'"${upgrade_output}"

  classify_apt_result "$combined_output"
  sentinel_log_event "maintenance" "update_run" "apt" "$APT_RESULT_STATUS" "$APT_RESULT_DETAILS"

  rm -f "$tmp_update" "$tmp_upgrade"
  return 0
}

run_dnf_updates() {
  sentinel_log_event "maintenance" "update_run" "dnf" "started" \
    "running sudo dnf upgrade -y"

  if ! require_sudo; then
    DNF_RESULT_STATUS="failed"
    DNF_RESULT_DETAILS="sudo unavailable for dnf operations"
    sentinel_log_event "maintenance" "update_run" "dnf" "failed" "$DNF_RESULT_DETAILS"
    return 1
  fi

  local output status
  output="$(sudo dnf upgrade -y 2>&1)"
  status=$?
  printf '%s\n' "$output"

  if [[ $status -ne 0 ]]; then
    DNF_RESULT_STATUS="failed"
    DNF_RESULT_DETAILS="sudo dnf upgrade -y failed"
    sentinel_log_event "maintenance" "update_run" "dnf" "failed" "$DNF_RESULT_DETAILS"
    return 1
  fi

  classify_dnf_result "$output"
  sentinel_log_event "maintenance" "update_run" "dnf" "$DNF_RESULT_STATUS" "$DNF_RESULT_DETAILS"
  return 0
}

run_pacman_updates() {
  sentinel_log_event "maintenance" "update_run" "pacman" "started" \
    "running sudo pacman -Syu --noconfirm"

  if ! require_sudo; then
    PACMAN_RESULT_STATUS="failed"
    PACMAN_RESULT_DETAILS="sudo unavailable for pacman operations"
    sentinel_log_event "maintenance" "update_run" "pacman" "failed" "$PACMAN_RESULT_DETAILS"
    return 1
  fi

  local output status
  output="$(sudo pacman -Syu --noconfirm 2>&1)"
  status=$?
  printf '%s\n' "$output"

  if [[ $status -ne 0 ]]; then
    PACMAN_RESULT_STATUS="failed"
    PACMAN_RESULT_DETAILS="sudo pacman -Syu --noconfirm failed"
    sentinel_log_event "maintenance" "update_run" "pacman" "failed" "$PACMAN_RESULT_DETAILS"
    return 1
  fi

  classify_pacman_result "$output"
  sentinel_log_event "maintenance" "update_run" "pacman" "$PACMAN_RESULT_STATUS" "$PACMAN_RESULT_DETAILS"
  return 0
}

run_zypper_updates() {
  sentinel_log_event "maintenance" "update_run" "zypper" "started" \
    "running sudo zypper refresh && sudo zypper update -y"

  if ! require_sudo; then
    ZYPPER_RESULT_STATUS="failed"
    ZYPPER_RESULT_DETAILS="sudo unavailable for zypper operations"
    sentinel_log_event "maintenance" "update_run" "zypper" "failed" "$ZYPPER_RESULT_DETAILS"
    return 1
  fi

  local tmp_refresh tmp_update refresh_output update_output combined_output
  tmp_refresh="$(mktemp)"
  tmp_update="$(mktemp)"

  if ! sudo zypper refresh 2>&1 | tee "$tmp_refresh"; then
    ZYPPER_RESULT_STATUS="failed"
    ZYPPER_RESULT_DETAILS="sudo zypper refresh failed"
    sentinel_log_event "maintenance" "update_run" "zypper" "failed" "$ZYPPER_RESULT_DETAILS"
    rm -f "$tmp_refresh" "$tmp_update"
    return 1
  fi

  if ! sudo zypper update -y 2>&1 | tee "$tmp_update"; then
    ZYPPER_RESULT_STATUS="failed"
    ZYPPER_RESULT_DETAILS="sudo zypper update -y failed"
    sentinel_log_event "maintenance" "update_run" "zypper" "failed" "$ZYPPER_RESULT_DETAILS"
    rm -f "$tmp_refresh" "$tmp_update"
    return 1
  fi

  refresh_output="$(cat "$tmp_refresh")"
  update_output="$(cat "$tmp_update")"
  combined_output="${refresh_output}"$'\n'"${update_output}"

  classify_zypper_result "$combined_output"
  sentinel_log_event "maintenance" "update_run" "zypper" "$ZYPPER_RESULT_STATUS" "$ZYPPER_RESULT_DETAILS"

  rm -f "$tmp_refresh" "$tmp_update"
  return 0
}

run_flatpak_updates() {
  sentinel_log_event "maintenance" "update_run" "flatpak" "started" \
    "running flatpak update -y"

  local output status
  output="$(flatpak update -y 2>&1)"
  status=$?
  printf '%s\n' "$output"

  if [[ $status -ne 0 ]]; then
    FLATPAK_RESULT_STATUS="failed"
    FLATPAK_RESULT_DETAILS="flatpak update -y failed"
    sentinel_log_event "maintenance" "update_run" "flatpak" "failed" "$FLATPAK_RESULT_DETAILS"
    return 1
  fi

  if grep -qi 'Nothing to do\.' <<< "$output"; then
    FLATPAK_RESULT_STATUS="none"
    FLATPAK_RESULT_DETAILS="no flatpak updates were needed"
  else
    FLATPAK_RESULT_STATUS="updated"
    FLATPAK_RESULT_DETAILS="flatpak update -y completed"
  fi

  sentinel_log_event "maintenance" "update_run" "flatpak" "$FLATPAK_RESULT_STATUS" "$FLATPAK_RESULT_DETAILS"
  return 0
}

run_snap_updates() {
  sentinel_log_event "maintenance" "update_run" "snap" "started" \
    "running sudo snap refresh"

  if ! require_sudo; then
    SNAP_RESULT_STATUS="failed"
    SNAP_RESULT_DETAILS="sudo unavailable for snap operations"
    sentinel_log_event "maintenance" "update_run" "snap" "failed" "$SNAP_RESULT_DETAILS"
    return 1
  fi

  local output status
  output="$(sudo snap refresh 2>&1)"
  status=$?
  printf '%s\n' "$output"

  if [[ $status -ne 0 ]]; then
    SNAP_RESULT_STATUS="failed"
    SNAP_RESULT_DETAILS="sudo snap refresh failed"
    sentinel_log_event "maintenance" "update_run" "snap" "failed" "$SNAP_RESULT_DETAILS"
    return 1
  fi

  if grep -qi 'All snaps up to date\.' <<< "$output"; then
    SNAP_RESULT_STATUS="none"
    SNAP_RESULT_DETAILS="no snap updates were needed"
  else
    SNAP_RESULT_STATUS="updated"
    SNAP_RESULT_DETAILS="sudo snap refresh completed"
  fi

  sentinel_log_event "maintenance" "update_run" "snap" "$SNAP_RESULT_STATUS" "$SNAP_RESULT_DETAILS"
  return 0
}

run_manager() {
  local manager="$1"

  case "$manager" in
    apt)
      if run_step "APT system packages" run_apt_updates; then
        case "$APT_RESULT_STATUS" in
          updated)
            SUCCESS_MANAGERS+=("apt")
            print_status "[updated]" "$APT_RESULT_DETAILS"
            ;;
          deferred)
            DEFERRED_MANAGERS+=("apt")
            print_status "[deferred]" "$APT_RESULT_DETAILS"
            ;;
          none)
            NOCHANGE_MANAGERS+=("apt")
            print_status "[none]" "$APT_RESULT_DETAILS"
            ;;
          *)
            SUCCESS_MANAGERS+=("apt")
            print_status "[updated]" "apt-get full-upgrade completed"
            ;;
        esac
      else
        FAILED_MANAGERS+=("apt")
        print_status "[fail]" "${APT_RESULT_DETAILS:-apt-get updates failed}"
      fi
      ;;

    dnf)
      if run_step "DNF system packages" run_dnf_updates; then
        case "$DNF_RESULT_STATUS" in
          none)
            NOCHANGE_MANAGERS+=("dnf")
            print_status "[none]" "$DNF_RESULT_DETAILS"
            ;;
          updated)
            SUCCESS_MANAGERS+=("dnf")
            print_status "[updated]" "$DNF_RESULT_DETAILS"
            ;;
          *)
            SUCCESS_MANAGERS+=("dnf")
            print_status "[updated]" "dnf upgrade completed"
            ;;
        esac
      else
        FAILED_MANAGERS+=("dnf")
        print_status "[fail]" "${DNF_RESULT_DETAILS:-dnf updates failed}"
      fi
      ;;

    pacman)
      if run_step "Pacman system packages" run_pacman_updates; then
        case "$PACMAN_RESULT_STATUS" in
          none)
            NOCHANGE_MANAGERS+=("pacman")
            print_status "[none]" "$PACMAN_RESULT_DETAILS"
            ;;
          updated)
            SUCCESS_MANAGERS+=("pacman")
            print_status "[updated]" "$PACMAN_RESULT_DETAILS"
            ;;
          *)
            SUCCESS_MANAGERS+=("pacman")
            print_status "[updated]" "pacman -Syu completed"
            ;;
        esac
      else
        FAILED_MANAGERS+=("pacman")
        print_status "[fail]" "${PACMAN_RESULT_DETAILS:-pacman updates failed}"
      fi
      ;;

    zypper)
      if run_step "Zypper system packages" run_zypper_updates; then
        case "$ZYPPER_RESULT_STATUS" in
          none)
            NOCHANGE_MANAGERS+=("zypper")
            print_status "[none]" "$ZYPPER_RESULT_DETAILS"
            ;;
          updated)
            SUCCESS_MANAGERS+=("zypper")
            print_status "[updated]" "$ZYPPER_RESULT_DETAILS"
            ;;
          *)
            SUCCESS_MANAGERS+=("zypper")
            print_status "[updated]" "zypper update completed"
            ;;
        esac
      else
        FAILED_MANAGERS+=("zypper")
        print_status "[fail]" "${ZYPPER_RESULT_DETAILS:-zypper updates failed}"
      fi
      ;;

    flatpak)
      if run_step "Flatpak applications" run_flatpak_updates; then
        case "$FLATPAK_RESULT_STATUS" in
          none)
            NOCHANGE_MANAGERS+=("flatpak")
            print_status "[none]" "$FLATPAK_RESULT_DETAILS"
            ;;
          updated)
            SUCCESS_MANAGERS+=("flatpak")
            print_status "[updated]" "$FLATPAK_RESULT_DETAILS"
            ;;
          *)
            SUCCESS_MANAGERS+=("flatpak")
            print_status "[updated]" "flatpak updates completed"
            ;;
        esac
      else
        FAILED_MANAGERS+=("flatpak")
        print_status "[fail]" "${FLATPAK_RESULT_DETAILS:-flatpak updates failed}"
      fi
      ;;

    snap)
      if run_step "Snap packages" run_snap_updates; then
        case "$SNAP_RESULT_STATUS" in
          none)
            NOCHANGE_MANAGERS+=("snap")
            print_status "[none]" "$SNAP_RESULT_DETAILS"
            ;;
          updated)
            SUCCESS_MANAGERS+=("snap")
            print_status "[updated]" "$SNAP_RESULT_DETAILS"
            ;;
          *)
            SUCCESS_MANAGERS+=("snap")
            print_status "[updated]" "snap refresh completed"
            ;;
        esac
      else
        FAILED_MANAGERS+=("snap")
        print_status "[fail]" "${SNAP_RESULT_DETAILS:-snap refresh failed}"
      fi
      ;;
  esac
}

print_summary() {
  echo
  print_divider
  echo "Update Summary"
  print_divider

  if [[ "${#AVAILABLE_MANAGERS[@]}" -gt 0 ]]; then
    print_status "Detected:" "$(join_by_comma "${AVAILABLE_MANAGERS[@]}")"
  else
    print_status "Detected:" "none"
  fi

  if [[ "${#SUCCESS_MANAGERS[@]}" -gt 0 ]]; then
    print_status "Updated:" "$(join_by_comma "${SUCCESS_MANAGERS[@]}")"
  else
    print_status "Updated:" "none"
  fi

  if [[ "${#DEFERRED_MANAGERS[@]}" -gt 0 ]]; then
    print_status "Deferred:" "$(join_by_comma "${DEFERRED_MANAGERS[@]}")"
  else
    print_status "Deferred:" "none"
  fi

  if [[ "${#NOCHANGE_MANAGERS[@]}" -gt 0 ]]; then
    print_status "No change:" "$(join_by_comma "${NOCHANGE_MANAGERS[@]}")"
  else
    print_status "No change:" "none"
  fi

  if [[ "${#FAILED_MANAGERS[@]}" -gt 0 ]]; then
    print_status "Failed:" "$(join_by_comma "${FAILED_MANAGERS[@]}")"
  else
    print_status "Failed:" "none"
  fi

  if [[ "${#SKIPPED_MANAGERS[@]}" -gt 0 ]]; then
    print_status "Skipped:" "$(join_by_comma "${SKIPPED_MANAGERS[@]}")"
  else
    print_status "Skipped:" "none"
  fi
}

main() {
  print_header

  sentinel_log_event "maintenance" "update_start" "system" "started" \
    "sentinel update started by ${OPERATOR_USER} on ${HOST_NAME}"

  detect_managers

  if [[ "${#AVAILABLE_MANAGERS[@]}" -eq 0 ]]; then
    echo "No supported package managers were found."
    sentinel_log_event "maintenance" "update_complete" "system" "skipped" \
      "no supported package managers detected"
    exit 0
  fi

  echo "Detected package managers:"
  for manager in "${AVAILABLE_MANAGERS[@]}"; do
    printf ' - %s\n' "$manager"
  done

  if [[ "${#SKIPPED_MANAGERS[@]}" -gt 0 ]]; then
    echo
    echo "Missing package managers:"
    for manager in "${SKIPPED_MANAGERS[@]}"; do
      printf ' - %s\n' "$manager"
    done
  fi

  for manager in "${AVAILABLE_MANAGERS[@]}"; do
    run_manager "$manager"
  done

  print_summary

  sentinel_log_event "maintenance" "update_complete" "system" "finished" \
    "detected=$(join_by_comma "${AVAILABLE_MANAGERS[@]}"); updated=$(join_by_comma "${SUCCESS_MANAGERS[@]}"); deferred=$(join_by_comma "${DEFERRED_MANAGERS[@]}"); no_change=$(join_by_comma "${NOCHANGE_MANAGERS[@]}"); failed=$(join_by_comma "${FAILED_MANAGERS[@]}"); skipped=$(join_by_comma "${SKIPPED_MANAGERS[@]}")"

  if [[ "${#FAILED_MANAGERS[@]}" -gt 0 ]]; then
    exit 1
  fi

  exit 0
}

main "$@"
