#!/usr/bin/env bash
# Battery power tuning for HP Pavilion Plus (i5-12500H). Runs on boot + AC plug/unplug.
# PCIe ASPM is not touched: lockdown=integrity + BIOS block it.
set -euo pipefail

# powertop autotune: USB/audio/runtime PM (non-persistent, so reapply each run)
powertop --auto-tune >/dev/null 2>&1 || true

# CPU package power limit (RAPL PL1): stock 55W on AC, 22W cap on battery
RAPL=/sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw
if [ "$(cat /sys/class/power_supply/ADP1/online)" = 1 ]; then
  echo 55000000 > "$RAPL"
else
  echo 22000000 > "$RAPL"
fi
