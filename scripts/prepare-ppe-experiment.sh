#!/usr/bin/env bash
# EXPERIMENTAL: port the Redmi AX6 *stock-layout* profile to the PPE-only 6.18 tree.
# This is an image-generation feasibility build. NOT approved for flashing.
# References: ImmortalWrt openwrt-25.12 AX6 stock DTS, envtools and platform.sh.
set -Eeuo pipefail

img=target/linux/qualcommax/image/ipq807x.mk
subtarget=target/linux/qualcommax/ipq807x/config-default
target=target/linux/qualcommax/Makefile
dtsdir=target/linux/qualcommax/dts
upgrade=target/linux/qualcommax/ipq807x/base-files/lib/upgrade/platform.sh
envtools=package/boot/uboot-tools/uboot-envtools/files/qualcommax_ipq807x
network=target/linux/qualcommax/ipq807x/base-files/etc/board.d/02_network
leds=target/linux/qualcommax/ipq807x/base-files/etc/board.d/01_leds
caldata=target/linux/qualcommax/ipq807x/base-files/etc/hotplug.d/firmware/11-ath11k-caldata
bootcount=target/linux/qualcommax/ipq807x/base-files/etc/init.d/bootcount

for f in "$img" "$subtarget" "$target" "$dtsdir/ipq8071-ax6.dts" \
  "$dtsdir/ipq8071-ax3600.dtsi" "$upgrade" "$envtools" "$network" "$leds" "$caldata" "$bootcount" \
  target/linux/qualcommax/config-6.18; do
  [[ -f "$f" ]] || { echo "ERROR: missing PPE source input: $f" >&2; exit 1; }
done
grep -Fqx 'KERNEL_PATCHVER:=6.18' "$target" || {
  echo 'ERROR: unknown PPE source kernel; review required.' >&2; exit 1;
}
for flag in CONFIG_QCOM_EDMA=y CONFIG_QCOM_80211AX_PPE=y; do
  grep -Fqx "$flag" "$subtarget" || {
    echo "ERROR: missing $flag from upstream PPE source." >&2; exit 1;
  }
done
grep -Fqx 'CONFIG_MTD_QCOMSMEM_PARTS=y' target/linux/qualcommax/config-6.18 || {
  echo 'ERROR: stock layout requires Qualcomm SMEM partition parser.' >&2; exit 1;
}

python3 - "$img" "$dtsdir" "$upgrade" "$envtools" "$network" "$leds" "$caldata" "$bootcount" <<'PY'
from pathlib import Path
import re
import sys

img, dtsdir, upgrade, envtools, network, leds, caldata, bootcount = map(Path, sys.argv[1:])
images = img.read_text()
expected = (
    "define Device/redmi_ax6\n"
    "\t$(call Device/xiaomi_ax3600)\n"
    "\tDEVICE_VENDOR := Redmi\n"
    "\tDEVICE_MODEL := AX6\n"
    "\tDEVICE_PACKAGES := ipq-wifi-redmi_ax6\n"
    "endef\n"
    "TARGET_DEVICES += redmi_ax6\n"
)
if images.count(expected) != 1 or "define Device/redmi_ax6-stock" in images:
    raise SystemExit("ERROR: upstream Redmi AX6 profile changed, or stock variant already exists.")
parent = re.search(r"^define Device/xiaomi_ax3600\n(.*?)^endef$", images, re.M | re.S)
if not parent or "$(call Device/UbiFit)" not in parent.group(1) or "KERNEL_SIZE := 36608k" not in parent.group(1):
    raise SystemExit("ERROR: upstream UBI parent recipe changed; review required.")
dts = (dtsdir / "ipq8071-ax6.dts").read_text()
dtsi = (dtsdir / "ipq8071-ax3600.dtsi").read_text()
if (dtsdir / "ipq8071-ax6-stock.dts").exists():
    raise SystemExit("ERROR: upstream stock DTS already exists; review instead of overwriting.")
if 'compatible = "redmi,ax6", "qcom,ipq8074";' not in dts or "reg = <0x2dc0000 0x5220000>;" not in dts:
    raise SystemExit("ERROR: AX6 base DTS layout changed, cannot safely derive stock variant.")
if 'compatible = "fixed-partitions";' not in dtsi or 'label = "ubi_kernel";' not in dtsi:
    raise SystemExit("ERROR: inherited AX3600 partition layout changed.")
for label in ("swport2:", "swport3:", "swport4:", "swport5:"):
    if label not in dtsi:
        raise SystemExit(f"ERROR: DSA port label {label} missing; cannot port stock DTS.")

# Bootloader stock layout is provided by SMEM: NEVER reuse the expanded
# fixed-partitions rootfs mapping from ipq8071-ax6.dts.
stock_dts = """// SPDX-License-Identifier: GPL-2.0-or-later OR MIT
// EXPERIMENTAL AX6 stock-layout adaptation from ImmortalWrt openwrt-25.12.
// Not flash-safe until dual-slot UBI layout is validated on the actual device.
#include "ipq8071-ax6.dts"

/ {
    model = "Redmi AX6 (stock layout, PPE experiment)";
    compatible = "redmi,ax6-stock", "qcom,ipq8074";

    aliases {
        ethernet1 = &swport2;
        ethernet2 = &swport3;
        ethernet3 = &swport4;
        ethernet4 = &swport5;
    };

    chosen {
        bootargs-append = " root=/dev/ubiblock0_1";
    };
};

&qpic_nand {
    /delete-node/ partitions;

    nand@0 {
        /delete-node/ partitions;

        partitions {
            compatible = "qcom,smem-part";
        };
    };
};

// The deleted expanded-layout ART NVMEM node cannot be used by DSA ports.
// U-Boot MAC patching for swport aliases still needs real-hardware testing.
&swport2 {
    /delete-property/ nvmem-cells;
    /delete-property/ nvmem-cell-names;
};
&swport3 {
    /delete-property/ nvmem-cells;
    /delete-property/ nvmem-cell-names;
};
&swport4 {
    /delete-property/ nvmem-cells;
    /delete-property/ nvmem-cell-names;
};
&swport5 {
    /delete-property/ nvmem-cells;
    /delete-property/ nvmem-cell-names;
};
"""

