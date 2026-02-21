#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OVERLAYS=""
CONFIG=""
REPORT_FILE=""
NON_INTERACTIVE=0
APPLY_PROFILE=1
SKIP_SMOKE=0

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

BEST_MODEL=""
BEST_PROFILE_CONF=""
BEST_PROFILE_STATE=""
BEST_RATE=""
BEST_FORMAT=""
BEST_CHANNELS=""
DETECTED_CARD=""

PASS_ITEMS=()
WARN_ITEMS=()
FAIL_ITEMS=()
ACTION_ITEMS=()

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    PASS_ITEMS+=("$*")
    echo "[PASS] $*"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    WARN_ITEMS+=("$*")
    echo "[WARN] $*"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_ITEMS+=("$*")
    echo "[FAIL] $*"
}

add_action() {
    ACTION_ITEMS+=("$*")
}

usage() {
    cat <<'USAGE'
Usage: exp_doctor.sh [options]

Options:
  -y, --yes             Non-interactive mode (no prompts)
      --no-apply        Do not apply recommended ALSA profile
      --skip-smoke      Skip baseline/final smoke tests
      --report-file P   Write report to path P
  -h, --help            Show this help
USAGE
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes|--non-interactive)
                NON_INTERACTIVE=1
                shift
                ;;
            --no-apply)
                APPLY_PROFILE=0
                shift
                ;;
            --skip-smoke)
                SKIP_SMOKE=1
                shift
                ;;
            --report-file)
                [[ $# -ge 2 ]] || { echo "Missing value for --report-file" >&2; exit 1; }
                REPORT_FILE="$2"
                shift 2
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

setup_report() {
    local report_dir

    if [[ -n "$REPORT_FILE" ]]; then
        mkdir -p "$(dirname "$REPORT_FILE")"
    else
        report_dir="${SCRIPT_DIR}/logs"
        mkdir -p "$report_dir"
        REPORT_FILE="${report_dir}/$(date +%Y%m%d-%H%M%S)-doctor.log"
    fi

    # Keep a stable pointer to the newest doctor report.
    ln -sfn "$REPORT_FILE" "$(dirname "$REPORT_FILE")/latest-doctor.log"
    ln -sfn "$REPORT_FILE" "$(dirname "$REPORT_FILE")/latest.log"

    exec > >(tee -a "$REPORT_FILE") 2>&1
}

selected_overlay_from_config() {
    grep -E '^dtoverlay=seeed-(2|4|6|8)mic-voicecard$' "$CONFIG" 2>/dev/null | head -n 1 | cut -d'=' -f2
}

detect_card_number() {
    local line

    if ! command_exists arecord; then
        return 1
    fi

    line="$(arecord -l 2>/dev/null | awk '/^card [0-9]+:/{if (tolower($0) ~ /seeed|respeaker|voicecard/) {print; exit}}')"
    [[ -n "$line" ]] || return 1

    echo "$line" | sed -E 's/^card ([0-9]+):.*/\1/'
}

capture_busy_pids() {
    local card="$1"
    local dev="/dev/snd/pcmC${card}D0c"

    [[ -e "$dev" ]] || return 0
    command_exists fuser || return 0

    fuser "$dev" 2>/dev/null | tr -s '[:space:]' ' ' | sed -E 's/^ +//; s/ +$//'
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

    add_action "Stop process(es) using ${dev}, then rerun doctor"
    add_action "Find holders: sudo fuser -v ${dev}"
}

get_capture_channel_max() {
    local card="$1"
    local params
    local max_channels

    params="$(arecord -D "plughw:${card},0" --dump-hw-params -d 1 /dev/null 2>&1 || true)"
    max_channels="$(echo "$params" | sed -n -E 's/.*CHANNELS:[[:space:]]*\[[0-9]+[[:space:]]+([0-9]+)\].*/\1/p' | head -n 1)"

    if [[ -z "$max_channels" ]]; then
        max_channels="$(echo "$params" | sed -n -E 's/.*channels:[[:space:]]*([0-9]+).*/\1/p' | head -n 1)"
    fi

    [[ -n "$max_channels" ]] || max_channels="2"
    echo "$max_channels"
}

recommend_profile() {
    local overlay

    overlay="$(selected_overlay_from_config)"
    if [[ -z "$overlay" ]]; then
        warn "No explicit Seeed overlay found in ${CONFIG}; defaulting to 2-mic profile"
        overlay="seeed-2mic-voicecard"
    fi

    case "$overlay" in
        seeed-2mic-voicecard)
            BEST_MODEL="2"
            BEST_PROFILE_CONF="/etc/voicecard/asound_2mic.conf"
            BEST_PROFILE_STATE="/etc/voicecard/wm8960_asound.state"
            ;;
        seeed-4mic-voicecard)
            BEST_MODEL="4"
            BEST_PROFILE_CONF="/etc/voicecard/asound_4mic.conf"
            BEST_PROFILE_STATE="/etc/voicecard/ac108_asound.state"
            ;;
        seeed-6mic-voicecard|seeed-8mic-voicecard)
            BEST_MODEL="6"
            BEST_PROFILE_CONF="/etc/voicecard/asound_6mic.conf"
            BEST_PROFILE_STATE="/etc/voicecard/ac108_6mic.state"
            ;;
        *)
            BEST_MODEL="2"
            BEST_PROFILE_CONF="/etc/voicecard/asound_2mic.conf"
            BEST_PROFILE_STATE="/etc/voicecard/wm8960_asound.state"
            warn "Unknown overlay '${overlay}', defaulting to 2-mic profile"
            ;;
    esac

    if [[ -f "$BEST_PROFILE_CONF" ]]; then
        pass "Recommended ALSA profile: model ${BEST_MODEL} (${BEST_PROFILE_CONF})"
    else
        fail "Recommended profile file not found: ${BEST_PROFILE_CONF}"
        add_action "Re-run installer to repopulate /etc/voicecard"
    fi
}

