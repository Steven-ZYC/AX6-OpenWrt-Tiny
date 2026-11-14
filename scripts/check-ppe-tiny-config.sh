#!/usr/bin/env bash
# Enforce desired selections AFTER make defconfig; do not assume Kconfig accepted them.
set -Eeuo pipefail
cfg="${1:-.config}"
[[ -f "$cfg" ]] || { echo "ERROR: no generated config: $cfg" >&2; exit 1; }

require() { grep -Fqx "$1" "$cfg" || { echo "ERROR: missing required config: $1" >&2; exit 1; }; }
for option in   CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6-stock=y   CONFIG_TARGET_SQUASHFS_BLOCK_SIZE=1024   CONFIG_PACKAGE_ppe-help=y   CONFIG_PACKAGE_kmod-nft-offload=y   CONFIG_PACKAGE_kmod-nss-wifi-drv=y   CONFIG_ATH11K_NSS_WIFI=y   CONFIG_PACKAGE_nss-firmware-ipq807x=y   CONFIG_PACKAGE_tc-tiny=y   CONFIG_PACKAGE_kmod-sched-flower=y   CONFIG_PACKAGE_luci=y   CONFIG_PACKAGE_luci-ssl=y   CONFIG_PACKAGE_luci-theme-argon=y   CONFIG_PACKAGE_luci-app-homeproxy=y   CONFIG_PACKAGE_sing-box-tiny=y   CONFIG_PACKAGE_kmod-nft-tproxy=y   CONFIG_PACKAGE_firewall4=y; do
  require "$option"
done

for option in   CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6=y   CONFIG_TARGET_MULTI_PROFILE=y   CONFIG_PACKAGE_sing-box=y   CONFIG_PACKAGE_kmod-qca-nss-drv-64=y   CONFIG_PACKAGE_qca-nss-ecm=y   CONFIG_PACKAGE_kmod-shortcut-fe=y   CONFIG_PACKAGE_luci-app-ssr-plus=y; do
  if grep -Fqx "$option" "$cfg"; then echo "ERROR: forbidden: $option" >&2; exit 1; fi
done

# Guard against selecting NSS Wi-Fi without a matching firmware package.
grep -Fqx 'CONFIG_NSS_FIRMWARE_VERSION_12_5=y' "$cfg" || {
  echo 'ERROR: expected NSS 12.5 firmware selector absent' >&2; exit 1;
}
echo 'OK: PPE + NSS Wi-Fi + Tiny + HomeProxy + Argon stock layout requested.'
