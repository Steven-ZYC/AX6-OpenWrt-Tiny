#!/usr/bin/env bash
# Offline regression tests for the dual-variant proxy policy and package gates.
set -Eeuo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT

bash "$repo/scripts/verify-ax6-variant.sh" config tiny \
  "$repo/configs/redmi-ax6-ppe-tiny-stock.config"
bash "$repo/scripts/verify-ax6-variant.sh" config tiny-plus \
  "$repo/configs/redmi-ax6-ppe-tiny-plus-stock.config"

base=(
  firewall4 kmod-nft-offload ppe-help kmod-nss-wifi-drv
  nss-firmware-ipq807x tc-tiny kmod-sched-flower
  luci luci-ssl luci-theme-argon luci-i18n-base-zh-cn
)
for pkg in "${base[@]}"; do
  echo "$pkg - 1.0" >> "$temp/tiny.manifest"
done
cp "$temp/tiny.manifest" "$temp/plus.manifest"
for pkg in luci-app-homeproxy luci-i18n-homeproxy-zh-cn sing-box-tiny kmod-nft-tproxy; do
  echo "$pkg - 1.0" >> "$temp/plus.manifest"
done
bash "$repo/scripts/verify-ax6-variant.sh" manifest tiny "$temp/tiny.manifest"
bash "$repo/scripts/verify-ax6-variant.sh" manifest tiny-plus "$temp/plus.manifest"

# Tiny must not contain any of the known proxy packages.
if bash "$repo/scripts/verify-ax6-variant.sh" manifest tiny "$temp/plus.manifest" >/dev/null 2>&1; then
  echo 'ERROR: Tiny accidentally accepted a proxy-containing manifest' >&2; exit 1
fi
# Plus must include its full stack, including translation.
if bash "$repo/scripts/verify-ax6-variant.sh" manifest tiny-plus "$temp/tiny.manifest" >/dev/null 2>&1; then
  echo 'ERROR: Tiny Plus accidentally accepted a proxy-free manifest' >&2; exit 1
fi
sed '/^luci-i18n-base-zh-cn /d' "$temp/tiny.manifest" > "$temp/missing-zh.manifest"
if bash "$repo/scripts/verify-ax6-variant.sh" manifest tiny "$temp/missing-zh.manifest" >/dev/null 2>&1; then
  echo 'ERROR: accepted firmware without Chinese LuCI package' >&2; exit 1
fi
echo 'Variant guard regression tests PASSED'