apply_profile() {
    local backup_file

    if [[ "$APPLY_PROFILE" -eq 0 ]]; then
        warn "Profile application skipped (--no-apply)"
        return
    fi

    if [[ ! -f "$BEST_PROFILE_CONF" ]]; then
        fail "Cannot apply profile; missing ${BEST_PROFILE_CONF}"
        add_action "Fix profile files and re-run doctor"
        return
    fi

    if [[ -e /etc/asound.conf && ! -L /etc/asound.conf ]]; then
        backup_file="/etc/asound.conf.backup.$(date +%Y%m%d%H%M%S)"
        cp /etc/asound.conf "$backup_file"
        pass "Backed up /etc/asound.conf to ${backup_file}"
    fi

    ln -sfn "$BEST_PROFILE_CONF" /etc/asound.conf
    pass "Linked /etc/asound.conf -> ${BEST_PROFILE_CONF}"

    if [[ -f "$BEST_PROFILE_STATE" ]]; then
        mkdir -p /var/lib/alsa
        ln -sfn "$BEST_PROFILE_STATE" /var/lib/alsa/asound.state
        pass "Linked /var/lib/alsa/asound.state -> ${BEST_PROFILE_STATE}"
    else
        warn "State file not found: ${BEST_PROFILE_STATE}"
        add_action "Check /etc/voicecard state files"
    fi

    if command_exists alsactl; then
        if alsactl restore >/dev/null 2>&1; then
            pass "alsactl restore completed"
        else
            warn "alsactl restore failed"
            add_action "Run: sudo alsactl restore"
        fi
    else
        warn "alsactl not found"
        add_action "Install alsa-utils: sudo apt-get install -y alsa-utils"
    fi
}

