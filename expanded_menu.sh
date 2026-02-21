#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPANDED_DIR="${SCRIPT_DIR}/expanded"

LOCK_FILE="/tmp/seeed-voicecard-expanded-menu.lock"
LOG_DIR_DEFAULT="${EXPANDED_DIR}/logs"
LOG_DIR=""

restore_terminal_state() {
    local tty_path

    tty_path="$(tty 2>/dev/null || true)"
    if [[ -n "$tty_path" && -r "$tty_path" ]]; then
        stty sane < "$tty_path" 2>/dev/null || true
        stty opost onlcr < "$tty_path" 2>/dev/null || true
        printf '\033[0m\033[?7h\033[?25h' > "$tty_path" 2>/dev/null || true
    else
        stty sane 2>/dev/null || true
        stty opost onlcr 2>/dev/null || true
        printf '\033[0m\033[?7h\033[?25h' 2>/dev/null || true
    fi
}

ensure_lock() {
    exec 9>"${LOCK_FILE}"
    if ! flock -n 9; then
        echo "Another expanded menu session is already running (lock: ${LOCK_FILE})." >&2
        exit 1
    fi
}

setup_log_dir() {
    mkdir -p "$LOG_DIR_DEFAULT"
    LOG_DIR="$LOG_DIR_DEFAULT"
}

update_latest_log_links() {
    local action_name="$1"
    local log_file="$2"

    ln -sfn "$log_file" "${LOG_DIR}/latest.log"
    ln -sfn "$log_file" "${LOG_DIR}/latest-${action_name}.log"
}

ui_msg() {
    local title="$1"
    local message="$2"

    restore_terminal_state
    echo
    echo "=== ${title} ==="
    printf '%b\n' "$message"
    echo
}

