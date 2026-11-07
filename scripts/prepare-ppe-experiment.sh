#!/usr/bin/env bash
# Prepare an experimental PPE-only AX6 stock source tree.
# Run from the root of JuliusBairaktaris/openwrt-ppe-nss (ppe-nss branch).
# The device definition is based on ImmortalWrt openwrt-25.12 stock variant.
# NEVER automatically release or flash any resulting image.
set -Eeuo pipefail

file=target/linux/qualcommax/image/ipq807x.mk
subtarget=target/linux/qualcommax/ipq807x/config-default
target=target/linux/qualcommax/Makefile

for f in "$file" "$subtarget" "$target"; do
  [[ -f "$f" ]] || { echo "ERROR: upstream missing $f" >&2; exit 1; }
done
grep -Fqx 'KERNEL_PATCHVER:=6.18' "$target" || {
  echo 'ERROR: unexpected PPE source kernel version; re-audit upstream before upgrading.' >&2; exit 1;
}
for flag in CONFIG_QCOM_EDMA=y CONFIG_QCOM_80211AX_PPE=y; do
  grep -Fqx "$flag" "$subtarget" || {
    echo "ERROR: PPE datapath flag $flag missing upstream." >&2; exit 1;
  }
done

python3 - "$file" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
source = path.read_text()
expected = (
    "define Device/redmi_ax6\n"
    "\t$(call Device/xiaomi_ax3600)\n"
    "\tDEVICE_VENDOR := Redmi\n"
    "\tDEVICE_MODEL := AX6\n"
    "\tDEVICE_PACKAGES := ipq-wifi-redmi_ax6\n"
    "endef\n"
    "TARGET_DEVICES += redmi_ax6\n"
)
# Exact source guard: upstream changes require review, not auto-guessing.
if source.count(expected) != 1:
    raise SystemExit("ERROR: upstream Redmi AX6 definition changed; manual review required.")
if "define Device/redmi_ax6-stock" in source:
    raise SystemExit("ERROR: stock profile already exists upstream; review it instead of duplicating.")
if source.count("define Device/xiaomi_ax3600\n") != 1:
    raise SystemExit("ERROR: upstream AX3600 image inheritance changed.")
parent = re.search(r"^define Device/xiaomi_ax3600\n(.*?)^endef$", source, re.M | re.S)
if not parent or "$(call Device/UbiFit)" not in parent.group(1) or "KERNEL_SIZE := 36608k" not in parent.group(1):
    raise SystemExit("ERROR: AX3600 parent image recipe changed; must verify stock safety.")

# Matches the stock-layout variant override in ImmortalWrt 25.12.
stock = (
    "\ndefine Device/redmi_ax6-stock\n"
    "\t$(call Device/redmi_ax6)\n"
    "\tDEVICE_VARIANT := (stock layout)\n"
    "\tDEVICE_ALT0_VENDOR := Redmi\n"
    "\tDEVICE_ALT0_MODEL := AX6\n"
    "\tDEVICE_ALT0_VARIANT := (custom U-Boot layout)\n"
    "\tKERNEL_SIZE :=\n"
    "\tARTIFACTS :=\n"
    "endef\n"
    "TARGET_DEVICES += redmi_ax6-stock\n"
)
path.write_text(source.replace(expected, expected + stock))
if path.read_text().count("TARGET_DEVICES += redmi_ax6-stock") != 1:
    raise SystemExit("ERROR: stock device definition was not added exactly once.")
print("OK: added experimental AX6 stock image definition based on ImmortalWrt 25.12")
print("WARNING: source-profile match is NOT proof of bootloader, DTS or flash safety")
PY
