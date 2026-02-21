#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OVERLAYS=""
CONFIG=""
REPORT_FILE=""
QUIET=0

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

FAIL_DETAILS=()
WARN_DETAILS=()
ACTION_ITEMS=()

log() {
    [[ "$QUIET" -eq 1 ]] && return 0
    echo "$*"
}

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    log "[PASS] $*"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_DETAILS+=("$*")
    log "[FAIL] $*"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    WARN_DETAILS+=("$*")
    log "[WARN] $*"
}

add_action() {
    ACTION_ITEMS+=("$*")
}

usage() {
    cat <<'USAGE'
Usage: exp_post_install_smoke_test.sh [options]

Options:
  --report-file <path>   Write report output to this file
  --quiet                Reduce console output
  -h, --help             Show this help
USAGE
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --report-file)
                [[ $# -ge 2 ]] || { echo "Missing value for --report-file" >&2; exit 1; }
                REPORT_FILE="$2"
                shift 2
                ;;
            --quiet)
                QUIET=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
}

require_root() {
    if [[ ${EUID} -ne 0 ]]; then
        echo "[ERROR] This script must be run as root (use sudo)." >&2
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_boot_paths() {
    OVERLAYS="/boot/overlays"
    [[ -d /boot/firmware/overlays ]] && OVERLAYS="/boot/firmware/overlays"

    if [[ -f /boot/firmware/usercfg.txt ]]; then
        CONFIG="/boot/firmware/usercfg.txt"
    elif [[ -f /boot/firmware/config.txt ]]; then
        CONFIG="/boot/firmware/config.txt"
    elif [[ -f /boot/config.txt ]]; then
        CONFIG="/boot/config.txt"
    else
        echo "[ERROR] Could not locate Raspberry Pi config file." >&2
        exit 1
    fi
}

detect_seeed_card() {
    local line

    if ! command_exists arecord; then
        return 1
    fi

    line="$(arecord -l 2>/dev/null | awk '/^card [0-9]+:/{if (tolower($0) ~ /seeed|respeaker|voicecard/) {print; exit}}')"
    [[ -n "$line" ]] || return 1

    echo "$line" | sed -E 's/^card ([0-9]+):.*/\1/'
}

playback_busy_pids() {
    local card="$1"
    local dev="/dev/snd/pcmC${card}D0p"

    [[ -e "$dev" ]] || return 0
    command_exists fuser || return 0

    fuser "$dev" 2>/dev/null | tr -s '[:space:]' ' ' | sed -E 's/^ +//; s/ +$//'
}

capture_busy_pids() {
    local card="$1"
    local dev="/dev/snd/pcmC${card}D0c"

    [[ -e "$dev" ]] || return 0
    command_exists fuser || return 0

    fuser "$dev" 2>/dev/null | tr -s '[:space:]' ' ' | sed -E 's/^ +//; s/ +$//'
}

report_playback_busy() {
    local card="$1"
    local pids="$2"
    local dev="/dev/snd/pcmC${card}D0p"
    local pid
    local info

    [[ -n "$pids" ]] || return 0
    warn "Playback device busy: ${dev} (PID(s): ${pids})"

    if command_exists ps; then
        for pid in $pids; do
            info="$(ps -p "$pid" -o pid=,user=,cmd= 2>/dev/null | sed -E 's/^ +//; s/ +/ /g')"
            [[ -n "$info" ]] && warn "Holder: ${info}"
        done
    fi

    add_action "Stop process(es) using ${dev}, then rerun smoke test"
    add_action "Find holders: sudo fuser -v ${dev}"
}

report_capture_busy() {
    local card="$1"
    local pids="$2"
    local dev="/dev/snd/pcmC${card}D0c"
    local pid
    local info

    [[ -n "$pids" ]] || return 0
    warn "Capture device busy: ${dev} (PID(s): ${pids})"

    if command_exists ps; then
        for pid in $pids; do
            info="$(ps -p "$pid" -o pid=,user=,cmd= 2>/dev/null | sed -E 's/^ +//; s/ +/ /g')"
            [[ -n "$info" ]] && warn "Holder: ${info}"
        done
    fi

    add_action "Stop process(es) using ${dev}, then rerun smoke test"
    add_action "Find holders: sudo fuser -v ${dev}"
}

setup_report() {
    local default_dir

    if [[ -n "$REPORT_FILE" ]]; then
        mkdir -p "$(dirname "$REPORT_FILE")"
    else
        default_dir="${SCRIPT_DIR}/logs"
        mkdir -p "$default_dir"
        REPORT_FILE="${default_dir}/$(date +%Y%m%d-%H%M%S)-smoke-test.log"
    fi

    # Keep a stable pointer to the newest smoke test report.
    ln -sfn "$REPORT_FILE" "$(dirname "$REPORT_FILE")/latest-smoke-test.log"
    ln -sfn "$REPORT_FILE" "$(dirname "$REPORT_FILE")/latest.log"

    exec > >(tee -a "$REPORT_FILE") 2>&1
}

check_file_paths() {
    [[ -x /usr/bin/seeed-voicecard ]] && pass "/usr/bin/seeed-voicecard exists and is executable" || {
        fail "/usr/bin/seeed-voicecard missing or not executable"
        add_action "Re-run installer: sudo ./expanded/exp_install.sh"
    }

    [[ -f /lib/systemd/system/seeed-voicecard.service ]] && pass "Systemd unit file is present" || {
        fail "Systemd unit file is missing"
        add_action "Re-run installer to reinstall systemd unit"
    }

    [[ -d /etc/voicecard ]] && pass "/etc/voicecard exists" || {
        fail "/etc/voicecard missing"
        add_action "Re-run installer to restore /etc/voicecard"
    }
}

check_config_entries() {
    if grep -qxF "dtoverlay=i2s-mmap" "$CONFIG"; then
        pass "dtoverlay=i2s-mmap is set in ${CONFIG}"
    else
        fail "dtoverlay=i2s-mmap not found in ${CONFIG}"
        add_action "Add dtoverlay=i2s-mmap to ${CONFIG} and reboot"
    fi

    if grep -qxF "dtparam=i2s=on" "$CONFIG"; then
        pass "dtparam=i2s=on is set in ${CONFIG}"
    else
        fail "dtparam=i2s=on not found in ${CONFIG}"
        add_action "Add dtparam=i2s=on to ${CONFIG} and reboot"
    fi
}

selected_overlay_from_config() {
    grep -E '^dtoverlay=seeed-(2|4|6|8)mic-voicecard$' "$CONFIG" 2>/dev/null | head -n 1 | cut -d'=' -f2
}

check_overlay_state() {
    local selected_overlay
    local overlay_count

    selected_overlay="$(selected_overlay_from_config)"
    overlay_count="$(grep -E '^dtoverlay=seeed-(2|4|6|8)mic-voicecard$' "$CONFIG" 2>/dev/null | wc -l)"

    if [[ "$overlay_count" -eq 1 ]]; then
        pass "Exactly one Seeed overlay is selected in ${CONFIG}: ${selected_overlay}"
    elif [[ "$overlay_count" -eq 0 ]]; then
        fail "No Seeed overlay selected in ${CONFIG}"
        add_action "Set one overlay in ${CONFIG}, e.g. dtoverlay=seeed-2mic-voicecard"
    else
        fail "Multiple Seeed overlays found in ${CONFIG}"
        add_action "Keep only one dtoverlay=seeed-*-voicecard line in ${CONFIG}"
    fi

    if [[ -n "$selected_overlay" ]]; then
        if [[ -f "${OVERLAYS}/${selected_overlay}.dtbo" ]]; then
            pass "Selected overlay file exists: ${OVERLAYS}/${selected_overlay}.dtbo"
        else
            fail "Selected overlay file missing: ${OVERLAYS}/${selected_overlay}.dtbo"
            add_action "Run: sudo ./builddtbo.sh and reinstall"
        fi
    fi
}

check_modules_config() {
    local module

    for module in snd-soc-seeed-voicecard snd-soc-ac108 snd-soc-wm8960; do
        if grep -qxF "$module" /etc/modules 2>/dev/null; then
            pass "${module} is listed in /etc/modules"
        else
            fail "${module} is not listed in /etc/modules"
            add_action "Add ${module} to /etc/modules or re-run installer"
        fi
    done
}

check_service_state() {
    if ! command_exists systemctl; then
        warn "systemctl not found; skipping service checks"
        return
    fi

    if systemctl is-enabled seeed-voicecard.service >/dev/null 2>&1; then
        pass "seeed-voicecard.service is enabled"
    else
        fail "seeed-voicecard.service is not enabled"
        add_action "Enable service: sudo systemctl enable seeed-voicecard.service"
    fi

    if systemctl is-active seeed-voicecard.service >/dev/null 2>&1; then
        pass "seeed-voicecard.service is active"
    else
        warn "seeed-voicecard.service is not active right now"
        add_action "Start service: sudo systemctl restart seeed-voicecard.service"
    fi
}

check_loaded_modules() {
    local miss=0
    local module

    for module in snd_soc_seeed_voicecard snd_soc_ac108 snd_soc_wm8960; do
        if lsmod | grep -q "^${module}\\b"; then
            pass "Kernel module loaded: ${module}"
        else
            warn "Kernel module not currently loaded: ${module}"
            miss=1
        fi
    done

    if [[ "$miss" -eq 1 ]]; then
        add_action "Run: sudo modprobe snd_soc_wm8960 snd_soc_ac108 snd_soc_seeed_voicecard"
        add_action "If modules still do not load, reboot and re-run this smoke test"
    fi
}

check_alsa_visibility() {
    if ! command_exists arecord; then
        fail "arecord not installed; cannot verify ALSA capture"
        add_action "Install alsa-utils: sudo apt-get install -y alsa-utils"
        return
    fi

    if arecord -l 2>/dev/null | grep -Ei 'seeed|respeaker|voicecard' >/dev/null; then
        pass "ALSA capture device for Seeed/ReSpeaker is visible"
    else
        fail "No Seeed/ReSpeaker capture device found in arecord -l"
        add_action "Check ribbon/header wiring and reboot after install"
    fi

    if command_exists aplay; then
        if aplay -l >/dev/null 2>&1; then
            pass "ALSA playback listing works (aplay -l)"
        else
            warn "aplay -l failed"
            add_action "Check ALSA playback device configuration"
        fi
    else
        warn "aplay not installed"
        add_action "Install alsa-utils: sudo apt-get install -y alsa-utils"
    fi
}

check_record_playback_smoke() {
    local card
    local file="/tmp/seeed-smoke-record.wav"
    local pids
    local rec_err=""
    local play_err=""

    if ! command_exists arecord || ! command_exists aplay; then
        fail "arecord/aplay missing; cannot run record/playback smoke test"
        add_action "Install alsa-utils and re-run smoke test"
        return
    fi

    card="$(detect_seeed_card || true)"
    if [[ -z "$card" ]]; then
        fail "Cannot identify Seeed card for record/playback smoke test"
        add_action "Check arecord -l output and verify device detection"
        return
    fi

    log "[INFO] Running short recording smoke test on plughw:${card},0"
    if rec_err="$(arecord -D "plughw:${card},0" -f S16_LE -r 16000 -d 1 -c 2 "$file" 2>&1 >/dev/null)"; then
        pass "Short audio recording completed"
    else
        pids="$(capture_busy_pids "$card" || true)"
        if [[ -n "$pids" || "$rec_err" == *"Device or resource busy"* ]]; then
            warn "Short audio recording skipped: capture device is busy"
            report_capture_busy "$card" "$pids"
            [[ -n "$rec_err" ]] && warn "arecord error: ${rec_err}"
            rm -f "$file"
            return
        fi

        fail "Short audio recording failed"
        [[ -n "$rec_err" ]] && warn "arecord error: ${rec_err}"
        add_action "Run doctor workflow: sudo ./expanded/exp_doctor.sh"
        rm -f "$file"
        return
    fi

    log "[INFO] Running short playback smoke test on plughw:${card},0"
    if play_err="$(aplay -D "plughw:${card},0" "$file" 2>&1 >/dev/null)"; then
        pass "Short audio playback completed"
    else
        pids="$(playback_busy_pids "$card" || true)"
        if [[ -n "$pids" || "$play_err" == *"Device or resource busy"* ]]; then
            warn "Short audio playback skipped: playback device is busy"
            report_playback_busy "$card" "$pids"
            [[ -n "$play_err" ]] && warn "aplay error: ${play_err}"
        else
            fail "Short audio playback failed"
            [[ -n "$play_err" ]] && warn "aplay error: ${play_err}"
            add_action "Check playback output route and mixer levels for plughw:${card},0"
        fi
    fi

    rm -f "$file"
}

print_actions() {
    local item
    local seen=""

    if (( ${#ACTION_ITEMS[@]} == 0 )); then
        return
    fi

    echo
    echo "Recommended Next Actions"
    for item in "${ACTION_ITEMS[@]}"; do
        if [[ " $seen " == *"|$item|"* ]]; then
            continue
        fi
        seen+="|$item|"
        echo "- $item"
    done
}

summary_and_exit() {
    local verdict

    if [[ "$FAIL_COUNT" -gt 0 ]]; then
        verdict="FAIL"
    elif [[ "$WARN_COUNT" -gt 0 ]]; then
        verdict="WARN"
    else
        verdict="PASS"
    fi

    echo
    echo "Smoke Test Summary"
    echo "  Pass: ${PASS_COUNT}"
    echo "  Warn: ${WARN_COUNT}"
    echo "  Fail: ${FAIL_COUNT}"
    echo "  Verdict: ${verdict}"

    if (( ${#FAIL_DETAILS[@]} > 0 )); then
        echo
        echo "Failed Checks"
        printf -- '- %s\n' "${FAIL_DETAILS[@]}"
    fi

    if (( ${#WARN_DETAILS[@]} > 0 )); then
        echo
        echo "Warnings"
        printf -- '- %s\n' "${WARN_DETAILS[@]}"
    fi

    print_actions

    echo
    echo "Report written to: ${REPORT_FILE}"

    if [[ "$FAIL_COUNT" -gt 0 ]]; then
        exit 1
    fi

    exit 0
}

main() {
    parse_args "$@"
    require_root
    detect_boot_paths
    setup_report

    echo "Running Seeed post-install smoke test"
    echo "Timestamp: $(date -Iseconds)"
    echo "Using config: ${CONFIG}"
    echo "Using overlays dir: ${OVERLAYS}"
    echo

    check_file_paths
    check_config_entries
    check_overlay_state
    check_modules_config
    check_service_state
    check_loaded_modules
    check_alsa_visibility
    check_record_playback_smoke

    summary_and_exit
}

main "$@"