stock_profile = (
    "\ndefine Device/redmi_ax6-stock\n"
    "\t$(call Device/redmi_ax6)\n"
    "\tDEVICE_VARIANT := (stock layout)\n"
    "\tDEVICE_ALT0_VENDOR := Redmi\n"
    "\tDEVICE_ALT0_MODEL := AX6\n"
    "\tDEVICE_ALT0_VARIANT := (custom U-Boot layout)\n"
    "\tDEVICE_DTS := ipq8071-ax6-stock\n"
    "\tKERNEL_SIZE :=\n"
    "\tARTIFACTS :=\n"
    "endef\n"
    "TARGET_DEVICES += redmi_ax6-stock\n"
)

def replace_once(path: Path, old: str, new: str) -> None:
    s = path.read_text()
    if s.count(old) != 1 or new in s:
        raise SystemExit(f"ERROR: unreviewed source change or duplicate in {path}: {old!r}")
    path.write_text(s.replace(old, new))

# Validate all source anchors BEFORE writing anything to the build tree.
replacements = [
    (envtools, 'redmi,ax6|\\\n', 'redmi,ax6|\\\nredmi,ax6-stock|\\\n'),
    (network, '\tredmi,ax6|\\\n', '\tredmi,ax6|\\\n\tredmi,ax6-stock|\\\n'),
    (leds, 'redmi,ax6)\n', 'redmi,ax6|\\\nredmi,ax6-stock)\n'),
    (caldata, '\tredmi,ax6|\\\n', '\tredmi,ax6|\\\n\tredmi,ax6-stock|\\\n'),
]
for p, old, new in replacements:
    s = p.read_text()
    if s.count(old) != 1 or new in s:
        raise SystemExit(f"ERROR: source pattern mismatch in {p}")

boot_old = '\t;;\n\tesac\n}\n'
if bootcount.read_text().count(boot_old) != 1:
    raise SystemExit("ERROR: bootcount service changed.")

upgrade_old = '\t*)\n\t\tdefault_do_upgrade "$1"\n\t\t;;\n'
if upgrade.read_text().count(upgrade_old) != 1 or 'redmi,ax6-stock' in upgrade.read_text():
    raise SystemExit("ERROR: upstream upgrade handler changed or stock is already supported.")

# All guards passed: apply changes. Real flashing still requires hardware review.
img.write_text(images.replace(expected, expected + stock_profile))
(dtsdir / "ipq8071-ax6-stock.dts").write_text(stock_dts)
for p, old, new in replacements:
    replace_once(p, old, new)

boot_patch = """\tredmi,ax6-stock)
\t\t# Stock dual-slot boot flags (ImmortalWrt 25.12 reference).
\t\tfw_setenv flag_ota_reboot 0
\t\tfw_setenv flag_boot_success 1
\t;;
"""
replace_once(bootcount, boot_old, boot_patch + boot_old)

# Keep the same stock-style upgrade selection as ImmortalWrt 25.12.
# In addition, FAIL on missing/unexpected boot flag instead of guessing a slot.
upgrade_patch = """\tredmi,ax6-stock)
\t\tpart_num="$(fw_printenv -n flag_boot_rootfs)" || return 1
\t\tcase "$part_num" in
\t\t1)
\t\t\tCI_UBIPART="rootfs_1"
\t\t\ttarget_num=1
\t\t\tfw_setenv flag_try_sys2_failed 0 || return 1
\t\t\t;;
\t\t0)
\t\t\tCI_UBIPART="rootfs"
\t\t\ttarget_num=0
\t\t\tfw_setenv flag_try_sys1_failed 0 || return 1
\t\t\t;;
\t\t*)
\t\t\techo "ERROR: unknown flag_boot_rootfs; refusing stock AX6 upgrade" >&2
\t\t\treturn 1
\t\t\t;;
\t\tesac
\t\tfw_setenv flag_boot_rootfs "$target_num" || return 1
\t\tfw_setenv flag_last_success "$target_num" || return 1
\t\tfw_setenv flag_boot_success 0 || return 1
\t\tnand_do_upgrade "$1"
\t\t;;
"""
replace_once(upgrade, upgrade_old, upgrade_patch + upgrade_old)

# Final explicit proof of the only device that was registered.
assert img.read_text().count("TARGET_DEVICES += redmi_ax6-stock") == 1
assert 'compatible = "qcom,smem-part";' in (dtsdir / "ipq8071-ax6-stock.dts").read_text()
print("OK: guarded experimental AX6 stock DT + DSA aliases, SMEM partitions, boot/upgrade board hooks")
print("WARNING: build success is NOT stock-layout runtime, MAC, Wi-Fi, or flash-safety validation")
PY
