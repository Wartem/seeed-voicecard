# seeed-voicecard

The drivers for [ReSpeaker Mic Hat](https://www.seeedstudio.com/ReSpeaker-2-Mics-Pi-HAT-p-2874.html), [ReSpeaker 4 Mic Array](https://www.seeedstudio.com/ReSpeaker-4-Mic-Array-for-Raspberry-Pi-p-2941.html), [6-Mics Circular Array Kit](), and [4-Mics Linear Array Kit]() for Raspberry Pi.

# Extended ReSpeaker Drivers for Raspberry Pi 4 and 5

This project is a fork of HinTak's fork of the official ReSpeaker drivers, extended with the goal of adding support for Raspberry Pi 4 and 5 and to create diagnostics and tests.

## Current Status

- **Compatibility**: Aimed at Raspberry Pi 4 and 5
- **Testing**: I/O Audio successfully tested on Raspberry Pi 5 using reSpeaker 2-Mics Pi HAT.
  Running:
    Latest version (2024-10-01) of Debian GNU/Linux 12 (bookworm).
      Linux raspberrypi 6.6.51+rpt-rpi-2712 #1 SMP PREEMPT Debian 1:6.6.51-1+rpt2 (2024-10-01) aarch64 GNU/Linux
- **Functionality**: Working audio recording and playback with default drivers

## Important Note

This is an experimental extension of the original and HinTak's drivers. While it has shown success in initial testing, there are no guarantees of full functionality or stability at this stage.

## Features

- Extended support for newer Raspberry Pi models (4 and 5)
- Utilizes default ALSA drivers for audio functionality
- Maintains compatibility with the Seeed 2-mic voice card (ReSpeaker HAT)

## Installation

Get the seeed voice card source code and install all linux kernel drivers
```bash
git clone https://github.com/Wartem/seeed-voicecard
cd seeed-voicecard
sudo ./expanded_menu.sh
```

## Known Issues

- Clock configuration warning for WM8960 codec (does not affect basic functionality)
- LED's not working.

## Troubleshooting

A common fix is to install mulitple times.

## Disclaimer

This is a work in progress. Use at your own risk. We recommend thorough testing before using in any production environment.

## Acknowledgments

This project builds upon the work of the original ReSpeaker driver developers. We extend our gratitude for their foundational work.

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

### uninstall seeed-voicecard
The goal is to support uninstall via the menu. No guarantees that it works yet.

### Technical support

For hardware testing purposes we made a Rasperry Pi OS 5.10.17-v7l+ 32-bit image with reSpeaker drivers pre-installed, which you can download by clicking on [this link](https://files.seeedstudio.com/linux/Raspberry%20Pi%204%20reSpeaker/2021-05-07-raspios-buster-armhf-lite-respeaker.img.xz).

We provide official support for using reSpeaker with the following OS:
- 32-bit Raspberry Pi OS
- 64-bit Raspberry Pi OS

And following hardware platforms:
- Raspberry Pi 3 (all models), Raspberry Pi 4 (all models)

Anything beyond the scope of official support is considered to be community supported. Support for other OS/hardware platforms can be added, provided MOQ requirements can be met. 

If you have a technical problem when using reSpeaker with one of the officially supported platforms/OS, feel free to create an issue on Github. For general questions or suggestions, please use [Seeed forum](https://forum.seeedstudio.com/c/products/respeaker/15). 
