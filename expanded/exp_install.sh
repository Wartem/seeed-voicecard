#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEEED_VOICECARD_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OVERLAYS=""
CONFIG=""
SELECTED_OVERLAY=""
SELECTED_MODEL=""

NON_INTERACTIVE=0
AUTO_CONFIRM=0
AUTO_REBOOT=0
CLI_MODEL=""
CLI_UPDATE_MODE="prompt"
RUN_SMOKE_TEST=0
RUN_DOCTOR=0

log() {
    echo "[INFO] $*"
}

warn() {
    echo "[WARN] $*" >&2
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

show_help() {
    cat <<'USAGE'
Usage: exp_install.sh [options]

Options:
  -y, --yes                    Non-interactive mode (auto-confirm prompts)
      --non-interactive        Same as --yes
      --model <2|4|6|8>        Select mic model without prompt
      --update-mode <mode>     One of: prompt, none, update, upgrade, full-upgrade
      --run-smoke-test         Run post-install smoke test automatically
      --run-doctor             Run full doctor workflow automatically
      --reboot                 Reboot automatically at the end
  -h, --help                   Show this help

Examples:
  sudo ./expanded/exp_install.sh
  sudo ./expanded/exp_install.sh --yes --model 2 --update-mode none
  sudo ./expanded/exp_install.sh --yes --model 4 --update-mode upgrade --run-smoke-test
  sudo ./expanded/exp_install.sh --yes --model 2 --update-mode none --run-doctor --reboot
USAGE
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                NON_INTERACTIVE=1
                AUTO_CONFIRM=1
                shift
                ;;
            --non-interactive)
                NON_INTERACTIVE=1
                AUTO_CONFIRM=1
                shift
                ;;
            --model)
                [[ $# -ge 2 ]] || die "Missing value for --model"
                CLI_MODEL="$2"
                shift 2
                ;;
            --update-mode)
                [[ $# -ge 2 ]] || die "Missing value for --update-mode"
                CLI_UPDATE_MODE="$2"
                shift 2
                ;;
            --reboot)
                AUTO_REBOOT=1
                shift
                ;;
            --run-smoke-test)
                RUN_SMOKE_TEST=1
                shift
                ;;
            --run-doctor)
                RUN_DOCTOR=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
}

validate_args() {
    case "$CLI_UPDATE_MODE" in
        prompt|none|update|upgrade|full-upgrade)
            ;;
        *)
            die "Invalid --update-mode: ${CLI_UPDATE_MODE}"
            ;;
    esac

    if [[ -n "$CLI_MODEL" ]]; then
        case "$CLI_MODEL" in
            2|4|6|8)
                ;;
            *)
                die "Invalid --model: ${CLI_MODEL} (expected 2, 4, 6, or 8)"
                ;;
        esac
    fi

    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        [[ -n "$CLI_MODEL" ]] || die "Non-interactive mode requires --model <2|4|6|8>."
        if [[ "$CLI_UPDATE_MODE" == "prompt" ]]; then
            CLI_UPDATE_MODE="none"
        fi
    fi

    if [[ "$RUN_SMOKE_TEST" -eq 1 && "$RUN_DOCTOR" -eq 1 ]]; then
        warn "Both --run-smoke-test and --run-doctor set; doctor already runs validation, so smoke flag will be ignored."
        RUN_SMOKE_TEST=0
    fi
}

require_root() {
    if [[ ${EUID} -ne 0 ]]; then
        die "This script must be run as root (use sudo)."
    fi
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
        die "Could not find Raspberry Pi config.txt (checked /boot and /boot/firmware)."
    fi
}

add_line_if_missing() {
    local line="$1"
    local file="$2"

    [[ -f "$file" ]] || touch "$file"
    grep -qxF "$line" "$file" || echo "$line" >> "$file"
}

remove_exact_line() {
    local line="$1"
    local file="$2"
    local tmp_file

    [[ -f "$file" ]] || return 0

    tmp_file="$(mktemp)"
    grep -vxF "$line" "$file" > "$tmp_file" || true
    cat "$tmp_file" > "$file"
    rm -f "$tmp_file"
}

remove_existing_overlay_lines() {
    local existing_overlay

    for existing_overlay in \
        seeed-2mic-voicecard \
        seeed-4mic-voicecard \
        seeed-6mic-voicecard \
        seeed-8mic-voicecard; do
        remove_exact_line "dtoverlay=${existing_overlay}" "$CONFIG"
    done
}

apply_update_mode() {
    local mode="$1"

    if ! command_exists apt-get; then
        warn "apt-get not found. Skipping package update actions."
        return 0
    fi

    case "$mode" in
        none)
            log "Skipping package update/upgrade."
            ;;
        update)
            log "Running apt-get update..."
            apt-get update
            ;;
        upgrade)
            log "Running apt-get update + apt-get upgrade..."
            apt-get update
            apt-get upgrade -y
            ;;
        full-upgrade)
            log "Running apt-get update + apt-get full-upgrade..."
            apt-get update
            apt-get full-upgrade -y
            ;;
        *)
            die "Unsupported update mode: ${mode}"
            ;;
    esac
}

