#!/bin/bash

# This script updates your Linux system and installs the Seeed ReSpeaker HAT.
# Updating is recommended to ensure compatibility, security, and performance.
# The script will update system packages, enable necessary interfaces,
# set up device tree overlays, compile and install drivers, and configure
# sound card modules. A system reboot is required after installation.

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

# Function to check if a kernel module exists
check_module_exists() {
    if lsmod | grep -q "^$1"; then
        return 0
    else
        return 1
    fi
}

# Function to safely add a line to a file if it doesn't exist
add_line_if_not_exists() {
    grep -qxF "$1" "$2" || echo "$1" >> "$2"
}

# Function to update the configuration line
update_config_line() {
    local config_file="/boot/firmware/config.txt"
    local line_to_add="$1"
    local temp_file="/tmp/temp_config.txt"

    if [ ! -f "$config_file" ]; then
        echo "Error: Config file $config_file not found."
        return 1
    fi

    awk -v line="$line_to_add" '
        $0 != line {print}
        END {print line}
    ' "$config_file" > "$temp_file"

    mv "$temp_file" "$config_file"

    echo "Updated $config_file with '$line_to_add'"
}

# Function to remove existing Seeed overlays
remove_existing_overlays() {
    local config_file="/boot/firmware/config.txt"
    local overlays=("seeed-2mic-voicecard" "seeed-4mic-voicecard" "seeed-6mic-voicecard" "seeed-8mic-voicecard")

    for current_overlay in "${overlays[@]}"; do
        sed -i "/dtoverlay=$current_overlay/d" "$config_file"
    done
    echo "Removed existing Seeed voicecard overlays from $config_file"
}

