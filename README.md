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

# seeed-voicecard (Extended)

Community-maintained ReSpeaker voicecard drivers and tooling for Raspberry Pi,
with practical support improvements for Raspberry Pi 4 and 5.

This repository includes:
- Kernel driver sources and DKMS install path
- Device tree overlays for ReSpeaker configurations
- Single-pass expanded installer/uninstaller
- Headless-friendly diagnostics, smoke test, and doctor workflow
- Terminal-first CLI wrapper (optional)

## Supported Hardware and Scope

Primary target in this fork:
- Raspberry Pi 4 and Raspberry Pi 5
- ReSpeaker 2-Mic Pi HAT
- ReSpeaker 4-Mic Array
- ReSpeaker 6-Mic/8-Mic circular configurations

Notes:
- 6-mic selection currently maps to the `seeed-8mic-voicecard` overlay path in this fork.
- This is still community-supported software. Validate behavior on your specific OS/kernel/device combination.

## Kernel Support

Validated in this fork:
- `6.6.51+rpt-rpi-2712` (Raspberry Pi 5)
- `6.12.62+rpt-rpi-2712` (Raspberry Pi 5)

How support works:
- Installer registers driver sources in DKMS.
- DKMS builds modules for installed kernel headers.
- The running kernel (`uname -r`) loads its matching module set.

Compatibility updates in this fork include:
- API-guarded driver changes for 6.1/6.6/6.12 ASoC and driver callbacks.
- Overlay updates for 2-mic clock/MCLK handling needed on newer kernels.

## Quick Start

```bash
git clone https://github.com/Wartem/seeed-voicecard
cd seeed-voicecard
```

### Option 1: Interactive CLI Wrapper

```bash
./expanded_menu.sh
```

The wrapper:
- Works over SSH in a plain terminal (no `whiptail`/`dialog` dependency)
- Adds safety checks for conflicting runs
- Writes per-action logs and prints PASS/WARN/FAIL summaries
- Supports direct command mode:
  - `./expanded_menu.sh install-guided`
  - `./expanded_menu.sh install-quick`
  - `./expanded_menu.sh uninstall`
  - `./expanded_menu.sh diagnostics`
  - `./expanded_menu.sh smoke-test`
  - `./expanded_menu.sh doctor`
  - `./expanded_menu.sh help`

### Option 2: Direct CLI (source of truth)

Install (interactive):
```bash
sudo ./expanded/exp_install.sh
```

Install (non-interactive):
```bash
sudo ./expanded/exp_install.sh --yes --model 2 --update-mode none
```

Install + automatic validation:
```bash
sudo ./expanded/exp_install.sh --yes --model 2 --update-mode none --run-smoke-test
sudo ./expanded/exp_install.sh --yes --model 2 --update-mode none --run-doctor
```

Uninstall:
```bash
sudo ./expanded/exp_uninstall.sh
```

Diagnostics:
```bash
sudo ./expanded/exp_diagnostics_and_tests.sh
```

Smoke test:
```bash
sudo ./expanded/exp_post_install_smoke_test.sh
```

Doctor workflow:
```bash
sudo ./expanded/exp_doctor.sh
```

## Expanded Installer Flags

`expanded/exp_install.sh` supports:
- `--yes` / `--non-interactive`
- `--model <2|4|6|8>`
- `--update-mode <prompt|none|update|upgrade|full-upgrade>`
- `--run-smoke-test`
- `--run-doctor`
- `--reboot`

Show help:
```bash
./expanded/exp_install.sh --help
```

## What The Installer Does (Detailed)

`expanded/exp_install.sh` is the main one-pass installer for this fork.
At a high level it performs the following actions:

1. Validates execution context and arguments (`root`, model, update mode).
2. Detects boot/config locations (for example `/boot/firmware/config.txt` and overlays dir).
3. Optionally performs package update/upgrade according to `--update-mode`.
4. Ensures required dependencies are installed.
5. Selects and installs the requested ReSpeaker overlay (`2/4/6/8` mapping logic in script).
6. Updates boot config entries (I2S and selected dtoverlay).
7. Ensures required kernel module names are present in `/etc/modules`.
8. Installs runtime/helper files under system paths used by the voicecard stack.
9. Runs `depmod -a`.
10. Optionally runs post-install validation (`--run-smoke-test` or `--run-doctor`).
11. Prompts for reboot (or reboots automatically with `--reboot`).

This is designed to be idempotent for normal re-runs on the same host.

