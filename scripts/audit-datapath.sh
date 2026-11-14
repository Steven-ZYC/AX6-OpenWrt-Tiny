#!/usr/bin/env bash
# Read-only, source-level datapath audit. Run from the OpenWrt source root.
# This is NOT a runtime proof of hardware offload.
set -Eeuo pipefail
if (( $# != 2 )); then
  echo 'Usage: audit-datapath.sh PATH_TO_GENERATED_CONFIG OUTPUT_MD' >&2
  exit 2
fi
cfg="$1"
out="$2"
base='target/linux/qualcommax'
target_mk="$base/Makefile"
subtarget_cfg="$base/ipq807x/config-default"
image_mk="$base/image/ipq807x.mk"
for file in "$cfg" "$target_mk" "$subtarget_cfg" "$image_mk"; do
  [[ -f "$file" ]] || { echo "ERROR: missing datapath audit input: $file" >&2; exit 1; }
done

# Refuse to generate a misleading report for an expanded-layout image.
grep -Fqx 'CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6-stock=y' "$cfg" || {
  echo 'ERROR: the selected device is not redmi_ax6-stock.' >&2; exit 1;
}
if ! grep -Eq '^define Device/redmi_ax6-stock[[:space:]]*$' "$image_mk"; then
  echo 'ERROR: upstream tree lacks an explicit AX6 stock-layout image profile.' >&2
  exit 1
fi
if grep -Fqx 'CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6=y' "$cfg"; then
  echo 'ERROR: expanded AX6 profile also selected.' >&2; exit 1
fi

kernel="$(sed -nE 's/^KERNEL_PATCHVER[[:space:]]*:=[[:space:]]*([^[:space:]]+).*/\1/p' "$target_mk" | head -n 1)"
[[ -n "$kernel" ]] || kernel='unknown'

if grep -Fqx 'CONFIG_QCOM_EDMA=y' "$subtarget_cfg" &&
   grep -Fqx 'CONFIG_QCOM_80211AX_PPE=y' "$subtarget_cfg"; then
  stack='EDMA + PPE source configuration detected'
  ppe='CANDIDATE: verify built kernel, fw4 hardware flowtable, and actual traffic on router'
elif grep -Fq 'kmod-qca-nss-dp' "$target_mk"; then
  stack='Legacy qca-nss-dp / qca-ssdk datapath'
  ppe='NOT AVAILABLE via the new upstream qca_edma/qca_ppe flowtable path in this source'
else
  stack='UNKNOWN: source requires manual review'
  ppe='UNVERIFIED: do not enable hardware flow offload solely from this audit'
fi

nss_wifi='not explicitly selected'
if grep -Fqx 'CONFIG_PACKAGE_kmod-nss-wifi-drv=y' "$cfg" ||
   grep -Fqx 'CONFIG_ATH11K_NSS_WIFI=y' "$cfg"; then
  nss_wifi='requested in build configuration; firmware, drivers, and runtime still require verification'
fi

mkdir -p "$(dirname "$out")"
cat > "$out" <<EOF
# Redmi AX6 stock - Qualcomm datapath source audit

- Target: qualcommax/ipq807x, redmi_ax6-stock (verified in config and source image definition)
- Kernel series in source: $kernel
- Ethernet datapath family: $stack
- PPE hardware flow offload: $ppe
- NSS Wi-Fi offload: $nss_wifi
- Runtime accelerated flows and throughput: NOT TESTED

This is a read-only source audit, NOT proof of PPE/NSS hardware acceleration.
It does not enable UCI flow_offloading_hw: doing so without driver support, or
without checking transparent proxy / TProxy rules, can silently misroute traffic.
The stock flash size gate and full hardware testing remain mandatory before flashing.
EOF
cat "$out"
