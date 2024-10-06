#!/bin/bash

# Expanded Test script for ReSpeaker devices with comprehensive diagnostics

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 1>&2
   exit 1
fi

show_general_system_info() {
    echo "Gathering detailed system information..."

    echo -e "\n=== General System Info ==="
    uname -a
    cat /etc/os-release
    echo "Kernel version: $(uname -r)"
    echo "CPU Info:"
    cat /proc/cpuinfo | grep "model name" | uniq
    echo "Total RAM: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "Available RAM: $(free -h | awk '/^Mem:/ {print $7}')"

    echo -e "\n=== Disk Space Info ==="
    df -h

    echo -e "\n=== Network Interfaces ==="
    ip addr show
    echo "Routing table (route -n):"
    route -n
    echo "Network Configuration (ifconfig):"
    ifconfig -a

    echo -e "\n=== USB Devices ==="
    lsusb

    echo -e "\n=== I2C Devices ==="
    echo "Detecting I2C devices on bus 1:"
    i2cdetect -y 1

    echo -e "\n=== GPIO Status ==="
    gpio readall

    echo -e "\n=== System Logs (dmesg) ==="
    dmesg | tail -n 50

    echo -e "\n=== Mounted Filesystems ==="
    mount

    echo -e "\n=== Uptime Information ==="
    uptime

    echo -e "\n=== CPU Load Average ==="
    cat /proc/loadavg

    echo -e "\n=== Running Processes ==="
    ps aux --sort=-%mem | head -n 10

    echo -e "\n=== Systemd Services Status ==="
    systemctl list-units --type=service --state=running --no-pager
}

show_audio_info() {
    echo "Gathering detailed audio system information..."

    echo -e "\n=== ALSA Information ==="
    echo "ALSA Cards:"
    cat /proc/asound/cards
    echo "Playback Devices (aplay -l):"
    aplay -l
    echo "Recording Devices (arecord -l):"
    arecord -l
    echo "ALSA version:"
    alsactl --version
    echo "ALSA Mixer:"
    amixer

    echo -e "\n=== PulseAudio Information ==="
    pulseaudio --version
    pactl info
    echo "PulseAudio Sinks:"
    pactl list sinks short
    echo "PulseAudio Sources:"
    pactl list sources short

    echo -e "\n=== Sound Modules Loaded ==="
    echo "Checking loaded sound-related modules (snd):"
    lsmod | grep snd

    echo -e "\n=== Device Tree Overlays ==="
    vcdbg log msg | grep -i seeed

    echo -e "\n=== Kernel Messages (dmesg) for ReSpeaker ==="
    dmesg | grep -i "seeed\|respeaker\|wm8960"

    echo -e "\n=== Audio Configuration Files ==="
    echo "Content of /etc/asound.conf:"
    cat /etc/asound.conf 2>/dev/null || echo "File not found"
    echo -e "\nContent of ~/.asoundrc:"
    cat ~/.asoundrc 2>/dev/null || echo "File not found"

    echo -e "\n=== List of All Audio Related Packages ==="
    dpkg --list | grep "alsa\|pulse\|audio"

    echo -e "\n=== PCM Devices and Playback Testing ==="
    echo "PCM Devices (aplay -L):"
    aplay -L
    echo "Testing audio playback (speaker-test)..."
    speaker-test -t wav -l 1
}

run_alsamixer() {
    echo alsamixer
}

# Function to play a system sound
play_system_sound() {
    echo "Playing system sound..."

    # Example sound file path (adjust based on your system)
    sound_file="/usr/share/sounds/alsa/Front_Center.wav"

    if [ -f "$sound_file" ]; then
        aplay "$sound_file"
        echo "System sound playback completed."
    else
        echo "System sound file not found."
    fi
}

# Function to play a simple beep sound
play_beep_sound() {
    echo "Playing beep sound..."
    speaker-test -t sine -f 1000 -l 1
    echo "Beep sound test completed."
}

# Function to play a simple beep sound
play_beep_sound() {
    echo "Playing beep sound..."
    speaker-test -t sine -f 1000 -l 1
    echo "Beep sound test completed."
}

