#!/usr/bin/env bash
# Fail-closed AX6 stock variant audit: run after Kconfig and after image generation.
set -Eeuo pipefail
(( $# == 3 )) || { echo 'Usage: verify-ax6-variant.sh config|manifest tiny|tiny-plus FILE' >&2; exit 2; }
stage="$1"; variant="$2"; file="$3"
[[ "$stage" == config || "$stage" == manifest ]] || exit 2
[[ "$variant" == tiny || "$variant" == tiny-plus ]] || exit 2
[[ -f "$file" ]] || { echo "ERROR: missing $file" >&2; exit 1; }

if [[ "$stage" == config ]]; then
  has() { grep -Fqx "CONFIG_PACKAGE_$1=y" "$file"; }
  req() { grep -Fqx "$1" "$file" || { echo "ERROR: missing $1" >&2; exit 1; }; }
  req 'CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6-stock=y'
  req 'CONFIG_TARGET_SQUASHFS_BLOCK_SIZE=1024'
  req 'CONFIG_LUCI_LANG_zh_Hans=y'
  req 'CONFIG_ATH11K_NSS_WIFI=y'
  req 'CONFIG_NSS_FIRMWARE_VERSION_12_5=y'
else
  has() { awk '{print $1}' "$file" | grep -Fqx "$1"; }
  req() { has "$1" || { echo "ERROR: expected installed package $1 missing" >&2; exit 1; }; }
fi

base_packages=(
  firewall4 kmod-nft-offload ppe-help
  kmod-nss-wifi-drv nss-firmware-ipq807x
  tc-tiny kmod-sched-flower
  luci luci-ssl luci-theme-argon luci-i18n-base-zh-cn
)
for pkg in "${base_packages[@]}"; do
  if [[ "$stage" == config ]]; then
    has "$pkg" || { echo "ERROR: required config package $pkg missing" >&2; exit 1; }
  else
    req "$pkg"
  fi
done

if [[ "$stage" == config ]]; then
  for opt in CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6=y CONFIG_TARGET_MULTI_PROFILE=y; do
    if grep -Fqx "$opt" "$file"; then echo "ERROR: forbidden: $opt" >&2; exit 1; fi
  done
fi
for pkg in sing-box xray-core luci-app-ssr-plus kmod-qca-nss-drv-64 \
           qca-nss-ecm kmod-shortcut-fe luci-app-turboacc; do
  if has "$pkg"; then echo "ERROR: prohibited package $pkg in $variant" >&2; exit 1; fi
done

# The interactive terminal is restricted to Plus, but not a proxy package.
# Plus-only interactive utilities; no extra image-updater is bundled.
terminal_packages=(luci-app-ttyd ttyd luci-app-filemanager luci-app-autoreboot)
if [[ "$variant" == tiny-plus ]]; then
  for pkg in "${terminal_packages[@]}" luci-mod-system; do
    if ! has "$pkg"; then echo "ERROR: Tiny Plus requires $pkg" >&2; exit 1; fi
  done
else
  for pkg in "${terminal_packages[@]}"; do
    if has "$pkg"; then echo "ERROR: Tiny must not install terminal package $pkg" >&2; exit 1; fi
  done
fi

proxy_packages=(luci-app-homeproxy luci-i18n-homeproxy-zh-cn sing-box-tiny kmod-nft-tproxy)
if [[ "$variant" == tiny-plus ]]; then
  for pkg in "${proxy_packages[@]}"; do
    if ! has "$pkg"; then echo "ERROR: Tiny Plus requires $pkg" >&2; exit 1; fi
  done
else
  forbidden=(
    "${proxy_packages[@]}" shadowsocks-rust-sslocal shadowsocks-rust-ssserver
    v2ray-plugin trojan dns2socks dns2tcp
    luci-app-passwall luci-app-passwall2 luci-app-openclash
    hysteria tuic-client microsocks ipt2socks shadowsocksr-libev-ssr-local
  )
  for pkg in "${forbidden[@]}"; do
    if has "$pkg"; then echo "ERROR: proxy package $pkg found in pure Tiny" >&2; exit 1; fi
  done
fi
echo "PASS: $stage audit: $variant, stock AX6, PPE/NSS, LuCI/Argon + zh-CN; proxy policy enforced."
