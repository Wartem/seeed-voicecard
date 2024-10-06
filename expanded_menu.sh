#!/bin/bash

# Function to run the installation script
run_install() {
    echo "Running expanded installation script..."
    sudo ./expanded/exp_install.sh
}

# Function to run the uninstallation script
run_uninstall() {
    echo "Running expanded uninstallation script..."
    sudo ./expanded/exp_uninstall.sh
}

# Function to run the diagnostics script
run_diagnostics() {
    echo "Running expanded diagnostics script..."
    sudo ./expanded/exp_diagnostics_and_tests.sh
}

# Main menu function
show_menu() {
    clear 
    echo "=== Expanded Menu ==="
    echo "1) Install"
    echo "2) Uninstall"
    echo "3) Diagnostics and Tests"
    echo "4) Exit"
    echo "====================="
}

# Main loop

# Convert DOS line endings to Unix and ensure all scripts in the expanded directory are executable
chmod +x expanded/*.sh

while true; do
    show_menu
    read -p "Enter your choice (1-4): " choice

    case $choice in
        1) run_install ;;
        2) run_uninstall ;;
        3) run_diagnostics ;;
        4) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac

    echo
    read -p "Press Enter to continue..."
done