# Function to test audio recording once
test_recording_simple() {
    echo "Testing audio recording..."

    # Default format and sample rate
    format=S16_LE
    rate=44100

    echo "Recording audio: Format $format, Rate $rate Hz (Speak for 5 seconds)"
    arecord -D plughw:0,0 -f $format -r $rate -d 5 -c 2 test_recording.wav

    echo "Playing back the recorded audio..."
    aplay test_recording.wav

    # Test complete
    echo "Audio recording test completed."
    rm test_recording.wav
}

# Function to test the first microphone in the array
test_mic_array_simple() {
    echo "Testing microphone array..."

    # Using card 0 (default) and microphone 0 (default) as standard values
    card=0
    mic=0

    echo "Testing microphone $mic on card $card (Speak for 3 seconds)"
    arecord -D hw:$card,$mic -d 3 -f S16_LE -r 16000 -c 1 mic_test.wav

    echo "Playing back recording from microphone $mic"
    aplay mic_test.wav

    # No user input required, just check if the process works
    echo "Microphone $mic on card $card test completed."
}

# Added new submenu for package info and installation
display_package_info_menu() {
    clear
    echo "====================================================="
    echo "            Package Info and Installation"
    echo "====================================================="
    echo "1. Show alsa-utils Info"
    echo "2. Show i2c-tools Info"
    echo "3. Show libasound2-dev Info"
    echo "4. Show portaudio19-dev Info"
    echo "5. Install All Packages"
    echo "6. Back to Main Menu"
    echo "====================================================="
    echo "Please enter your choice (1-6):"
}

# Show package information functions
show_alsa_utils_info() {
    echo -e "\n=== alsa-utils ==="
    apt show alsa-utils
}

show_i2c_tools_info() {
    echo -e "\n=== i2c-tools ==="
    apt show i2c-tools
}

show_libasound2_dev_info() {
    echo -e "\n=== libasound2-dev ==="
    apt show libasound2-dev
}

show_portaudio19_dev_info() {
    echo -e "\n=== portaudio19-dev ==="
    apt show portaudio19-dev
}

# Install all relevant packages
install_all_packages() {
    echo "Installing alsa-utils, i2c-tools, libasound2-dev, portaudio19-dev..."
    apt update
    apt install -y alsa-utils i2c-tools libasound2-dev portaudio19-dev
    echo "Installation completed."
}

# Handle Package Info and Installation menu
handle_package_info_menu() {
    while true; do
        display_package_info_menu
        read -r choice
        case $choice in
            1) show_alsa_utils_info; press_enter_to_continue ;;
            2) show_i2c_tools_info; press_enter_to_continue ;;
            3) show_libasound2_dev_info; press_enter_to_continue ;;
            4) show_portaudio19_dev_info; press_enter_to_continue ;;
            5) install_all_packages; press_enter_to_continue ;;
            6) break ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Function to test audio playback
test_mic_array_advanced() {
    echo "Testing microphone array..."

    # List all cards with 'seeed' and allow the user to pick one
    arecord -l | grep -i seeed
    echo "Please enter the card number you want to test (e.g., 1):"
    read -r card

    # Get the number of channels for the chosen card
    local channels=$(arecord -D plughw:$card,0 --dump-hw-params | grep "channels" | awk '{print $2}')
    echo "Detected $channels channels on card $card."

    # Allow the user to select which microphone to test
    echo "Please enter the microphone number you want to test (0 to $(($channels-1))):"
    read -r mic

    # Record a test from the selected microphone
    echo "Testing microphone $mic on card $card (Speak for 3 seconds)"
    arecord -D hw:$card,$mic -d 3 -f S16_LE -r 16000 -c 1 mic_test_${card}_${mic}.wav

    # Playback the recorded audio
    echo "Playing back recording from microphone $mic"
    aplay mic_test_${card}_${mic}.wav

    # Ask the user if the test was successful
    echo "Did you hear clear audio from microphone $mic? (y/n)"
    read -r mic_test_result

    if [ "$mic_test_result" = "y" ]; then
        echo "Microphone $mic on card $card test passed."
    else
        echo "Microphone $mic on card $card test failed or audio unclear."
    fi
}