## Validation Workflows

### Smoke Test (`expanded/exp_post_install_smoke_test.sh`)

Checks core installation state and prints a clear verdict:
- Boot config entries and selected overlay
- Overlay file presence
- `/etc/modules` entries
- Service enabled/active
- ALSA device visibility
- Short record/playback smoke check

Outputs:
- `Verdict: PASS | WARN | FAIL`
- Recommended next actions on issues
- Timestamped report log (default: `expanded/logs/`)

### Doctor (`expanded/exp_doctor.sh`)

Guided validation and tuning workflow:
- Baseline smoke validation
- Recommends profile from overlay
- Runs capture matrix across formats/rates
- Collects basic quality metrics (signal/clipping/channel balance where possible)
- Applies recommended ALSA profile with backup
- Re-runs smoke validation and prints final verdict

Show help:
```bash
./expanded/exp_doctor.sh --help
```

### LED Test Scope

`expanded/exp_diagnostics_and_tests.sh` includes a generic LED test that toggles
entries found under `/sys/class/leds`.

On some systems this may only control Raspberry Pi status LEDs (for example
`ACT`/`PWR`) and not a ReSpeaker LED ring. ReSpeaker LEDs must be exposed by the
active kernel/device stack to be controllable through this interface.

## Logging

Most expanded workflows write timestamped logs.
Typical location:
- `expanded/logs/`

## Known Limitations

- Some setups may still require manual ALSA/mixer tuning depending on hardware and ambient noise.
- LED behavior can vary by board/revision and may not work uniformly.
- Community support quality depends on reproducible logs and hardware details provided in issues.

## Update Log

For ongoing history, see `CHANGELOG.md`.

### 2026-02-20

- Reworked expanded installer to single-pass, idempotent behavior.
- Added non-interactive installer flags (`--yes`, `--model`, `--update-mode`, `--run-smoke-test`, `--run-doctor`, `--reboot`).
- Reworked expanded uninstaller to deterministic full cleanup in one flow.
- Reworked diagnostics script menus and maintenance workflow integration.
- Added dedicated post-install smoke test script with PASS/WARN/FAIL verdicts and recommended next actions.
- Added doctor workflow script for guided validation + profile recommendation/application.
- Updated `builddtbo.sh` to build overlays from existing DTS files only.
- Improved runtime helper script path handling and safer symlink/file operations.
- Replaced `expanded_menu.sh` with a terminal-first CLI wrapper:
  - interactive menu and direct command mode
  - lock file to prevent concurrent wrapper sessions
  - conflict checks against active install/uninstall/diagnostic jobs
  - per-action log files and summary output

## Disclaimer

This project is experimental and community-supported. Use at your own risk.
Always keep backups before changing kernel/audio configuration on production devices.

## Credits

This fork builds on:
- Original Seeed ReSpeaker driver project
- Community maintenance by multiple contributors (including HinTak's fork)

Upstream product docs:
- https://wiki.seeedstudio.com/ReSpeaker/

## README CONTENT FROM ORIGINAL/UPSTREAM REPO BELOW:

Important:
- The section below is kept for historical/upstream context.
- Some commands/options there may be outdated for this fork.
- For this repository, use the install/validation flows documented above in this README.

### Install seeed-voicecard (upstream reference)

Get the seeed voice card source code and install all linux kernel drivers:

```bash
git clone https://github.com/respeaker/seeed-voicecard
cd seeed-voicecard
sudo ./install.sh
sudo reboot
```

### ReSpeaker Documentation (upstream reference)

Up to date documentation for reSpeaker products:
- https://wiki.seeedstudio.com/ReSpeaker/

### Coherence (upstream reference)

Estimate the magnitude squared coherence using Welch’s method.
Note: `CO 1-2` means coherence between channel 1 and channel 2.

```bash
sudo apt install python-numpy python-scipy python-matplotlib
python tools/coherence.py a.wav
```

Input file requirements:
- format: WAV (signed 16-bit PCM)
- channels: `>= 2`

### Uninstall seeed-voicecard (upstream reference)

If you want to upgrade the upstream driver, uninstall first:

```bash
sudo ./uninstall.sh
```

### Technical support scope (upstream reference)

Original upstream support scope was documented for:
- 32-bit Raspberry Pi OS
- 64-bit Raspberry Pi OS
- Raspberry Pi 3/4 official combinations

Anything beyond that scope is generally community-supported.