pre_install() {
    # Ensure DKMS is installed
    apt install -y dkms

    # Remove old DKMS modules if they exist
    #dkms remove -m seeed-voicecard -v 0.3 --all || true

    # Reinstall dtbo files if missing
    #for dtbo in seeed-2mic-voicecard.dtbo seeed-4mic-voicecard.dtbo seeed-8mic-voicecard.dtbo; do
        #if [ ! -f "$OVERLAYS/$dtbo" ]; then
            #echo "Reinstalling $dtbo"
            #cp "$SEEED_VOICECARD_ROOT/$dtbo" "$OVERLAYS/"
        #fi
    #done

    # Remove old kernel modules if they exist
    #rm -f /lib/modules/*/updates/dkms/snd-soc-wm8960.ko
    #rm -f /lib/modules/*/updates/dkms/snd-soc-ac108.ko
    #rm -f /lib/modules/*/updates/dkms/snd-soc-seeed-voicecard.ko

    # Update /etc/modules
    
    for module in snd-soc-seeed-voicecard snd-soc-ac108 snd-soc-wm8960; do
        add_line_if_not_exists $module /etc/modules
    done

    # Update config.txt
    sed -i -e 's:#dtparam=i2c_arm=on:dtparam=i2c_arm=on:g' $CONFIG
    add_line_if_not_exists "dtoverlay=i2s-mmap" $CONFIG
    add_line_if_not_exists "dtparam=i2s=on" $CONFIG

    # Ensure config files are in place
    mkdir -p /etc/voicecard

    # Copy .conf files
    if ls "$SEEED_VOICECARD_ROOT"/*.conf 1>/dev/null 2>&1; then
        cp "$SEEED_VOICECARD_ROOT"/*.conf /etc/voicecard/
    else
        echo "Warning: No .conf files found in $SEEED_VOICECARD_ROOT"
    fi

    # Copy .state files
    if ls "$SEEED_VOICECARD_ROOT"/*.state 1>/dev/null 2>&1; then
        cp "$SEEED_VOICECARD_ROOT"/*.state /etc/voicecard/
    else
        echo "Warning: No .state files found in $SEEED_VOICECARD_ROOT"
    fi

    # Ensure seeed-voicecard binary and service are in place
    cp "$SEEED_VOICECARD_ROOT/seeed-voicecard" /usr/bin/
    cp "$SEEED_VOICECARD_ROOT/seeed-voicecard.service" /lib/systemd/system/
}

expanded_install_part_2() {
    echo "Building dtbo files..."
    "$SEEED_VOICECARD_ROOT/builddtbo.sh"

    echo "Compiling and installing the driver..."
    "$SEEED_VOICECARD_ROOT/install.sh"

    echo "Recompiling the Seeed voicecard driver..."
    make clean
    make
    make install
 
    echo "Building and installing dtbo file for $overlay..."
    dtc -@ -I dts -O dtb -o "/boot/overlays/${overlay}.dtbo" "$SEEED_VOICECARD_ROOT/${overlay}-overlay.dts"

    echo "Removing existing overlays"
    remove_existing_overlays

    echo "Setting up device tree overlay for $overlay..."
    update_config_line "dtoverlay=$overlay"
    update_config_line "dtparam=i2s=on"

    echo "Enabling I2C and SPI interfaces..."
    raspi-config nonint do_i2c 0
    raspi-config nonint do_spi 0

    echo "Configuring sound card modules and blacklisting default audio driver..."
    echo -e "snd-soc-seeed-voicecard\nsnd-soc-ac108\nsnd-soc-wm8960" | sudo tee -a /etc/modules
    echo "blacklist snd_bcm2835" | sudo tee -a /etc/modprobe.d/raspi-blacklist.conf

    echo "Adding user to audio and i2c groups..."
    usermod -a -G audio,i2c $SUDO_USER

    modprobe snd-soc-wm8960
    modprobe snd-soc-seeed-voicecard

    echo "Updating initramfs..."
    update-initramfs -u
    

    }

# Expanded Seeed ReSpeaker HAT installation
expanded_install() {
    echo "Welcome to this expanded Seeed ReSpeaker HAT installation script."
    echo "Do you want to update your system before install?"
    echo "1) Yes (recommended)"
    echo "2) No (skip updating)"
    read -p "Enter your choice (1 or 2): " update_choice

    if [ "$update_choice" != "2" ]; then
        echo "Updating the system..."
        apt update
        # Ensure required packages are installed
        # apt install -y dkms git i2c-tools libasound2-plugins raspberrypi-kernel-headers

        echo "Choose the type of system upgrade:"
        echo "1) Regular upgrade - apt upgrade (safer, recommended)"
        echo "2) Full upgrade - apt full-upgrade (more thorough, but may remove packages)"
        read -p "Enter your choice (1 or 2): " upgrade_choice

        if [ "$upgrade_choice" = "2" ]; then
            apt full-upgrade -y
        else
            apt upgrade -y
        fi
    else
        echo "Skipping system update."
    fi

    echo "Please select your ReSpeaker mic model:"
    echo "2) 2-Mics Pi HAT"
    echo "4) 4-Mics Pi HAT"
    echo "6) 6-Mics Circular Array Kit"
    echo "8) 8-Mics Circular Array Kit"
    read -p "Enter your choice (2-8): " mic_choice

    case $mic_choice in
        2) overlay="seeed-2mic-voicecard" ;;
        4) overlay="seeed-4mic-voicecard" ;;
        6) overlay="seeed-6mic-voicecard" ;;
        8) overlay="seeed-8mic-voicecard" ;;
        *) echo "Invalid choice. Exiting."; exit 1 ;;
    esac

    pre_install

    for i in {1..2}; do
        echo "Installing drivers run $i of 2"
        expanded_install_part_2
    done


    # Clean up any old dtbo files
    for old_overlay in seeed-2mic-voicecard seeed-4mic-voicecard seeed-6mic-voicecard seeed-8mic-voicecard; do
        if [ "$old_overlay" != "$overlay" ]; then
            rm -f "/boot/overlays/${old_overlay}.dtbo"
        fi
    done

    echo "Installation completed."
    echo "A reboot is required to apply all changes."
    echo "--- NOTE ---"
    echo "Running this installation one more time after reboot can sometimes solve issues."
    echo "--- NOTE ---"

    read -p "Do you want to reboot now? (y/n): " reboot_choice
    if [[ $reboot_choice =~ ^[Yy]$ ]]; then
        echo "Rebooting now..."
        reboot
    else
        echo "Installation completed."
        echo "A reboot is required to apply all changes."
        echo "If you use SSH, try raspberrypi.local as hostname if you get 'permission denied'."
        echo "┌─── NOTE ───────────────────────────────────────────────────────────────┐"
        echo "│ Running this installation 2 times with a booot in between              │"
        echo "│ can sometimes solve issues.                                            │"
        echo "└────────────────────────────────────────────────────────────────────────┘"
        echo "Don't forget to reboot your Raspberry Pi to apply all changes."
    fi
}

# Prompt for main install
echo ""
echo "Welcome to to the expanded installation."
echo "Note that success is not guaranteed." 
echo "Make sure to backup any and all important data before proceeding."
echo "In worst case secenario you will have to reflash your OS if it doesn't work." 
echo ""
read -p "Do you want to install now? (yes/no): " run_main
if [[ $run_main == "yes" ]]; then
    expanded_install
else
    echo "Skipping the installation."
fi