measure_audio_metrics() {
    local file="$1"
    local channels="$2"
    local max_amp=""
    local rms_amp=""
    local left_rms=""
    local right_rms=""
    local ratio=""

    if ! command_exists sox; then
        warn "sox not installed; skipping quality metric extraction"
        return 0
    fi

    max_amp="$(sox "$file" -n stat 2>&1 | awk -F': *' '/Maximum amplitude/{print $2; exit}')"
    rms_amp="$(sox "$file" -n stat 2>&1 | awk -F': *' '/RMS[[:space:]]+amplitude/{print $2; exit}')"

    if [[ -n "$max_amp" ]]; then
        pass "Measured max amplitude: ${max_amp}"
        awk -v x="$max_amp" 'BEGIN{exit (x>=0.98)?0:1}' && {
            warn "Potential clipping detected (max amplitude ${max_amp})"
            add_action "Lower capture gain in alsamixer if distortion is audible"
        }
    fi

    if [[ -n "$rms_amp" ]]; then
        pass "Measured RMS amplitude: ${rms_amp}"
        awk -v x="$rms_amp" 'BEGIN{exit (x<0.0005)?0:1}' && {
            warn "Very low signal level detected (RMS ${rms_amp})"
            add_action "Raise capture level and re-run doctor while speaking near microphones"
        }
    fi

    if [[ "$channels" -ge 2 ]]; then
        left_rms="$(sox "$file" -n remix 1 stat 2>&1 | awk -F': *' '/RMS[[:space:]]+amplitude/{print $2; exit}')"
        right_rms="$(sox "$file" -n remix 2 stat 2>&1 | awk -F': *' '/RMS[[:space:]]+amplitude/{print $2; exit}')"

        if [[ -n "$left_rms" && -n "$right_rms" ]]; then
            ratio="$(awk -v l="$left_rms" -v r="$right_rms" 'BEGIN{if (l<=0 || r<=0) print 99; else if (l>r) print l/r; else print r/l;}')"
            pass "Channel RMS balance ratio: ${ratio}"
            awk -v x="$ratio" 'BEGIN{exit (x>4.0)?0:1}' && {
                warn "Large channel imbalance detected"
                add_action "Check microphone orientation/wiring and per-channel gains"
            }
        fi
    fi
}

run_capture_matrix() {
    local rates=(16000 32000 44100 48000)
    local formats=(S16_LE S24_LE S32_LE)
    local score=0
    local best_score=-1
    local format
    local rate
    local channels
    local file
    local fmt_weight
    local rate_weight
    local capture_err=""
    local busy_pids=""

    DETECTED_CARD="$(detect_card_number || true)"
    if [[ -z "$DETECTED_CARD" ]]; then
        fail "Could not detect a Seeed/ReSpeaker ALSA capture card"
        add_action "Check hardware connection and run: arecord -l"
        return
    fi

    channels="$(get_capture_channel_max "$DETECTED_CARD")"
    BEST_CHANNELS="$channels"
    pass "Detected capture card index: ${DETECTED_CARD}"
    pass "Detected max capture channels: ${channels}"

    busy_pids="$(capture_busy_pids "$DETECTED_CARD" || true)"
    if [[ -n "$busy_pids" ]]; then
        warn "Capture matrix skipped: capture device is currently busy"
        report_capture_busy "$DETECTED_CARD" "$busy_pids"
        return
    fi

    if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
        echo
        echo "Speak continuously for the next short recording tests."
        read -r -p "Press Enter when ready..."
    fi

    for format in "${formats[@]}"; do
        case "$format" in
            S32_LE) fmt_weight=3 ;;
            S24_LE) fmt_weight=2 ;;
            *) fmt_weight=1 ;;
        esac

        for rate in "${rates[@]}"; do
            case "$rate" in
                48000) rate_weight=3 ;;
                44100) rate_weight=2 ;;
                *) rate_weight=1 ;;
            esac

            file="/tmp/seeed-doctor-${format}-${rate}.wav"
            if capture_err="$(arecord -D "plughw:${DETECTED_CARD},0" -f "$format" -r "$rate" -d 2 -c 2 "$file" 2>&1 >/dev/null)"; then
                score=$((fmt_weight * 10 + rate_weight))
                pass "Capture matrix success: format=${format}, rate=${rate}"

                if [[ "$score" -gt "$best_score" ]]; then
                    best_score="$score"
                    BEST_FORMAT="$format"
                    BEST_RATE="$rate"
                fi

                if [[ "$format" == "$BEST_FORMAT" && "$rate" == "$BEST_RATE" ]]; then
                    measure_audio_metrics "$file" 2
                fi
            else
                if [[ "$capture_err" == *"Device or resource busy"* ]]; then
                    busy_pids="$(capture_busy_pids "$DETECTED_CARD" || true)"
                    warn "Capture matrix aborted: device became busy during test"
                    report_capture_busy "$DETECTED_CARD" "$busy_pids"
                    rm -f "$file"
                    return
                fi
                warn "Capture matrix failed: format=${format}, rate=${rate}"
            fi

            rm -f "$file"
        done
    done

    if [[ "$best_score" -lt 0 ]]; then
        fail "No working capture format/rate found in matrix"
        add_action "Run smoke test and inspect dmesg for codec errors"
    else
        pass "Best tested capture mode: ${BEST_FORMAT} @ ${BEST_RATE} Hz"
    fi
}