prompt_for_system_update() {
    local update_choice
    local upgrade_choice

    if [[ "$CLI_UPDATE_MODE" != "prompt" ]]; then
        apply_update_mode "$CLI_UPDATE_MODE"
        return 0
    fi

    if ! command_exists apt-get; then
        warn "apt-get not found. Skipping package update prompts."
        return 0
    fi

    echo "Do you want to update package indexes before installation?"
    echo "1) Yes (recommended)"
    echo "2) No"
    read -r -p "Enter your choice (1 or 2): " update_choice

    if [[ "$update_choice" == "2" ]]; then
        log "Skipping package index update."
        return 0
    fi

    log "Running apt-get update..."
    apt-get update

    echo "Choose system upgrade type:"
    echo "1) Skip upgrade"
    echo "2) apt-get upgrade (safer: no package removals)"
    echo "3) apt-get full-upgrade (more complete: may remove packages)"
    read -r -p "Enter your choice (1-3): " upgrade_choice

    case "$upgrade_choice" in
        2)
            log "Running apt-get upgrade..."
            apt-get upgrade -y
            ;;
        3)
            log "Running apt-get full-upgrade..."
            apt-get full-upgrade -y
            ;;
        *)
            log "Skipping system upgrade."
            ;;
    esac
}

ensure_dependencies() {
    local pkg
    local missing=()
    local required_packages=(dkms device-tree-compiler)

    if ! command_exists apt-get; then
        warn "apt-get not found. Cannot auto-install missing dependencies."
        return 0
    fi

    for pkg in "${required_packages[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done

    if (( ${#missing[@]} == 0 )); then
        return 0
    fi

    log "Installing required packages: ${missing[*]}"
    apt-get update
    apt-get install -y "${missing[@]}"
}

map_model_to_overlay() {
    local model="$1"

    case "$model" in
        2)
            SELECTED_OVERLAY="seeed-2mic-voicecard"
            ;;
        4)
            SELECTED_OVERLAY="seeed-4mic-voicecard"
            ;;
        6)
            # Upstream runtime logic uses the 8-mic overlay for 6-mic hardware.
            SELECTED_OVERLAY="seeed-8mic-voicecard"
            warn "6-mic selection maps to ${SELECTED_OVERLAY} in this fork."
            ;;
        8)
            SELECTED_OVERLAY="seeed-8mic-voicecard"
            ;;
        *)
            die "Invalid mic model choice: ${model}"
            ;;
    esac

    SELECTED_MODEL="$model"
}

choose_mic_model() {
    local mic_choice

    if [[ -n "$CLI_MODEL" ]]; then
        map_model_to_overlay "$CLI_MODEL"
        return 0
    fi

    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        die "Non-interactive mode requires --model <2|4|6|8>."
    fi

    echo "Please select your ReSpeaker mic model:"
    echo "2) 2-Mics Pi HAT"
    echo "4) 4-Mics Pi HAT"
    echo "6) 6-Mics Circular Array Kit"
    echo "8) 8-Mics Circular Array Kit"
    read -r -p "Enter your choice (2, 4, 6, or 8): " mic_choice

    map_model_to_overlay "$mic_choice"
}

run_base_driver_install() {
    log "Building overlay binaries..."
    (
        cd "$SEEED_VOICECARD_ROOT"
        bash ./builddtbo.sh
    )

    log "Installing drivers (DKMS path)..."
    (
        cd "$SEEED_VOICECARD_ROOT"
        bash ./install.sh
    )
}

install_selected_overlay() {
    local overlay_name
    local selected_dtbo

    selected_dtbo="${SELECTED_OVERLAY}.dtbo"
    [[ -f "${SEEED_VOICECARD_ROOT}/${selected_dtbo}" ]] || die "Missing ${selected_dtbo} in repository root."

    log "Installing selected overlay ${selected_dtbo} to ${OVERLAYS}"
    install -m 0644 "${SEEED_VOICECARD_ROOT}/${selected_dtbo}" "${OVERLAYS}/${selected_dtbo}"

    for overlay_name in \
        seeed-2mic-voicecard \
        seeed-4mic-voicecard \
        seeed-6mic-voicecard \
        seeed-8mic-voicecard; do
        if [[ "$overlay_name" != "$SELECTED_OVERLAY" ]]; then
            rm -f "${OVERLAYS}/${overlay_name}.dtbo"
        fi
    done
}

configure_boot() {
    log "Updating boot configuration: ${CONFIG}"

    # Uncomment i2c_arm line if present and commented.
    sed -i -E 's|^[[:space:]]*#[[:space:]]*(dtparam=i2c_arm=on)|\1|' "$CONFIG"

    remove_existing_overlay_lines
    add_line_if_missing "dtoverlay=i2s-mmap" "$CONFIG"
    add_line_if_missing "dtparam=i2s=on" "$CONFIG"
    add_line_if_missing "dtoverlay=${SELECTED_OVERLAY}" "$CONFIG"
}

