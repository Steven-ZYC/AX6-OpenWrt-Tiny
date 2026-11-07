#!/usr/bin/env bash
# Fast no-network checks for repository scripts and workflow helpers.
set -Eeuo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash -n "$repo"/scripts/*.sh "$repo/tests/smoke.sh"
python3 -m py_compile "$repo/scripts/check-stock-image.py"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/scripts" "$work/feeds/luci/applications/luci-app-homeproxy"
# Mock an upstream revision where OpenWrt PR #26444 has already been merged.
# Real builds must apply the patch (or detect it is already present).
printf '# Re-emitted deps carry the pre-rank\n' > "$work/scripts/package-metadata.pl"
printf '#!/bin/sh\nexit 0\n' > "$work/scripts/feeds"
chmod +x "$work/scripts/feeds"
printf 'LUCI_DEPENDS:= \\\n  +sing-box \\\n  +firewall4\n' > "$work/feeds/luci/applications/luci-app-homeproxy/Makefile"
(cd "$work" && bash "$repo/scripts/prepare.sh")
grep -q '^  +sing-box-tiny' "$work/feeds/luci/applications/luci-app-homeproxy/Makefile"
cp "$repo/configs/redmi-ax6-stock.config" "$work/.config"
(cd "$work" && bash "$repo/scripts/check-config.sh")
# Regression test: expanded layout must fail.
printf 'CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6=y\n' >> "$work/.config"
if (cd "$work" && bash "$repo/scripts/check-config.sh" >/dev/null 2>&1); then
  echo 'ERROR: expanded layout incorrectly accepted' >&2; exit 1
fi
# Regression test: multi-device build must be rejected.
sed -i '/^CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6=y$/d' "$work/.config"
printf 'CONFIG_TARGET_MULTI_PROFILE=y\n' >> "$work/.config"
if (cd "$work" && bash "$repo/scripts/check-config.sh" >/dev/null 2>&1); then
  echo 'ERROR: multi-device layout incorrectly accepted' >&2; exit 1
fi
# Regression test: the single-profile selector is required, not TARGET_DEVICE.
sed -i '/^CONFIG_TARGET_MULTI_PROFILE=y$/d' "$work/.config"
sed -i '/^CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6-stock=y$/d' "$work/.config"
if (cd "$work" && bash "$repo/scripts/check-config.sh" >/dev/null 2>&1); then
  echo 'ERROR: missing stock target selector incorrectly accepted' >&2; exit 1
fi
# Construct a minimal synthetic AX6 factory/sysupgrade fixture to test the hard gate.
python3 - "$repo" "$work" <<'PY'
import io
import pathlib
import struct
import subprocess
import sys
import tarfile

repo, work = map(pathlib.Path, sys.argv[1:])
ubi = work / 'redmi_ax6-stock-squashfs-factory.ubi'
sysup = work / 'redmi_ax6-stock-squashfs-sysupgrade.bin'
peb = 128 * 1024
with ubi.open('wb') as stream:
    for vid in (0, 1):
        block = bytearray(peb)
        block[:4] = b'UBI#'
        struct.pack_into('>I', block, 16, 2048)
        block[2048:2052] = b'UBI!'
        struct.pack_into('>I', block, 2056, vid)
        stream.write(block)
with tarfile.open(sysup, 'w') as archive:
    for name in ('CONTROL', 'kernel', 'root'):
        data = b'1'
        entry = tarfile.TarInfo('sysupgrade-redmi_ax6-stock/' + name)
        entry.size = len(data)
        archive.addfile(entry, io.BytesIO(data))
checker = [sys.executable, str(repo / 'scripts/check-stock-image.py'), str(sysup), str(ubi)]
assert subprocess.run(checker, capture_output=True).returncode == 0
with ubi.open('r+b') as stream:
    stream.truncate(29 * 1024 * 1024)
assert subprocess.run(checker, capture_output=True).returncode != 0
PY
# Source-level datapath audit: legacy baseline is reported, never mislabelled as PPE.
mkdir -p "$work/target/linux/qualcommax/ipq807x" "$work/target/linux/qualcommax/image"
printf 'KERNEL_PATCHVER:=6.12\nDEFAULT_PACKAGES += kmod-qca-nss-dp\n' > "$work/target/linux/qualcommax/Makefile"
printf 'CONFIG_NET_DSA=y\n' > "$work/target/linux/qualcommax/ipq807x/config-default"
printf 'define Device/redmi_ax6-stock\nendef\n' > "$work/target/linux/qualcommax/image/ipq807x.mk"
cp "$repo/configs/redmi-ax6-stock.config" "$work/.config"
(cd "$work" && bash "$repo/scripts/audit-datapath.sh" .config datapath-audit.md)
grep -Fq 'Legacy qca-nss-dp' "$work/datapath-audit.md"
grep -Fq 'NOT AVAILABLE via the new upstream' "$work/datapath-audit.md"
# PPE+NSS source without an explicit stock definition must be rejected.
printf 'define Device/redmi_ax6\nendef\n' > "$work/target/linux/qualcommax/image/ipq807x.mk"
if (cd "$work" && bash "$repo/scripts/audit-datapath.sh" .config datapath-audit.md >/dev/null 2>&1); then
  echo 'ERROR: missing stock definition incorrectly accepted by datapath audit' >&2; exit 1
fi
# Experimental PPE-only profile port must match reviewed upstream structure.
mkdir -p "$work/ppe/target/linux/qualcommax/ipq807x" "$work/ppe/target/linux/qualcommax/image"
printf 'KERNEL_PATCHVER:=6.18\n' > "$work/ppe/target/linux/qualcommax/Makefile"
printf 'CONFIG_QCOM_EDMA=y\nCONFIG_QCOM_80211AX_PPE=y\n' > "$work/ppe/target/linux/qualcommax/ipq807x/config-default"
cat > "$work/ppe/target/linux/qualcommax/image/ipq807x.mk" <<'PPE_DEVICE'
define Device/xiaomi_ax3600
  $(call Device/FitImage)
  $(call Device/UbiFit)
  KERNEL_SIZE := 36608k
endef
define Device/redmi_ax6
	$(call Device/xiaomi_ax3600)
	DEVICE_VENDOR := Redmi
	DEVICE_MODEL := AX6
	DEVICE_PACKAGES := ipq-wifi-redmi_ax6
endef
TARGET_DEVICES += redmi_ax6
PPE_DEVICE
(cd "$work/ppe" && bash "$repo/scripts/prepare-ppe-experiment.sh")
grep -Fqx 'TARGET_DEVICES += redmi_ax6-stock' "$work/ppe/target/linux/qualcommax/image/ipq807x.mk"
cp "$repo/configs/redmi-ax6-ppe-only-stock.config" "$work/ppe/.config"
(cd "$work/ppe" && bash "$repo/scripts/check-ppe-config.sh" .config)
# Upstream image profile change must be a hard error.
if (cd "$work/ppe" && bash "$repo/scripts/prepare-ppe-experiment.sh" >/dev/null 2>&1); then
  echo 'ERROR: repeated PPE stock port unexpectedly accepted' >&2; exit 1
fi
printf 'SMOKE TESTS PASSED\n'
