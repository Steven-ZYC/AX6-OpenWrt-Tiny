#!/usr/bin/env bash
# Verify packages after compilation; never claim success merely from .config.
set -Eeuo pipefail
target="${1:-bin/targets/qualcommax/ipq807x}"
report="${2:-../ppe-tiny-report}"
mkdir -p "$report"
shopt -s nullglob
manifests=("$target"/*redmi_ax6-stock*.manifest)
(( ${#manifests[@]} == 1 )) || { echo 'ERROR: stock AX6 manifest missing/ambiguous' >&2; exit 1; }
file="${manifests[0]}"
for name in luci luci-theme-argon luci-app-homeproxy sing-box-tiny kmod-nft-tproxy kmod-nft-offload kmod-nss-wifi-drv nss-firmware-ipq807x ppe-help; do
  awk '{print $1}' "$file" | grep -Fqx "$name" || {
    echo "ERROR: expected package missing from firmware: $name" >&2; exit 1;
  }
done
for name in sing-box xray-core kmod-qca-nss-drv-64 qca-nss-ecm kmod-shortcut-fe luci-app-ssr-plus; do
  if awk '{print $1}' "$file" | grep -Fqx "$name"; then
    echo "ERROR: unwanted/conflicting legacy package present: $name" >&2; exit 1;
  fi
done
cp "$file" "$report/"
printf '# Combined PPE + Tiny package audit\n\n' > "$report/PACKAGE-AUDIT.md"
printf 'Required user-interface, proxy and Qualcomm Wi-Fi package checks: PASS.\n\n' >> "$report/PACKAGE-AUDIT.md"
printf 'Real router hardware, flash/boot and TProxy interaction tests: NOT DONE.\n' >> "$report/PACKAGE-AUDIT.md"
echo 'OK: combined manifest checks PASSED'
