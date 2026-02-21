#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEEED_VOICECARD_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OVERLAYS=""
CONFIG=""

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

remove_overlay_runtime_state() {
    local overlay

    if command_exists dtoverlay; then
        for overlay in \
            seeed-2mic-voicecard \
            seeed-4mic-voicecard \
            seeed-6mic-voicecard \
            seeed-8mic-voicecard; do
            dtoverlay -r "$overlay" >/dev/null 2>&1 || true
        done
    fi
}

remove_overlay_files() {
    local overlay

    log "Removing overlay binaries from ${OVERLAYS}"
    for overlay in \
        seeed-2mic-voicecard \
        seeed-4mic-voicecard \
        seeed-6mic-voicecard \
        seeed-8mic-voicecard; do
        rm -f "${OVERLAYS}/${overlay}.dtbo"
    done
}

remove_boot_config_entries() {
    log "Removing Seeed-related lines from ${CONFIG}"

    remove_exact_line "dtoverlay=seeed-2mic-voicecard" "$CONFIG"
    remove_exact_line "dtoverlay=seeed-4mic-voicecard" "$CONFIG"
    remove_exact_line "dtoverlay=seeed-6mic-voicecard" "$CONFIG"
    remove_exact_line "dtoverlay=seeed-8mic-voicecard" "$CONFIG"
    remove_exact_line "dtoverlay=i2s-mmap" "$CONFIG"
    remove_exact_line "dtparam=i2s=on" "$CONFIG"
}

remove_module_config_entries() {
    log "Cleaning /etc/modules and blacklist entries"

    remove_exact_line "snd-soc-seeed-voicecard" /etc/modules
    remove_exact_line "snd-soc-ac108" /etc/modules
    remove_exact_line "snd-soc-wm8960" /etc/modules
    remove_exact_line "blacklist snd_bcm2835" /etc/modprobe.d/raspi-blacklist.conf
}

remove_service_and_runtime_files() {
    log "Removing service and runtime files"

    systemctl stop seeed-voicecard.service >/dev/null 2>&1 || true
    systemctl disable seeed-voicecard.service >/dev/null 2>&1 || true

    rm -f /usr/bin/seeed-voicecard
    rm -f /lib/systemd/system/seeed-voicecard.service
    rm -rf /etc/voicecard

    systemctl daemon-reload || true
}

remove_dkms_and_kernel_modules() {
    log "Removing DKMS state and installed modules"

    if command_exists dkms; then
        dkms remove -m seeed-voicecard -v 0.3 --all >/dev/null 2>&1 || true
    fi

    rm -rf /var/lib/dkms/seeed-voicecard
    rm -rf /usr/src/seeed-voicecard-0.3

    rm -f /lib/modules/*/updates/dkms/snd-soc-wm8960.ko
    rm -f /lib/modules/*/updates/dkms/snd-soc-ac108.ko
    rm -f /lib/modules/*/updates/dkms/snd-soc-seeed-voicecard.ko

    rm -f /lib/modules/*/kernel/sound/soc/codecs/snd-soc-wm8960.ko
    rm -f /lib/modules/*/kernel/sound/soc/codecs/snd-soc-ac108.ko
    rm -f /lib/modules/*/kernel/sound/soc/bcm/snd-soc-seeed-voicecard.ko
}

unload_modules() {
    modprobe -r snd_soc_seeed_voicecard >/dev/null 2>&1 || true
    modprobe -r snd_soc_wm8960 >/dev/null 2>&1 || true
    modprobe -r snd_soc_ac108 >/dev/null 2>&1 || true
}

prompt_reboot() {
    local reboot_choice

    echo
    echo "Uninstall completed. A reboot is recommended."
    read -r -p "Reboot now? (y/n): " reboot_choice
    if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
        log "Rebooting now..."
        reboot
    fi
}

main() {
    local run_main

    require_root
    detect_boot_paths

    echo "Expanded Seeed ReSpeaker uninstall"
    echo "This performs full cleanup in one pass."
    read -r -p "Continue? (yes/no): " run_main

    if [[ "$run_main" != "yes" ]]; then
        log "Uninstall aborted by user."
        return 0
    fi

    remove_overlay_runtime_state
    unload_modules
    remove_service_and_runtime_files
    remove_dkms_and_kernel_modules
    remove_overlay_files
    remove_boot_config_entries
    remove_module_config_entries

    depmod -a || warn "depmod failed; reboot is required before next audio test."

    if [[ -x "${SEEED_VOICECARD_ROOT}/uninstall.sh" ]]; then
        log "Note: legacy uninstall.sh exists at ${SEEED_VOICECARD_ROOT}/uninstall.sh but was not required."
    fi

    prompt_reboot
}

main "$@"