# Function to test audio recording
test_recording_advanced() {
    echo "Testing audio recording..."

    # Let the user choose the audio format and rate
    echo "Enter the audio format you want to test (e.g., S16_LE, S24_LE, S32_LE):"
    read -r format

    echo "Enter the sample rate you want to test (e.g., 44100, 48000, 96000):"
    read -r rate

    # Perform the recording based on user input
    echo "Testing recording: Format $format, Rate $rate Hz (Speak for 5 seconds)"
    arecord -D plughw:0,0 -f $format -r $rate -d 5 -c 2 test_${format}_${rate}.wav

    # Playback the recorded audio
    echo "Playing back the recorded audio..."
    aplay test_${format}_${rate}.wav

    # Ask the user if the test was successful
    echo "Did you hear your recording clearly? (y/n)"
    read -r heard_recording

    if [ "$heard_recording" = "y" ]; then
        echo "Audio recording test passed for $format at $rate Hz."
    else
        echo "Audio recording test failed for $format at $rate Hz."
    fi

    # Clean up the test file
    rm test_${format}_${rate}.wav
}

#If the service file has incorrect permissions, fix them:
#bashCopysudo chmod 644 /lib/systemd/system/seeed-voicecard.service
#sudo systemctl daemon-reload

# Function to reload audio modules
reload_audio_modules() {
    echo "Reloading audio modules..."
    rmmod snd_soc_seeed_voicecard
    rmmod snd_soc_wm8960
    modprobe snd_soc_wm8960
    modprobe snd_soc_seeed_voicecard
    echo "Audio modules reloaded. Checking status:"
    lsmod | grep "seeed\|wm8960"
}

# Function to test PulseAudio interference
check_pulseaudio() {
    echo "Checking for PulseAudio interference..."
    pulseaudio --kill
    echo "PulseAudio killed. Testing ALSA directly..."
    aplay -D plughw:0,0 /usr/share/sounds/alsa/Front_Center.wav
    echo "Did the audio play after PulseAudio was killed? (y/n)"
    read pulseaudio_result
    if [ "$pulseaudio_result" = "y" ]; then
        echo "Audio works without PulseAudio. PulseAudio may be interfering with ALSA."
    else
        echo "Audio still not working without PulseAudio. The issue may be with ALSA configuration."
    fi
    echo "Restarting PulseAudio..."
    pulseaudio --start
    echo "Testing audio with PulseAudio..."
    paplay /usr/share/sounds/alsa/Front_Center.wav
    echo "Did the audio play with PulseAudio? (y/n)"
    read pulseaudio_play_result
    if [ "$pulseaudio_play_result" = "y" ]; then
        echo "Audio works with PulseAudio."
    else
        echo "Audio not working with PulseAudio. Further investigation needed."
    fi
}

# Function to test ALSA mixer settings
check_alsa_mixer() {
    echo "Checking and setting ALSA mixer settings..."
    echo amixer -c 0 sset 'Headphone',0 100%
    echo amixer -c 0 sset 'Speaker',0 100%
    echo amixer -c 0 sset 'Playback',0 100%
    echo amixer -c 0 sset 'Capture',0 100%
    echo "Current ALSA mixer settings:"
    amixer -c 0 scontents
}

