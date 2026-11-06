#!/usr/bin/env bash
set -Eeuo pipefail
f="${1:-.config}"
[[ -f "$f" ]] || { echo "ERROR: no generated config: $f" >&2; exit 1; }

require() { grep -Fqx "$1" "$f" || { echo "ERROR: missing after make defconfig: $1" >&2; exit 1; }; }
for line in \
  'CONFIG_TARGET_DEVICE_qualcommax_ipq807x_DEVICE_redmi_ax6-stock=y' \
  'CONFIG_PACKAGE_luci-app-homeproxy=y' \
  'CONFIG_PACKAGE_luci-theme-argon=y' \
  'CONFIG_PACKAGE_sing-box-tiny=y' \
  'CONFIG_PACKAGE_kmod-nft-tproxy=y' \
  'CONFIG_SING_BOX_TINY_BUILD_UTLS=y' \
  'CONFIG_TARGET_SQUASHFS_BLOCK_SIZE=1024'; do
  require "$line"
done

if grep -Fxq 'CONFIG_TARGET_DEVICE_qualcommax_ipq807x_DEVICE_redmi_ax6=y' "$f"; then
  echo 'ERROR: expanded-layout AX6 profile selected! Refusing to build.' >&2; exit 1
fi
if grep -Fxq 'CONFIG_PACKAGE_sing-box=y' "$f"; then
  echo 'ERROR: full sing-box enabled. Refusing to build.' >&2; exit 1
fi
for feature in QUIC GVISOR WIREGUARD TAILSCALE GRPC; do
  if grep -Fxq "CONFIG_SING_BOX_TINY_BUILD_${feature}=y" "$f"; then
    echo "ERROR: unwanted feature ${feature} enabled. Refusing to build." >&2
    exit 1
  fi
done
echo 'OK: stock AX6 layout, Argon, HomeProxy and tiny core configuration selected.'
