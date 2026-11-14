#!/usr/bin/env bash
# Verifies the experimental PPE-only AX6 stock build config after make defconfig.
set -Eeuo pipefail
cfg="${1:-.config}"
[[ -f "$cfg" ]] || { echo "ERROR: no config: $cfg" >&2; exit 1; }
require() { grep -Fqx "$1" "$cfg" || { echo "ERROR: missing $1" >&2; exit 1; }; }
require 'CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6-stock=y'
require 'CONFIG_TARGET_SQUASHFS_BLOCK_SIZE=1024'
require 'CONFIG_PACKAGE_firewall4=y'
for forbidden in \
  'CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6=y' \
  'CONFIG_TARGET_MULTI_PROFILE=y' \
  'CONFIG_PACKAGE_kmod-nss-wifi-drv=y' \
  'CONFIG_ATH11K_NSS_WIFI=y'; do
  if grep -Fqx "$forbidden" "$cfg"; then
    echo "ERROR: forbidden PPE-only build option: $forbidden" >&2
    exit 1
  fi
done
if grep -Fqx 'CONFIG_PACKAGE_sing-box=y' "$cfg"; then
  echo 'ERROR: unexpected full sing-box in PPE hardware feasibility build' >&2
  exit 1
fi
echo 'OK: PPE-only feasibility config selects AX6 stock and excludes NSS Wi-Fi.'