test_leds() {
    echo "Testing LED functionality..."
    
    # Check if the LED sysfs interface exists
    if [ -d "/sys/class/leds" ]; then
        for led in /sys/class/leds/*; do
            if [ -d "$led" ]; then
                led_name=$(basename "$led")
                echo "Testing LED: $led_name"
                
                # Turn LED on
                echo 255 > "$led/brightness"
                sleep 1
                
                # Turn LED off
                echo 0 > "$led/brightness"
                sleep 1
            fi
        done
        
        # Ask user if the LEDs worked
        echo "LED test completed. Did you see the LEDs light up? (y/n)"
        read led_test_result
        if [ "$led_test_result" = "y" ]; then
            echo "LED test passed."
        else
            echo "LED test failed or LEDs not visible."
        fi
    else
        echo "LED sysfs interface not found. Unable to test LEDs."
    fi
}

# Function to test audio recording with various formats and rates
test_recording_advanced() {
    echo "Advanced Audio Recording Test"

    # Array of formats and rates to test
    formats=("S16_LE" "S24_LE" "S32_LE")
    rates=(16000 44100 48000)

    for format in "${formats[@]}"; do
        for rate in "${rates[@]}"; do
            echo "Testing: Format $format, Rate $rate Hz"
            filename="test_${format}_${rate}.wav"
            
            arecord -D plughw:0,0 -f "$format" -r "$rate" -d 3 -c 2 "$filename"
            
            echo "Recording complete. Playing back..."
            aplay "$filename"
            
            echo "Did the playback sound clear? (y/n)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                echo "Test passed for $format at $rate Hz"
            else
                echo "Test failed for $format at $rate Hz"
            fi
            
            rm "$filename"
        done
    done

    echo "Advanced audio recording test completed."
}

# Function to test each microphone in the array individually
test_mic_array_comprehensive() {
    echo "Comprehensive Microphone Array Test"

    # Detect ReSpeaker card
    card=$(arecord -l | grep -i seeed | awk -F':' '{print $1}' | awk '{print $2}')
    if [ -z "$card" ]; then
        echo "ReSpeaker card not detected. Please check the connection."
        return 1
    fi

    echo "ReSpeaker card detected: $card"

    # Get number of channels
    channels=$(arecord -D plughw:$card,0 --dump-hw-params | grep "channels" | awk '{print $2}')
    echo "Detected $channels channels."

    for mic in $(seq 0 $((channels-1))); do
        echo "Testing microphone $mic"
        filename="mic_test_${card}_${mic}.wav"
        
        arecord -D hw:$card,$mic -d 3 -f S16_LE -r 16000 -c 1 "$filename"
        
        echo "Playing back recording from microphone $mic"
        aplay "$filename"
        
        echo "Was the audio clear for microphone $mic? (y/n)"
        read -r mic_test_result
        if [[ "$mic_test_result" =~ ^[Yy]$ ]]; then
            echo "Microphone $mic test passed."
        else
            echo "Microphone $mic test failed or audio unclear."
        fi
        
        rm "$filename"
    done

    echo "Comprehensive microphone array test completed."
}

# Function to test audio playback with various audio files
test_audio_playback() {
    echo "Audio Playback Test"

    # Array of test tones and frequencies
    tones=(100 1000 10000)

    for tone in "${tones[@]}"; do
        echo "Generating $tone Hz test tone..."
        sox -n -r 44100 -b 16 "test_tone_${tone}.wav" synth 3 sine $tone

        echo "Playing $tone Hz test tone..."
        aplay "test_tone_${tone}.wav"

        echo "Did you hear the $tone Hz tone clearly? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "Playback test passed for $tone Hz"
        else
            echo "Playback test failed for $tone Hz"
        fi

        rm "test_tone_${tone}.wav"
    done

    echo "Audio playback test completed."
}

# Main function to run all tests
run_all_tests() {
    echo "Running all ReSpeaker HAT tests..."
    test_recording_advanced
    test_mic_array_comprehensive
    test_audio_playback
    echo "All tests completed."
}

# Function to check for firmware updates and display relevant repositories
check_firmware_updates() {
    # List of interesting repositories

    echo -e "\nRelevant repositories for updates and information:"
    echo "1. Original Seeed ReSpeaker: https://github.com/respeaker/seeed-voicecard"
    echo "2. HinTak's fork: https://github.com/HinTak/seeed-voicecard"
    
    echo -e "\nIf this fork doesn't work, please check the following repositories."
    echo "For the latest updates, search GitHub for terms such as:"
    echo -e "\t\"seeed\", \"seeed-voicecard\", and related keywords."
    echo "Additionally, consider using tools like Perplexity AI to assist in your research."
    
    # Placeholder for actual update mechanism
    echo -e "\nTo update, you may need to manually clone and install from the desired repository."
    echo "First make sure an update is available."
    echo "Then do this, for example:"
    echo "git clone https://github.com/HinTak/seeed-voicecard"
    echo "cd seeed-voicecard"
    echo "sudo ./install.sh"
}

# Updated Main Menu with Package Info and Installation option
display_main_menu() {
    clear
    echo "====================================================="
    echo "    ReSpeaker HAT Diagnostic and Test Tool for Raspberry Pi"
    echo "====================================================="
    echo "1. System Information"
    echo "2. Audio Tests"
    echo "3. Hardware Tests"
    echo "4. Maintenance"
    echo "5. Package Info and Installation"
    echo "6. Exit"
    echo "====================================================="
    echo "Please enter your choice (1-6):"
}

# System Information sub-menu
display_system_info_menu() {
    clear
    echo "====================================================="
    echo "             System Information Menu"
    echo "====================================================="
    echo "1. Show General System Info"
    echo "2. Show Detailed Audio Info"
    echo "3. Back to Main Menu"
    echo "====================================================="
    echo "Please enter your choice (1-3):"
}

display_audio_tests_menu() {
    clear
    echo "====================================================="
    echo "                 Audio Tests Menu"
    echo "====================================================="
    echo "1. Play System Sound"
    echo "2. Play Loud Beep Sound"
    echo "3. Test Microphone Array (Simple)"
    echo "4. Test Microphone Array (Advanced)"
    echo "5. Test Audio Recording (Simple)"
    echo "6. Test Audio Recording (Advanced)"
    echo "7. Test Microphone Array (Comprehensive)"
    echo "8. Test Audio Playback"
    echo "9. Run All Tests"
    echo "10. Back to Main Menu"
    echo "====================================================="
    echo "Please enter your choice (1-10):"
}

# Hardware Tests sub-menu
display_hardware_tests_menu() {
    clear
    echo "====================================================="
    echo "               Hardware Tests Menu"
    echo "====================================================="
    echo "1. Test LEDs"
    echo "2. Check ALSA Mixer Settings"
    echo "3. Back to Main Menu"
    echo "====================================================="
    echo "Please enter your choice (1-3):"
}

# Maintenance sub-menu
display_maintenance_menu() {
    clear
    echo "====================================================="
    echo "               Maintenance Menu"
    echo "====================================================="
    echo "1. Reload Audio Modules"
    echo "2. Check PulseAudio Interference (not installed by default)"
    echo "3. Check for Firmware Updates"
    echo "4. Run Alsamixer"
    echo "5. Back to Main Menu"
    echo "====================================================="
    echo "Please enter your choice (1-5):"
}

# Function to handle System Information menu
handle_system_info_menu() {
    while true; do
        display_system_info_menu
        read -r choice
        case $choice in
            1) show_general_system_info; press_enter_to_continue ;;
            2) show_audio_info; press_enter_to_continue ;;
            3) break ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Function to handle Audio Tests menu
handle_audio_tests_menu() {
    while true; do
        display_audio_tests_menu
        read -r choice
        case $choice in
            1) play_system_sound; press_enter_to_continue ;;
            2) play_beep_sound; press_enter_to_continue ;;
            3) test_mic_array_simple; press_enter_to_continue ;;
            4) test_mic_array_advanced; press_enter_to_continue ;;
            5) test_recording_simple; press_enter_to_continue ;;
            6) test_recording_advanced; press_enter_to_continue ;;
            7) test_mic_array_comprehensive; press_enter_to_continue ;;
            8) test_audio_playback; press_enter_to_continue ;;
            9) run_all_tests; press_enter_to_continue ;;
            10) break ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Function to handle Hardware Tests menu
handle_hardware_tests_menu() {
    while true; do
        display_hardware_tests_menu
        read -r choice
        case $choice in
            1) test_leds; press_enter_to_continue ;;
            2) check_alsa_mixer; press_enter_to_continue ;;
            3) break ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Function to handle Maintenance menu
handle_maintenance_menu() {
    while true; do
        display_maintenance_menu
        read -r choice
        case $choice in
            1) reload_audio_modules; press_enter_to_continue ;;
            2) check_pulseaudio; press_enter_to_continue ;;
            3) check_firmware_updates; press_enter_to_continue ;;
            4) alsamixer; press_enter_to_continue ;;
            5) break ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

press_enter_to_continue() {
    echo ""
    read -p "Press Enter to continue..."
}

# Main function to run the script
handle_main_menu() {
    while true; do
        display_main_menu
        read -r choice
        case $choice in
            1) handle_system_info_menu ;;
            2) handle_audio_tests_menu ;;
            3) handle_hardware_tests_menu ;;
            4) handle_maintenance_menu ;;
            5) handle_package_info_menu ;;
            6) exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Start the script
handle_main_menu