configure_modules() {
    local module

    log "Ensuring kernel modules are listed in /etc/modules"
    for module in snd-soc-seeed-voicecard snd-soc-ac108 snd-soc-wm8960; do
        add_line_if_missing "$module" /etc/modules
    done

    add_line_if_missing "blacklist snd_bcm2835" /etc/modprobe.d/raspi-blacklist.conf
}

install_runtime_files() {
    log "Installing runtime files under /etc/voicecard and systemd"

    mkdir -p /etc/voicecard

    if ls "${SEEED_VOICECARD_ROOT}"/*.conf >/dev/null 2>&1; then
        cp "${SEEED_VOICECARD_ROOT}"/*.conf /etc/voicecard/
    else
        warn "No .conf files found in ${SEEED_VOICECARD_ROOT}"
    fi

    if ls "${SEEED_VOICECARD_ROOT}"/*.state >/dev/null 2>&1; then
        cp "${SEEED_VOICECARD_ROOT}"/*.state /etc/voicecard/
    else
        warn "No .state files found in ${SEEED_VOICECARD_ROOT}"
    fi

    install -m 0755 "${SEEED_VOICECARD_ROOT}/seeed-voicecard" /usr/bin/seeed-voicecard
    install -m 0644 "${SEEED_VOICECARD_ROOT}/seeed-voicecard.service" /lib/systemd/system/seeed-voicecard.service

    systemctl daemon-reload
    systemctl enable seeed-voicecard.service >/dev/null 2>&1 || warn "Failed to enable seeed-voicecard.service"
    systemctl restart seeed-voicecard.service >/dev/null 2>&1 || warn "Failed to restart seeed-voicecard.service"
}

add_invoking_user_to_groups() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        log "Adding ${SUDO_USER} to audio and i2c groups"
        usermod -a -G audio,i2c "$SUDO_USER" || warn "Failed to update groups for ${SUDO_USER}"
    else
        warn "SUDO_USER not set; skipping audio/i2c group update."
    fi
}

post_install_summary() {
    echo
    echo "Installation completed in one pass."
    echo "Selected model: ${SELECTED_MODEL}"
    echo "Selected overlay: ${SELECTED_OVERLAY}"
    echo "Overlay directory: ${OVERLAYS}"
    echo "Config file: ${CONFIG}"
    echo
    echo "A reboot is required for all changes to take effect."
}

prompt_reboot() {
    local reboot_choice

    if [[ "$AUTO_REBOOT" -eq 1 ]]; then
        log "--reboot specified. Rebooting now..."
        reboot
    fi

    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        log "Non-interactive mode: skipping reboot prompt."
        return 0
    fi

    read -r -p "Reboot now? (y/n): " reboot_choice
    if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
        log "Rebooting now..."
        reboot
    fi
}

run_post_install_checks() {
    local doctor_script="${SCRIPT_DIR}/exp_doctor.sh"
    local smoke_script="${SCRIPT_DIR}/exp_post_install_smoke_test.sh"

    if [[ "$RUN_DOCTOR" -eq 1 ]]; then
        if [[ ! -x "$doctor_script" ]]; then
            warn "Doctor script not found: ${doctor_script}"
            return 0
        fi

        log "Running post-install doctor workflow..."
        if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
            "$doctor_script" --yes || warn "Doctor workflow reported issues. Review its report output."
        else
            "$doctor_script" || warn "Doctor workflow reported issues. Review its report output."
        fi
        return 0
    fi

    if [[ "$RUN_SMOKE_TEST" -eq 1 ]]; then
        if [[ ! -x "$smoke_script" ]]; then
            warn "Smoke test script not found: ${smoke_script}"
            return 0
        fi

        log "Running post-install smoke test..."
        "$smoke_script" || warn "Smoke test reported failures. Review its report output."
    fi
}

main() {
    local run_main

    parse_args "$@"
    validate_args

    require_root
    detect_boot_paths

    echo "Expanded Seeed ReSpeaker installation"
    echo "This script performs a single-pass install and configures one overlay."

    if [[ "$AUTO_CONFIRM" -ne 1 ]]; then
        read -r -p "Continue? (yes/no): " run_main
        if [[ "$run_main" != "yes" ]]; then
            log "Installation aborted by user."
            return 0
        fi
    fi

    prompt_for_system_update
    ensure_dependencies
    choose_mic_model

    run_base_driver_install
    install_selected_overlay
    configure_boot
    configure_modules
    install_runtime_files
    add_invoking_user_to_groups

    depmod -a || warn "depmod failed; kernel module dependency map may be stale until reboot."

    run_post_install_checks
    post_install_summary
    prompt_reboot
}

main "$@"
