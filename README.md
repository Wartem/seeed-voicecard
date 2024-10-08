# seeed-voicecard

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-A22846?style=for-the-badge&logo=Raspberry%20Pi&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![C](https://img.shields.io/badge/c-%2300599C.svg?style=for-the-badge&logo=c&logoColor=white)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)
![ALSA](https://img.shields.io/badge/ALSA-Audio-brightgreen?style=for-the-badge)
![ReSpeaker](https://img.shields.io/badge/ReSpeaker-Compatible-blue?style=for-the-badge)
![Debian](https://img.shields.io/badge/Debian-D70A53?style=for-the-badge&logo=debian&logoColor=white)
![ARM](https://img.shields.io/badge/ARM-0091BD?style=for-the-badge&logo=arm&logoColor=white)
![I2C](https://img.shields.io/badge/I2C-Enabled-yellowgreen?style=for-the-badge)
![SPI](https://img.shields.io/badge/SPI-Enabled-orange?style=for-the-badge)
![Kernel Module](https://img.shields.io/badge/Kernel-Module-lightgrey?style=for-the-badge)
![DKMS](https://img.shields.io/badge/DKMS-Supported-yellow?style=for-the-badge)
![Pi 4](https://img.shields.io/badge/Raspberry%20Pi%204-Supported-success?style=for-the-badge)
![Pi 5](https://img.shields.io/badge/Raspberry%20Pi%205-Supported-success?style=for-the-badge)

## Overview

This project provides extended drivers for ReSpeaker audio devices, specifically targeting Raspberry Pi 4 and 5. It's a fork of HinTak's fork of the official ReSpeaker drivers, with the goal of adding support for newer Raspberry Pi models and implementing diagnostics and tests.

## Current Status - Experimental

- **Compatibility**: Optimized for Raspberry Pi 4 and 5
- **Testing**: Successfully tested basic I/O audio on Raspberry Pi 5 with ReSpeaker 2-Mics Pi HAT
- **Environment**: 
  - Debian GNU/Linux 12 (bookworm) - Latest version as of 2024-10-01
  - Linux kernel: 6.6.51+rpt-rpi-2712 #1 SMP PREEMPT Debian 1:6.6.51-1+rpt2 (2024-10-01) aarch64 GNU/Linux
- **Functionality**: Supports audio recording and playback using ALSA

### Supported Devices

- [ReSpeaker 2-Mics Pi HAT](https://www.seeedstudio.com/ReSpeaker-2-Mics-Pi-HAT-p-2874.html)
- [ReSpeaker 4-Mics Pi HAT](https://www.seeedstudio.com/ReSpeaker-4-Mic-Array-for-Raspberry-Pi-p-2941.html)
- [ReSpeaker 6-Mics Circular Array Kit](https://www.seeedstudio.com/ReSpeaker-6-Mic-Circular-Array-Kit-for-Raspberry-Pi.html?srsltid=AfmBOooM2fDw69YjqGc_ZIQLruOYx043Ki6fqFli1His9ULooJ1SJJxt)
- [ReSpeaker 4-Mics Linear Array Kit](https://www.seeedstudio.com/ReSpeaker-4-Mic-Linear-Array-Kit-for-Raspberry-Pi.html)

## Features

- Extended support for Raspberry Pi 4 and 5
- Utilizes default ALSA drivers for audio functionality
- Maintains compatibility with Seeed 2-mic voice card (ReSpeaker HAT)
- Includes an expanded menu for easy installation, uninstallation, and diagnostics

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Wartem/seeed-voicecard
   ```
2. Navigate to the project directory:
   ```bash
   cd seeed-voicecard
   ```
3. Run the expanded menu script:
   ```bash
   sudo bash expanded_menu.sh
   ```
4. Follow the on-screen instructions to install, uninstall, or run diagnostics.

## Known Issues

- Clock configuration warning for WM8960 codec (does not affect basic functionality)
- LEDs are currently non-functional

## Troubleshooting

If you encounter issues, try running the installation multiple times. This has been known to resolve some problems.

## Uninstallation

Uninstallation can be performed through the expanded menu. Please note that this feature is still in development and may not be fully functional.

## Disclaimer

This project is a work in progress and is considered experimental. While initial testing has shown promising results, we cannot guarantee full functionality or stability at this stage. We strongly recommend thorough testing before using this in any production environment.

## More installation information
The expanded_install.sh script builds upon the original install.sh as it runs it as one of the steps. It adds more functionality and user interaction. Here's a summary of what this expanded script does:

1. Checks for root privileges.

2. Defines helper functions for various tasks like checking module existence, updating configuration files, and removing existing overlays.

3. Offers the user a choice to update the system before installation, including options for a regular upgrade or a full upgrade.

4. Allows the user to select their specific ReSpeaker mic model (2, 4, 6, or 8 mics).

5. Performs pre-installation tasks:
   - Ensures DKMS is installed
   - Updates /etc/modules with required sound modules
   - Updates the boot configuration file
   - Copies necessary configuration files to /etc/voicecard
   - Sets up the seeed-voicecard binary and service

6. Compiles and installs the driver twice (for redundancy):
   - Builds dtbo (Device Tree Blob Overlay) files
   - Compiles and installs the Seeed voicecard driver
   - Builds and installs the specific dtbo file for the chosen mic model
   - Removes existing overlays and sets up the new one
   - Enables I2C and SPI interfaces
   - Configures sound card modules and blacklists the default audio driver
   - Adds the user to audio and i2c groups
   - Updates the initramfs

7. Cleans up old dtbo files that aren't needed for the chosen model.

8. Offers the user a choice to reboot immediately or later.

9. Provides additional notes about potentially needing to run the installation twice for best results.

This expanded script aims to provide a comprehensive and user-friendly installation process for the Seeed ReSpeaker HAT, addressing potential issues that might arise due to system updates or specific hardware configurations.

## Acknowledgments

This project builds upon the work of the original ReSpeaker driver developers and HinTak's fork. We extend our gratitude for their foundational work.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.  
# 
# UNCHANGED README CONTENT FROM ORIGINAL/UPSTREAM REPO BELOW:

## ReSpeaker Documentation

Up to date documentation for reSpeaker products can be found in [Seeed Studio Wiki](https://wiki.seeedstudio.com/ReSpeaker/)!
![](https://files.seeedstudio.com/wiki/ReSpeakerProductGuide/img/Raspberry_Pi_Mic_Array_Solutions.png)

### Coherence

Estimate the magnitude squared coherence using Welch’s method.
![4-mics-linear-array-kit coherence](https://user-images.githubusercontent.com/3901856/37277486-beb1dd96-261f-11e8-898b-84405bfc7cea.png)  
Note: 'CO 1-2' means the coherence between channel 1 and channel 2.

```bash
# How to get the coherence of the captured audio(a.wav for example).
sudo apt install python-numpy python-scipy python-matplotlib
python tools/coherence.py a.wav

# Requirement of the input audio file:
- format: WAV(Microsoft) signed 16-bit PCM
- channels: >=2
```

### Technical support

For hardware testing purposes we made a Rasperry Pi OS 5.10.17-v7l+ 32-bit image with reSpeaker drivers pre-installed, which you can download by clicking on [this link](https://files.seeedstudio.com/linux/Raspberry%20Pi%204%20reSpeaker/2021-05-07-raspios-buster-armhf-lite-respeaker.img.xz).

We provide official support for using reSpeaker with the following OS:
- 32-bit Raspberry Pi OS
- 64-bit Raspberry Pi OS

And following hardware platforms:
- Raspberry Pi 3 (all models), Raspberry Pi 4 (all models)

Anything beyond the scope of official support is considered to be community supported. Support for other OS/hardware platforms can be added, provided MOQ requirements can be met. 

If you have a technical problem when using reSpeaker with one of the officially supported platforms/OS, feel free to create an issue on Github. For general questions or suggestions, please use [Seeed forum](https://forum.seeedstudio.com/c/products/respeaker/15). 
