# Changelog

All notable changes to this project should be documented in this file.

## 2026-02-21

### Added
- Validated kernel support for Raspberry Pi 5 on:
  - `6.6.51+rpt-rpi-2712`
  - `6.12.62+rpt-rpi-2712`

### Changed
- Converted `expanded_menu.sh` to a terminal-first CLI wrapper (removed `whiptail`/`dialog` backend behavior).
- Added direct command mode in `expanded_menu.sh` (`install-guided`, `install-quick`, `uninstall`, `diagnostics`, `smoke-test`, `doctor`, `help`).
- Updated top-level menu behavior so only `7) Exit` exits the app; `q` remains for cancellable sub-prompts.
- Changed default log output paths to workspace-local `expanded/logs` for:
  - `expanded_menu.sh`
  - `expanded/exp_post_install_smoke_test.sh`
  - `expanded/exp_doctor.sh`
- Updated `README.md` to match current CLI behavior and log locations.
- Updated 2-mic overlay clock configuration for newer kernel behavior:
  - added explicit `mclk` bindings/system-clock frequency and `simple-audio-card,mclk-fs`.
- Updated driver compatibility code paths to handle 6.1/6.6/6.12 kernel API differences in:
  - `seeed-voicecard.c`
  - `ac101.c`
  - `ac108.c`
  - `wm8960.c`

### Fixed
- Fixed menu rendering regression where prompt text disappeared in `expanded_menu.sh` command-substitution paths.
- Improved terminal state recovery in wrapper/menu flows (safer TTY handling).
- Normalized summary verdict parsing to avoid stray carriage-return artifacts in result output.
- Improved audio resource-conflict diagnostics across expanded workflows:
  - smoke/doctor/diagnostics now report busy ALSA capture/playback holders with PID/user/command details
  - busy-device cases now provide clearer actionable guidance.
- Fixed DKMS build/install failures on newer kernels by adding version-aware compatibility guards.

## 2026-02-20

### Added
- `expanded/exp_post_install_smoke_test.sh` for post-install PASS/WARN/FAIL validation.
- `expanded/exp_doctor.sh` for guided validation, profile recommendation, and tuning.
- Non-interactive installer options in `expanded/exp_install.sh`:
  - `--yes`, `--model`, `--update-mode`, `--run-smoke-test`, `--run-doctor`, `--reboot`.
- SSH-safe TUI wrapper behavior in `expanded_menu.sh`:
  - backend auto-detect (`whiptail`/`dialog`/text)
  - lock file protection
  - conflicting-process checks
  - per-action logs and result summaries

### Changed
- Reworked expanded install flow to single-pass, idempotent execution.
- Reworked expanded uninstall flow to deterministic one-pass cleanup.
- Reworked diagnostics/test menu and maintenance workflows.
- Updated `builddtbo.sh` to compile only overlays with existing DTS sources.
- Improved `seeed-voicecard` runtime helper path/symlink safety.
- Updated README with current usage and validation workflows.

### Notes
- 6-mic selection maps to the `seeed-8mic-voicecard` overlay path in this fork.
- CLI-only use remains fully supported; TUI wrapper is optional.