run_smoke() {
    local smoke_cmd=("${SCRIPT_DIR}/exp_post_install_smoke_test.sh")

    [[ "$SKIP_SMOKE" -eq 1 ]] && {
        warn "Smoke tests skipped (--skip-smoke)"
        return 0
    }

    if [[ ! -x "${SCRIPT_DIR}/exp_post_install_smoke_test.sh" ]]; then
        fail "Smoke test script not found: ${SCRIPT_DIR}/exp_post_install_smoke_test.sh"
        add_action "Restore smoke script and rerun doctor"
        return 1
    fi

    echo
    echo "[INFO] Running smoke test"
    if "${smoke_cmd[@]}"; then
        pass "Smoke test completed successfully"
    else
        warn "Smoke test reported failures"
        add_action "Review smoke test output for specific failed checks"
    fi
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

final_summary() {
    local verdict

    if [[ "$FAIL_COUNT" -gt 0 ]]; then
        verdict="FAIL"
    elif [[ "$WARN_COUNT" -gt 0 ]]; then
        verdict="WARN"
    else
        verdict="PASS"
    fi

    echo
    echo "Doctor Summary"
    echo "  Pass: ${PASS_COUNT}"
    echo "  Warn: ${WARN_COUNT}"
    echo "  Fail: ${FAIL_COUNT}"
    echo "  Verdict: ${verdict}"

    if [[ -n "$BEST_PROFILE_CONF" ]]; then
        echo "  Recommended profile: ${BEST_PROFILE_CONF}"
    fi
    if [[ -n "$BEST_FORMAT" && -n "$BEST_RATE" ]]; then
        echo "  Best capture mode tested: ${BEST_FORMAT} @ ${BEST_RATE} Hz"
    fi

    if (( ${#FAIL_ITEMS[@]} > 0 )); then
        echo
        echo "Failed Checks"
        printf -- '- %s\n' "${FAIL_ITEMS[@]}"
    fi

    if (( ${#WARN_ITEMS[@]} > 0 )); then
        echo
        echo "Warnings"
        printf -- '- %s\n' "${WARN_ITEMS[@]}"
    fi

    print_actions

    echo
    echo "Report written to: ${REPORT_FILE}"

    [[ "$FAIL_COUNT" -gt 0 ]] && return 1
    return 0
}

main() {
    parse_args "$@"
    require_root
    detect_boot_paths
    setup_report

    echo "Running Seeed Doctor"
    echo "Timestamp: $(date -Iseconds)"
    echo "Config file: ${CONFIG}"
    echo "Overlay dir: ${OVERLAYS}"

    run_smoke
    recommend_profile
    run_capture_matrix
    apply_profile
    run_smoke

    if final_summary; then
        exit 0
    fi

    exit 1
}

main "$@"
