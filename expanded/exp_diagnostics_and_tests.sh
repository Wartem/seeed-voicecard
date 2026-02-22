#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_FILES=()

log() {
    echo "[INFO] $*"
}

warn() {
    echo "[WARN] $*" >&2
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_root() {
    if [[ ${EUID} -ne 0 ]]; then
        echo "This script must be run as root (use sudo)." >&2
        exit 1
    fi
}

press_enter_to_continue() {
    restore_terminal_state
    echo
    read -r -p "Press Enter to continue..."
}

cleanup_temp_files() {
    local f
    for f in "${TEMP_FILES[@]}"; do
        [[ -n "$f" ]] && rm -f "$f"
    done
}

register_temp_file() {
    TEMP_FILES+=("$1")
}

restore_terminal_state() {
    # Interactive commands can leave TTY flags altered; always restore the real TTY.
    if [[ -r /dev/tty ]]; then
        stty sane < /dev/tty 2>/dev/null || true
        stty opost onlcr < /dev/tty 2>/dev/null || true
        printf '\033[0m\033[?7h\033[?25h' > /dev/tty 2>/dev/null || true
    else
        stty sane 2>/dev/null || true
        stty opost onlcr 2>/dev/null || true
        printf '\033[0m\033[?7h\033[?25h' 2>/dev/null || true
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

detect_playback_card() {
    local card
    card="$(detect_seeed_card || true)"
    [[ -n "$card" ]] || card="0"
    echo "$card"
}

extract_state_card_id() {
    local state_file="$1"

    [[ -f "$state_file" ]] || return 1

    awk '
        /^state\.[^[:space:]]+[[:space:]]*\{/ {
            name = $1
            sub(/^state\./, "", name)
            if (name != "ALSA") {
                print name
                exit
            }
        }
    ' "$state_file"
}

LAST_ARECORD_BUSY=0

report_busy_playback_holders() {
    local card="$1"
    local dev="/dev/snd/pcmC${card}D0p"
    local pids
    local pid
    local info

    [[ -e "$dev" ]] || return 0
    if ! command_exists fuser; then
        return 0
    fi

    pids="$(fuser "$dev" 2>/dev/null | tr -s '[:space:]' ' ' | sed -E 's/^ +//; s/ +$//')"
    [[ -n "$pids" ]] || return 0

    warn "Playback device busy: ${dev} (PID(s): ${pids})"
    if ! command_exists ps; then
        return 0
    fi

    for pid in $pids; do
        info="$(ps -p "$pid" -o pid=,user=,cmd= 2>/dev/null | sed -E 's/^ +//; s/ +/ /g')"
        [[ -n "$info" ]] && warn "Holder: ${info}"
    done
}

report_busy_capture_holders() {
    local card="$1"
    local dev="/dev/snd/pcmC${card}D0c"
    local pids
    local pid
    local info

    [[ -e "$dev" ]] || return 0
    if ! command_exists fuser; then
        return 0
    fi

    pids="$(fuser "$dev" 2>/dev/null | tr -s '[:space:]' ' ' | sed -E 's/^ +//; s/ +$//')"
    [[ -n "$pids" ]] || return 0

    warn "Capture device busy: ${dev} (PID(s): ${pids})"
    if ! command_exists ps; then
        return 0
    fi

    for pid in $pids; do
        info="$(ps -p "$pid" -o pid=,user=,cmd= 2>/dev/null | sed -E 's/^ +//; s/ +/ /g')"
        [[ -n "$info" ]] && warn "Holder: ${info}"
    done
}

arecord_seeed() {
    local card="$1"
    shift
    local err=""

    LAST_ARECORD_BUSY=0
    if err="$(arecord -D "plughw:${card},0" "$@" 2>&1)"; then
        return 0
    fi

    warn "Capture failed on plughw:${card},0"
    [[ -n "$err" ]] && warn "arecord error: ${err}"
    if [[ "$err" == *"Device or resource busy"* ]]; then
        LAST_ARECORD_BUSY=1
        report_busy_capture_holders "$card"
    fi
    return 1
}

aplay_seeed_file() {
    local file="$1"
    local card="${2:-}"

    [[ -n "$card" ]] || card="$(detect_playback_card)"
    if aplay -D "plughw:${card},0" "$file"; then
        return 0
    fi

    warn "Playback failed on plughw:${card},0"
    report_busy_playback_holders "$card"
    return 1
}

get_capture_channel_count() {
    local card="$1"
    local params
    local max_channels

    params="$(arecord -D "plughw:${card},0" --dump-hw-params -d 1 /dev/null 2>&1 || true)"
    max_channels="$(echo "$params" | sed -n -E 's/.*CHANNELS:[[:space:]]*\[[0-9]+[[:space:]]+([0-9]+)\].*/\1/p' | head -n 1)"

    if [[ -z "$max_channels" ]]; then
        max_channels="$(echo "$params" | sed -n -E 's/.*channels:[[:space:]]*([0-9]+).*/\1/p' | head -n 1)"
    fi

    if [[ -z "$max_channels" ]]; then
        max_channels="2"
    fi

    echo "$max_channels"
}

show_general_system_info() {
    echo "=== General System Info ==="
    uname -a
    echo

    if [[ -f /etc/os-release ]]; then
        cat /etc/os-release
        echo
    fi

    echo "Kernel version: $(uname -r)"
    if command_exists lscpu; then
        lscpu | sed -n '1,12p'
    else
        grep -m1 "model name" /proc/cpuinfo || true
    fi

    echo
    echo "=== Memory and Disk ==="
    free -h
    df -h

    echo
    echo "=== Network Interfaces ==="
    if command_exists ip; then
        ip -brief addr
        echo
        ip route
    else
        warn "ip command not found"
    fi

    echo
    echo "=== USB Devices ==="
    if command_exists lsusb; then
        lsusb
    else
        warn "lsusb not found"
    fi

    echo
    echo "=== I2C Scan (bus 1) ==="
    if command_exists i2cdetect; then
        i2cdetect -y 1
    else
        warn "i2cdetect not found"
    fi

    echo
    echo "=== GPIO Status ==="
    if command_exists raspi-gpio; then
        raspi-gpio get | sed -n '1,40p'
    elif command_exists gpio; then
        gpio readall
    else
        warn "No GPIO inspection tool found (raspi-gpio/gpio)."
    fi

    echo
    echo "=== Recent dmesg (last 50 lines) ==="
    dmesg | tail -n 50

    echo
    echo "=== Running services (top 40) ==="
    systemctl list-units --type=service --state=running --no-pager | sed -n '1,40p'
}

show_audio_info() {
    echo "=== ALSA Cards ==="
    cat /proc/asound/cards 2>/dev/null || warn "/proc/asound/cards not available"

    echo
    echo "=== ALSA Playback Devices (aplay -l) ==="
    if command_exists aplay; then
        aplay -l || true
        echo
        echo "=== ALSA Playback PCM Names (aplay -L) ==="
        aplay -L || true
    else
        warn "aplay not found"
    fi

    echo
    echo "=== ALSA Recording Devices (arecord -l) ==="
    if command_exists arecord; then
        arecord -l || true
    else
        warn "arecord not found"
    fi

    echo
    echo "=== ALSA Mixer ==="
    if command_exists amixer; then
        amixer scontrols || true
    else
        warn "amixer not found"
    fi

    echo
    echo "=== Loaded Sound Modules ==="
    lsmod | grep '^snd' || warn "No snd modules currently listed"

    echo
    echo "=== Device Tree / Boot Logs (Seeed-related) ==="
    if command_exists vcdbg; then
        vcdbg log msg | grep -i "seeed\|respeaker\|ac108\|wm8960" || true
    else
        warn "vcdbg not found"
    fi

    echo
    echo "=== Kernel Messages (Seeed-related) ==="
    dmesg | grep -i "seeed\|respeaker\|wm8960\|ac108" || true

    echo
    echo "=== Audio Config Files ==="
    echo "/etc/asound.conf:"
    cat /etc/asound.conf 2>/dev/null || echo "(not found)"
    echo
    echo "~/.asoundrc:"
    cat "${HOME}/.asoundrc" 2>/dev/null || echo "(not found)"

    echo
    echo "=== PulseAudio/PipeWire ==="
    if command_exists pactl; then
        if pactl info >/dev/null 2>&1; then
            pactl info
            pactl list sinks short || true
            pactl list sources short || true
        else
            warn "pactl is installed, but no user audio server is reachable from this root shell."
            warn "This is expected if PulseAudio/PipeWire is not running for the current user session."
        fi
    else
        warn "pactl not found"
    fi
}

play_system_sound() {
    local card
    local sound_file="/usr/share/sounds/alsa/Front_Center.wav"

    if ! command_exists aplay; then
        warn "aplay not found"
        return 1
    fi

    card="$(detect_playback_card)"

    if [[ -f "$sound_file" ]]; then
        aplay_seeed_file "$sound_file" "$card"
    else
        warn "${sound_file} not found"
    fi
}

play_beep_sound() {
    local card

    if ! command_exists speaker-test; then
        warn "speaker-test not found"
        return 1
    fi

    card="$(detect_playback_card)"
    if speaker-test -D "plughw:${card},0" -t sine -f 1000 -l 1; then
        return 0
    fi

    warn "speaker-test playback failed on plughw:${card},0"
    report_busy_playback_holders "$card"
    return 1
}

test_recording_simple() {
    local card
    local file

    if ! command_exists arecord || ! command_exists aplay; then
        warn "arecord/aplay are required"
        return 1
    fi

    card="$(detect_seeed_card || true)"
    [[ -n "$card" ]] || card="0"

    file="/tmp/respeaker_simple_recording.wav"
    register_temp_file "$file"

    log "Recording on plughw:${card},0 for 5 seconds"
    arecord_seeed "$card" -f S16_LE -r 44100 -d 5 -c 2 "$file" || return 1
    log "Playing back ${file}"
    aplay_seeed_file "$file" "$card"
}

test_recording_matrix() {
    local card
    local format
    local rate
    local file
    local response
    local formats=(S16_LE S24_LE S32_LE)
    local rates=(16000 44100 48000)

    if ! command_exists arecord || ! command_exists aplay; then
        warn "arecord/aplay are required"
        return 1
    fi

    card="$(detect_seeed_card || true)"
    [[ -n "$card" ]] || card="0"

    for format in "${formats[@]}"; do
        for rate in "${rates[@]}"; do
            file="/tmp/respeaker_${format}_${rate}.wav"
            register_temp_file "$file"

            echo
            log "Testing format=${format}, rate=${rate} on plughw:${card},0"
            if arecord_seeed "$card" -f "$format" -r "$rate" -d 3 -c 2 "$file"; then
                aplay_seeed_file "$file" "$card" || true
                read -r -p "Did this test sound correct? (y/n): " response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    echo "Result: pass (${format}, ${rate})"
                else
                    echo "Result: fail (${format}, ${rate})"
                fi
            else
                warn "Recording failed for ${format} @ ${rate}"
                if [[ "$LAST_ARECORD_BUSY" -eq 1 ]]; then
                    warn "Capture matrix aborted because the capture device is busy."
                    return 1
                fi
            fi
        done
    done
}

test_mic_array_simple() {
    local card
    local file

    if ! command_exists arecord || ! command_exists aplay; then
        warn "arecord/aplay are required"
        return 1
    fi

    card="$(detect_seeed_card || true)"
    [[ -n "$card" ]] || card="0"

    file="/tmp/respeaker_mic_simple.wav"
    register_temp_file "$file"

    log "Recording mono capture from plughw:${card},0"
    arecord_seeed "$card" -f S16_LE -r 16000 -d 3 -c 1 "$file" || return 1
    aplay_seeed_file "$file" "$card"
}

test_mic_array_comprehensive() {
    local card
    local channels
    local capture_file
    local ch
    local channel_file
    local response

    if ! command_exists arecord || ! command_exists aplay; then
        warn "arecord/aplay are required"
        return 1
    fi

    if ! command_exists sox; then
        warn "sox is required for per-channel mic tests. Install sox and retry."
        return 1
    fi

    card="$(detect_seeed_card || true)"
    if [[ -z "$card" ]]; then
        read -r -p "Could not auto-detect Seeed card. Enter ALSA card number: " card
    fi

    channels="$(get_capture_channel_count "$card")"
    capture_file="/tmp/respeaker_mic_multichannel.wav"
    register_temp_file "$capture_file"

    log "Recording ${channels} channels from plughw:${card},0"
    arecord_seeed "$card" -f S16_LE -r 16000 -d 4 -c "$channels" "$capture_file" || return 1

    for ch in $(seq 1 "$channels"); do
        channel_file="/tmp/respeaker_mic_ch${ch}.wav"
        register_temp_file "$channel_file"

        sox "$capture_file" "$channel_file" remix "$ch"
        echo
        log "Playing channel ${ch}/${channels}"
        aplay_seeed_file "$channel_file" "$card"

        read -r -p "Channel ${ch} sounds correct? (y/n): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "Channel ${ch}: pass"
        else
            echo "Channel ${ch}: fail"
        fi
    done
}

test_audio_playback_tones() {
    local card
    local tone
    local file
    local response
    local tones=(100 1000 10000)

    if ! command_exists sox || ! command_exists aplay; then
        warn "sox and aplay are required"
        return 1
    fi

    card="$(detect_playback_card)"

    for tone in "${tones[@]}"; do
        file="/tmp/respeaker_tone_${tone}.wav"
        register_temp_file "$file"

        sox -n -r 44100 -b 16 "$file" synth 3 sine "$tone"
        aplay_seeed_file "$file" "$card"

        read -r -p "Did ${tone} Hz play clearly? (y/n): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "Tone ${tone} Hz: pass"
        else
            echo "Tone ${tone} Hz: fail"
        fi
    done
}

run_all_audio_tests() {
    play_system_sound || true
    play_beep_sound || true
    test_recording_simple || true
    test_mic_array_comprehensive || true
    test_audio_playback_tones || true
}

check_alsa_mixer() {
    if ! command_exists amixer; then
        warn "amixer not found"
        return 1
    fi

    amixer -c 0 scontrols || true
    echo
    amixer -c 0 scontents || true
}

test_leds() {
    local led
    local led_name
    local max_brightness
    local response

    if [[ ! -d /sys/class/leds ]]; then
        warn "No /sys/class/leds interface found"
        return 1
    fi

    for led in /sys/class/leds/*; do
        [[ -d "$led" ]] || continue

        led_name="$(basename "$led")"
        max_brightness="$(cat "$led/max_brightness" 2>/dev/null || echo 255)"

        echo "Testing LED: ${led_name}"
        echo "$max_brightness" > "$led/brightness"
        sleep 1
        echo 0 > "$led/brightness"
        sleep 1
    done

    read -r -p "Did LEDs respond during test? (y/n): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "LED test: pass"
    else
        echo "LED test: fail"
    fi
}

reload_audio_modules() {
    local module

    for module in snd_soc_seeed_voicecard snd_soc_wm8960 snd_soc_ac108; do
        modprobe -r "$module" >/dev/null 2>&1 || true
    done

    for module in snd_soc_ac108 snd_soc_wm8960 snd_soc_seeed_voicecard; do
        if ! modprobe "$module" >/dev/null 2>&1; then
            warn "Failed to load ${module}"
        fi
    done

    lsmod | grep -E 'snd_soc_(seeed_voicecard|wm8960|ac108)' || true
}

show_audio_server_status() {
    echo "=== Running Audio Server Processes ==="
    pgrep -a pulseaudio || echo "pulseaudio: not running"
    pgrep -a pipewire || echo "pipewire: not running"
    pgrep -a wireplumber || echo "wireplumber: not running"

    echo
    echo "=== Package Presence ==="
    show_package_line pulseaudio
    show_package_line pipewire
    show_package_line wireplumber
}

run_alsamixer() {
    if ! command_exists alsamixer; then
        warn "alsamixer not found"
        return 1
    fi

    alsamixer
    restore_terminal_state
}

apply_asound_profile() {
    local choice
    local target_conf=""
    local target_state=""
    local backup_file

    echo "Choose ALSA profile to apply:"
    echo "1) 2-mic profile"
    echo "2) 4-mic profile"
    echo "3) 6-mic/8-mic profile"
    echo "4) Cancel"
    read -r -p "Enter choice (1-4): " choice

    case "$choice" in
        1)
            target_conf="/etc/voicecard/asound_2mic.conf"
            target_state="/etc/voicecard/wm8960_asound.state"
            ;;
        2)
            target_conf="/etc/voicecard/asound_4mic.conf"
            target_state="/etc/voicecard/ac108_asound.state"
            ;;
        3)
            target_conf="/etc/voicecard/asound_6mic.conf"
            target_state="/etc/voicecard/ac108_6mic.state"
            ;;
        *)
            echo "No changes made."
            return 0
            ;;
    esac

    if [[ ! -f "$target_conf" ]]; then
        warn "Missing profile: ${target_conf}"
        return 1
    fi

    if [[ -e /etc/asound.conf && ! -L /etc/asound.conf ]]; then
        backup_file="/etc/asound.conf.backup.$(date +%Y%m%d%H%M%S)"
        cp /etc/asound.conf "$backup_file"
        log "Backed up /etc/asound.conf to ${backup_file}"
    fi

    ln -sfn "$target_conf" /etc/asound.conf
    log "Linked /etc/asound.conf -> ${target_conf}"

    local restore_card=""
    if [[ -f "$target_state" ]]; then
        mkdir -p /var/lib/alsa
        ln -sfn "$target_state" /var/lib/alsa/asound.state
        log "Linked /var/lib/alsa/asound.state -> ${target_state}"
        restore_card="$(extract_state_card_id "$target_state" || true)"
    else
        warn "Missing state file: ${target_state}"
    fi

    if [[ -n "$restore_card" ]]; then
        alsactl -f "$target_state" restore "$restore_card" || warn "alsactl restore failed for card ${restore_card}"
    else
        alsactl restore || warn "alsactl restore failed"
    fi
}

show_package_line() {
    local package="$1"
    local version

    if dpkg -s "$package" >/dev/null 2>&1; then
        version="$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null)"
        echo "${package}: installed (${version})"
    else
        echo "${package}: not installed"
    fi
}

show_package_status() {
    echo "=== Core Package Status ==="
    show_package_line dkms
    show_package_line device-tree-compiler
    show_package_line i2c-tools
    show_package_line alsa-utils
    show_package_line libasound2-plugins
    show_package_line sox
    show_package_line pulseaudio
    show_package_line pipewire
}

check_firmware_updates() {
    echo "Relevant repositories:"
    echo "1. Original Seeed repo: https://github.com/respeaker/seeed-voicecard"
    echo "2. HinTak fork: https://github.com/HinTak/seeed-voicecard"
    echo "3. This fork: https://github.com/Wartem/seeed-voicecard"
    echo
    echo "To compare updates:"
    echo "- Review recent commits in each repo"
    echo "- Compare kernel compatibility patches and install scripts"
}

run_smoke_test_workflow() {
    local smoke_script="${SCRIPT_DIR}/exp_post_install_smoke_test.sh"

    if [[ ! -x "$smoke_script" ]]; then
        warn "Smoke test script not found or not executable: ${smoke_script}"
        return 1
    fi

    "$smoke_script"
}

run_doctor_workflow() {
    local doctor_script="${SCRIPT_DIR}/exp_doctor.sh"

    if [[ ! -x "$doctor_script" ]]; then
        warn "Doctor script not found or not executable: ${doctor_script}"
        return 1
    fi

    "$doctor_script"
}

display_main_menu() {
    restore_terminal_state
    clear
    echo "====================================================="
    echo " ReSpeaker HAT Diagnostic and Test Tool (Reworked)"
    echo "====================================================="
    echo "1. System Information"
    echo "2. Audio Tests"
    echo "3. Hardware Tests"
    echo "4. Maintenance"
    echo "5. Package Status"
    echo "6. Exit"
    echo "====================================================="
    echo "Enter choice (1-6):"
}

display_system_info_menu() {
    restore_terminal_state
    clear
    echo "================= System Information ================="
    echo "1. Show General System Info"
    echo "2. Show Detailed Audio Info"
    echo "3. Back"
    echo "======================================================"
    echo "Enter choice (1-3):"
}

display_audio_tests_menu() {
    restore_terminal_state
    clear
    echo "==================== Audio Tests ====================="
    echo "1. Play System Sound"
    echo "2. Play Beep Sound"
    echo "3. Test Recording (Simple)"
    echo "4. Test Recording (Matrix)"
    echo "5. Test Mic Array (Simple)"
    echo "6. Test Mic Array (Comprehensive)"
    echo "7. Test Audio Playback Tones"
    echo "8. Run All Audio Tests"
    echo "9. Back"
    echo "======================================================"
    echo "Enter choice (1-9):"
}

display_hardware_tests_menu() {
    restore_terminal_state
    clear
    echo "=================== Hardware Tests ==================="
    echo "1. Test LEDs"
    echo "2. Inspect ALSA Mixer"
    echo "3. Back"
    echo "======================================================"
    echo "Enter choice (1-3):"
}

display_maintenance_menu() {
    restore_terminal_state
    clear
    echo "==================== Maintenance ====================="
    echo "1. Reload Audio Modules"
    echo "2. Show Audio Server Status"
    echo "3. Open alsamixer"
    echo "4. Apply asound profile"
    echo "5. Run smoke test (PASS/WARN/FAIL verdict)"
    echo "6. Run doctor (auto-config + validation)"
    echo "7. Show firmware/source references"
    echo "8. Back"
    echo "======================================================"
    echo "Enter choice (1-8):"
}

handle_system_info_menu() {
    local choice

    while true; do
        display_system_info_menu
        read -r choice
        case "$choice" in
            1)
                show_general_system_info
                press_enter_to_continue
                ;;
            2)
                show_audio_info
                press_enter_to_continue
                ;;
            3)
                break
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
    done
}

handle_audio_tests_menu() {
    local choice

    while true; do
        display_audio_tests_menu
        read -r choice
        case "$choice" in
            1)
                play_system_sound
                press_enter_to_continue
                ;;
            2)
                play_beep_sound
                press_enter_to_continue
                ;;
            3)
                test_recording_simple
                press_enter_to_continue
                ;;
            4)
                test_recording_matrix
                press_enter_to_continue
                ;;
            5)
                test_mic_array_simple
                press_enter_to_continue
                ;;
            6)
                test_mic_array_comprehensive
                press_enter_to_continue
                ;;
            7)
                test_audio_playback_tones
                press_enter_to_continue
                ;;
            8)
                run_all_audio_tests
                press_enter_to_continue
                ;;
            9)
                break
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
    done
}

handle_hardware_tests_menu() {
    local choice

    while true; do
        display_hardware_tests_menu
        read -r choice
        case "$choice" in
            1)
                test_leds
                press_enter_to_continue
                ;;
            2)
                check_alsa_mixer
                press_enter_to_continue
                ;;
            3)
                break
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
    done
}

handle_maintenance_menu() {
    local choice

    while true; do
        display_maintenance_menu
        read -r choice
        case "$choice" in
            1)
                reload_audio_modules
                press_enter_to_continue
                ;;
            2)
                show_audio_server_status
                press_enter_to_continue
                ;;
            3)
                run_alsamixer
                press_enter_to_continue
                ;;
            4)
                apply_asound_profile
                press_enter_to_continue
                ;;
            5)
                run_smoke_test_workflow
                press_enter_to_continue
                ;;
            6)
                run_doctor_workflow
                press_enter_to_continue
                ;;
            7)
                check_firmware_updates
                press_enter_to_continue
                ;;
            8)
                break
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
    done
}

handle_main_menu() {
    local choice

    while true; do
        display_main_menu
        read -r choice
        case "$choice" in
            1)
                handle_system_info_menu
                ;;
            2)
                handle_audio_tests_menu
                ;;
            3)
                handle_hardware_tests_menu
                ;;
            4)
                handle_maintenance_menu
                ;;
            5)
                show_package_status
                press_enter_to_continue
                ;;
            6)
                return 0
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
    done
}

main() {
    require_root
    trap 'restore_terminal_state; cleanup_temp_files' EXIT
    handle_main_menu
}

main "$@"
