#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DTC_FLAGS=(-b 0 -Wno-unit_address_vs_reg -I dts -O dtb)
BUILT_COUNT=0

if ! command -v dtc >/dev/null 2>&1; then
    echo "[ERROR] dtc (device-tree-compiler) is required but not installed." >&2
    exit 1
fi

cd "$SCRIPT_DIR"

for dts in \
    seeed-2mic-voicecard-overlay.dts \
    seeed-4mic-voicecard-overlay.dts \
    seeed-6mic-voicecard-overlay.dts \
    seeed-8mic-voicecard-overlay.dts; do
    [[ -f "$dts" ]] || continue

    dtbo="${dts%-overlay.dts}.dtbo"
    echo "[INFO] Building ${dtbo} from ${dts}"
    dtc -@ "${DTC_FLAGS[@]}" -o "$dtbo" "$dts"
    BUILT_COUNT=$((BUILT_COUNT + 1))
done

if [[ "$BUILT_COUNT" -eq 0 ]]; then
    echo "[ERROR] No overlay DTS files were found to compile." >&2
    exit 1
fi

echo "[INFO] Built ${BUILT_COUNT} overlay file(s)."