ui_yesno() {
    local title="$1"
    local message="$2"
    local reply

    restore_terminal_state
    read -r -p "${title}: ${message} [y/N]: " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

menu_select() {
    local title="$1"
    local prompt="$2"
    local allow_cancel="${3:-1}"
    shift 3
    local options=("$@")
    local choice
    local idx label

    restore_terminal_state
    while true; do
        echo >&2
        echo "=== ${title} ===" >&2
        echo "$prompt" >&2
        idx=0
        while [[ $idx -lt ${#options[@]} ]]; do
            label="${options[$idx]}"
            echo "${label}) ${options[$((idx + 1))]}" >&2
            idx=$((idx + 2))
        done
        if [[ "$allow_cancel" -eq 1 ]]; then
            echo "q) Cancel" >&2
        fi
        read -r -p "Select: " choice

        if [[ -z "$choice" ]]; then
            if [[ "$allow_cancel" -eq 1 ]]; then
                return 1
            fi
            echo "Invalid selection: ${choice}" >&2
            continue
        fi

        if [[ "$allow_cancel" -eq 1 && ( "$choice" == "q" || "$choice" == "Q" ) ]]; then
            return 1
        fi

        idx=0
        while [[ $idx -lt ${#options[@]} ]]; do
            if [[ "$choice" == "${options[$idx]}" ]]; then
                echo "$choice"
                return 0
            fi
            idx=$((idx + 2))
        done

        echo "Invalid selection: ${choice}" >&2
    done
}

ensure_sudo_if_needed() {
    if [[ ${EUID} -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
        ui_msg "Missing sudo" "This wrapper is not running as root and sudo is unavailable.\n\nRun with sudo or install sudo first."
        return 1
    fi
    return 0
}

has_conflicting_process() {
    local patterns=(
        "expanded/exp_install.sh"
        "expanded/exp_uninstall.sh"
        "expanded/exp_diagnostics_and_tests.sh"
        "expanded/exp_post_install_smoke_test.sh"
        "expanded/exp_doctor.sh"
    )
    local pat

    for pat in "${patterns[@]}"; do
        if pgrep -f "$pat" >/dev/null 2>&1; then
            return 0
        fi
    done

    return 1
}

show_conflict_message() {
    ui_msg "Execution Blocked" "Another expanded install/uninstall/diagnostic process is already running.\n\nWait for it to finish, then try again."
}

run_action() {
    local action_name="$1"
    shift
    local cmd=("$@")
    local timestamp
    local log_file
    local status
    local verdict
    local pass_count warn_count fail_count
    local summary

    timestamp="$(date +%Y%m%d-%H%M%S)"
    log_file="${LOG_DIR}/${timestamp}-${action_name}.log"
    update_latest_log_links "$action_name" "$log_file"

    restore_terminal_state
    clear
    echo "Running action: ${action_name}"
    echo "Log file: ${log_file}"
    echo "Command: ${cmd[*]}"
    echo

    set +e
    {
        echo "[INFO] Action: ${action_name}"
        echo "[INFO] Timestamp: $(date -Iseconds)"
        echo "[INFO] Command: ${cmd[*]}"
        echo
        "${cmd[@]}"
    } 2>&1 | tee -a "$log_file"
    status=${PIPESTATUS[0]}
    set -e
    restore_terminal_state

    echo "[INFO] Exit code: ${status}" | tee -a "$log_file" >/dev/null

    verdict="$(grep -E 'Verdict:[[:space:]]*(PASS|WARN|FAIL)' "$log_file" | tail -n 1 | awk -F'Verdict:[[:space:]]*' '{print $2}' | tr -d '\r')"
    if [[ -z "$verdict" ]]; then
        if [[ "$status" -eq 0 ]]; then
            verdict="PASS"
        else
            verdict="FAIL"
        fi
    fi

    pass_count="$(grep -c '^\[PASS\]' "$log_file" 2>/dev/null || true)"
    warn_count="$(grep -c '^\[WARN\]' "$log_file" 2>/dev/null || true)"
    fail_count="$(grep -c '^\[FAIL\]' "$log_file" 2>/dev/null || true)"

    summary="Action: ${action_name}
Verdict: ${verdict}
Exit code: ${status}
PASS lines: ${pass_count}
WARN lines: ${warn_count}
FAIL lines: ${fail_count}

Log: ${log_file}"

    if grep -q '^Recommended Next Actions' "$log_file"; then
        summary+="

The log contains Recommended Next Actions."
    fi

    ui_msg "Action Complete" "$summary"
}

run_action_pty() {
    local action_name="$1"
    shift
    local cmd=("$@")
    local timestamp
    local log_file
    local status
    local verdict
    local pass_count warn_count fail_count
    local summary
    local cmd_escaped

    timestamp="$(date +%Y%m%d-%H%M%S)"
    log_file="${LOG_DIR}/${timestamp}-${action_name}.log"
    update_latest_log_links "$action_name" "$log_file"

    restore_terminal_state
    clear
    echo "Running action: ${action_name}"
    echo "Log file: ${log_file}"
    echo "Command: ${cmd[*]}"
    echo

    {
        echo "[INFO] Action: ${action_name}"
        echo "[INFO] Timestamp: $(date -Iseconds)"
        echo "[INFO] Command: ${cmd[*]}"
        echo
    } >> "$log_file"

    set +e
    if command -v script >/dev/null 2>&1; then
        printf -v cmd_escaped '%q ' "${cmd[@]}"
        script -qefc "$cmd_escaped" "$log_file"
        status=$?
    else
        {
            "${cmd[@]}"
        } 2>&1 | tee -a "$log_file"
        status=${PIPESTATUS[0]}
    fi
    set -e
    restore_terminal_state

    echo "[INFO] Exit code: ${status}" | tee -a "$log_file" >/dev/null

    verdict="$(grep -E 'Verdict:[[:space:]]*(PASS|WARN|FAIL)' "$log_file" | tail -n 1 | awk -F'Verdict:[[:space:]]*' '{print $2}' | tr -d '\r')"
    if [[ -z "$verdict" ]]; then
        if [[ "$status" -eq 0 ]]; then
            verdict="PASS"
        else
            verdict="FAIL"
        fi
    fi

    pass_count="$(grep -c '^\[PASS\]' "$log_file" 2>/dev/null || true)"
    warn_count="$(grep -c '^\[WARN\]' "$log_file" 2>/dev/null || true)"
    fail_count="$(grep -c '^\[FAIL\]' "$log_file" 2>/dev/null || true)"

    summary="Action: ${action_name}
Verdict: ${verdict}
Exit code: ${status}
PASS lines: ${pass_count}
WARN lines: ${warn_count}
FAIL lines: ${fail_count}

Log: ${log_file}"

    if grep -q '^Recommended Next Actions' "$log_file"; then
        summary+="

The log contains Recommended Next Actions."
    fi

    ui_msg "Action Complete" "$summary"
}

run_script_action() {
    local action_name="$1"
    local script_path="$2"
    shift 2
    local cmd=("$script_path" "$@")

    if [[ ${EUID} -ne 0 ]]; then
        cmd=(sudo "${cmd[@]}")
    fi

    run_action "$action_name" "${cmd[@]}"
}

run_script_action_pty() {
    local action_name="$1"
    local script_path="$2"
    shift 2
    local cmd=("$script_path" "$@")

    if [[ ${EUID} -ne 0 ]]; then
        cmd=(sudo "${cmd[@]}")
    fi

    run_action_pty "$action_name" "${cmd[@]}"
}

run_install_guided() {
    if ! ensure_sudo_if_needed; then
        return
    fi
    if has_conflicting_process; then
        show_conflict_message
        return
    fi
    run_script_action_pty "install-guided" "${EXPANDED_DIR}/exp_install.sh"
}

run_install_quick() {
    local model
    local update_mode
    local validation_mode
    local reboot_now="0"
    local cmd_args=(--yes)

    if ! ensure_sudo_if_needed; then
        return
    fi
    if has_conflicting_process; then
        show_conflict_message
        return
    fi

    model="$(menu_select "Quick Install" "Select microphone model" \
        "2" "2-Mic HAT" \
        "4" "4-Mic HAT" \
        "6" "6-Mic Circular" \
        "8" "8-Mic Circular")" || return

    update_mode="$(menu_select "Quick Install" "Select update mode" \
        "none" "No package update" \
        "update" "apt update only" \
        "upgrade" "apt update + upgrade" \
        "full-upgrade" "apt update + full-upgrade")" || return

    validation_mode="$(menu_select "Quick Install" "Post-install validation" \
        "none" "No automatic validation" \
        "smoke" "Run smoke test" \
        "doctor" "Run full doctor workflow")" || return

    if ui_yesno "Quick Install" "Reboot automatically after install?"; then
        reboot_now="1"
    fi

    cmd_args+=(--model "$model" --update-mode "$update_mode")

    case "$validation_mode" in
        smoke)
            cmd_args+=(--run-smoke-test)
            ;;
        doctor)
            cmd_args+=(--run-doctor)
            ;;
    esac

    if [[ "$reboot_now" == "1" ]]; then
        cmd_args+=(--reboot)
    fi

    run_script_action_pty "install-quick" "${EXPANDED_DIR}/exp_install.sh" "${cmd_args[@]}"
}

run_uninstall() {
    if ! ensure_sudo_if_needed; then
        return
    fi
    if has_conflicting_process; then
        show_conflict_message
        return
    fi

    if ! ui_yesno "Confirm Uninstall" "Proceed with full uninstall?"; then
        return
    fi

    run_script_action_pty "uninstall" "${EXPANDED_DIR}/exp_uninstall.sh"
}

run_diagnostics() {
    if ! ensure_sudo_if_needed; then
        return
    fi
    if has_conflicting_process; then
        show_conflict_message
        return
    fi
    run_script_action_pty "diagnostics" "${EXPANDED_DIR}/exp_diagnostics_and_tests.sh"
}

run_smoke_test() {
    if ! ensure_sudo_if_needed; then
        return
    fi
    if has_conflicting_process; then
        show_conflict_message
        return
    fi
    run_script_action_pty "smoke-test" "${EXPANDED_DIR}/exp_post_install_smoke_test.sh"
}

run_doctor() {
    if ! ensure_sudo_if_needed; then
        return
    fi
    if has_conflicting_process; then
        show_conflict_message
        return
    fi
    run_script_action_pty "doctor" "${EXPANDED_DIR}/exp_doctor.sh"
}

main_menu_choice() {
    menu_select "Seeed Voicecard CLI" "Choose an action" 0 \
        "1" "Install (guided prompts)" \
        "2" "Uninstall" \
        "3" "Diagnostics and Tests" \
        "4" "Post-install Smoke Test" \
        "5" "Doctor (Auto Configure + Validate)" \
        "6" "Exit"
}

usage() {
    cat <<'USAGE'
Usage: expanded_menu.sh [command]

Commands:
  menu            Open interactive terminal menu (default)
  install-guided  Run guided install
  install-quick   Run quick install prompts
  uninstall       Run uninstall
  diagnostics     Run diagnostics and tests
  smoke-test      Run post-install smoke test
  doctor          Run doctor workflow
  help            Show this help
USAGE
}

run_command() {
    local cmd="${1:-menu}"
    case "$cmd" in
        menu)
            return 10
            ;;
        install-guided)
            run_install_guided
            ;;
        install-quick)
            run_install_quick
            ;;
        uninstall)
            run_uninstall
            ;;
        diagnostics)
            run_diagnostics
            ;;
        smoke-test)
            run_smoke_test
            ;;
        doctor)
            run_doctor
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            echo "Unknown command: ${cmd}" >&2
            usage
            return 1
            ;;
    esac
}

main() {
    local rc

    chmod +x "${EXPANDED_DIR}"/*.sh

    trap restore_terminal_state EXIT INT TERM

    ensure_lock
    setup_log_dir

    if [[ $# -gt 0 ]]; then
        if run_command "$1"; then
            return 0
        fi
        rc=$?
        if [[ "$rc" -ne 10 ]]; then
            return 1
        fi
    fi

    while true; do
        local choice
        choice="$(main_menu_choice)" || break

        case "$choice" in
            1) run_install_guided ;;
            2) run_uninstall ;;
            3) run_diagnostics ;;
            4) run_smoke_test ;;
            5) run_doctor ;;
            6) break ;;
            *) ui_msg "Invalid" "Invalid option selected." ;;
        esac
    done
}

main "$@"
