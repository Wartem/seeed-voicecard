#!/bin/bash

# Uninstall script for Seeed ReSpeaker HAT

set -e

SEEED_VOICECARD_ROOT="$(dirname "$(dirname "$0")")"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 1>&2
   exit 1
fi

OVERLAYS=/boot/overlays
[ -d /boot/firmware/overlays ] && OVERLAYS=/boot/firmware/overlays

CONFIG=/boot/config.txt
[ -f /boot/firmware/config.txt ] && CONFIG=/boot/firmware/config.txt
[ -f /boot/firmware/usercfg.txt ] && CONFIG=/boot/firmware/usercfg.txt

expanded_uninstall() {
    echo "Uninstalling Seeed ReSpeaker HAT..."

    # Remove DKMS modules
    echo "Removing DKMS modules..."
    dkms remove -m seeed-voicecard -v 0.3 --all || true

    # Remove dtbo files
    echo "Removing dtbo files..."
    rm -f "$OVERLAYS/seeed-2mic-voicecard.dtbo"
    rm -f "$OVERLAYS/seeed-4mic-voicecard.dtbo"
    rm -f "$OVERLAYS/seeed-6mic-voicecard.dtbo"
    rm -f "$OVERLAYS/seeed-8mic-voicecard.dtbo"

    # Remove kernel modules
    echo "Removing kernel modules..."
    rm -f /lib/modules/*/updates/dkms/snd-soc-wm8960.ko
    rm -f /lib/modules/*/updates/dkms/snd-soc-ac108.ko
    rm -f /lib/modules/*/updates/dkms/snd-soc-seeed-voicecard.ko

    # Remove entries from /etc/modules
    echo "Updating /etc/modules..."
    sed -i '/snd-soc-seeed-voicecard/d' /etc/modules
    sed -i '/snd-soc-ac108/d' /etc/modules
    sed -i '/snd-soc-wm8960/d' /etc/modules

    # Remove dtoverlay entries from config.txt
    echo "Updating $CONFIG..."
    sed -i '/dtoverlay=seeed-2mic-voicecard/d' $CONFIG
    sed -i '/dtoverlay=seeed-4mic-voicecard/d' $CONFIG
    sed -i '/dtoverlay=seeed-6mic-voicecard/d' $CONFIG
    sed -i '/dtoverlay=seeed-8mic-voicecard/d' $CONFIG
    sed -i '/dtoverlay=i2s-mmap/d' $CONFIG

    # Remove configuration files
    echo "Removing configuration files..."
    rm -rf /etc/voicecard

    # Remove seeed-voicecard binary and service
    echo "Removing seeed-voicecard binary and service..."
    rm -f /usr/bin/seeed-voicecard
    rm -f /lib/systemd/system/seeed-voicecard.service

    # Remove blacklist entry
    echo "Removing audio driver blacklist..."
    sed -i '/blacklist snd_bcm2835/d' /etc/modprobe.d/raspi-blacklist.conf

    echo "Expanded uninstallation completed."
}

main_uninstall(){
    # Run the existing uninstall.sh script if it exists
    if [ -f "$SEEED_VOICECARD_ROOT/uninstall.sh" ]; then
        echo "Running existing uninstall.sh script..."
        "$SEEED_VOICECARD_ROOT/uninstall.sh"
    else
        echo "No existing uninstall.sh script found in $SEEED_VOICECARD_ROOT. Skipping."
    fi
}

# Main execution
echo "This script will uninstall the Seeed Voice Card and perform additional cleanup."

# Prompt for main uninstall
read -p "Do you want to run the main seeed-voicecard uninstall script? (yes/no): " run_main
if [[ $run_main == "yes" ]]; then
    main_uninstall
else
    echo "Skipping the main seeed-voicecard uninstall script."
fi

# Prompt for expanded uninstall
read -p "Do you want to run the expanded uninstall to remove additional configurations? (yes/no): " run_expanded
if [[ $run_expanded == "yes" ]]; then
    expanded_uninstall
else
    echo "Skipping the expanded uninstall."
fi

echo "Uninstallation process completed."
read -p "Do you want to reboot now? (y/n): " reboot_choice
if [[ $reboot_choice =~ ^[Yy]$ ]]; then
    echo "Rebooting now..."
    reboot
else
    echo "Please remember to reboot your Raspberry Pi to apply all changes."
fi