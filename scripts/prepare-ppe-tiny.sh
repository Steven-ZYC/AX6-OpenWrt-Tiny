#!/usr/bin/env bash
# Build-root preparer for combined OpenWrt PPE 6.18 + stock-layout AX6 Tiny.
# Needs repository checkout in parent folder; run inside cloned ppe-nss source.
# Always fail closed if an upstream feed or package layout changes.
set -Eeuo pipefail

[[ -x scripts/feeds ]] || { echo 'ERROR: run inside OpenWrt source root' >&2; exit 1; }
[[ -f ../scripts/prepare-ppe-experiment.sh ]] || { echo 'ERROR: missing stock port script' >&2; exit 1; }
mkdir -p ../ppe-tiny-report
bash ../scripts/prepare-ppe-experiment.sh

# Include the same user-facing defaults in Tiny and Tiny Plus.
# Files land in /etc/uci-defaults/ and apply on a clean initial boot;
# do not edit a running router or touch U-Boot flags here.
test -s ../files/etc/uci-defaults/95-ax6-tiny-firstboot
mkdir -p files/etc/uci-defaults
cp ../files/etc/uci-defaults/95-ax6-tiny-firstboot files/etc/uci-defaults/
test -s files/etc/uci-defaults/95-ax6-tiny-firstboot

cp feeds.conf.default feeds.conf
cat >> feeds.conf <<'FEEDS'
src-git nss https://github.com/JuliusBairaktaris/nss-packages.git;ppe-nss
FEEDS

./scripts/feeds update -a
./scripts/feeds install -a

# Fail early if the currently fetched OpenWrt LuCI feed drops the expected
# file-management web UI or standard Backup / Flash Firmware component.
test -f feeds/luci/applications/luci-app-filemanager/Makefile || {
  echo 'ERROR: OpenWrt LuCI File Manager package missing' >&2; exit 1;
}
test -f feeds/luci/modules/luci-mod-system/Makefile || {
  echo 'ERROR: LuCI core system / Backup / Flash Firmware module missing' >&2; exit 1;
}

# Import only the ImmortalWrt LuCI packages missing from OpenWrt's own
# 6.18 feeds. HomeProxy and Argon are already included; Scheduled Reboot is
# imported separately for Plus-only optional scheduled restarts.
# File Manager and Backup / Flash Firmware are from upstream OpenWrt LuCI.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git clone --depth 1 --single-branch --branch openwrt-25.12 https://github.com/immortalwrt/luci.git "$work/luci"
git -C "$work/luci" rev-parse HEAD > ../ppe-tiny-report/IMMORTALWRT-LUCI-SHA.txt
mkdir -p package/ax6-luci
for entry in applications/luci-app-homeproxy themes/luci-theme-argon applications/luci-app-autoreboot; do
  [[ -f "$work/luci/$entry/Makefile" ]] || { echo "ERROR: missing ImmortalWrt LuCI package: $entry" >&2; exit 1; }
  cp -a "$work/luci/$entry" package/ax6-luci/
done

python3 - <<'PY'
from pathlib import Path

custom = Path('package/ax6-luci')
for name in ('luci-app-homeproxy', 'luci-theme-argon', 'luci-app-autoreboot'):
    p = custom / name / 'Makefile'
    src = p.read_text()
    old = 'include ../../luci.mk'
    if src.count(old) != 1:
        raise SystemExit(f'ERROR: unexpected LuCI makefile include in {p}')
    p.write_text(src.replace(old, 'include $(TOPDIR)/feeds/luci/luci.mk'))

hp = custom / 'luci-app-homeproxy' / 'Makefile'
src = hp.read_text()
if src.count('+sing-box \\') != 1:
    raise SystemExit('ERROR: HomeProxy dependency changed; do not accidentally include full sing-box')
hp.write_text(src.replace('+sing-box \\', '+sing-box-tiny \\'))
if '+sing-box-tiny \\' not in hp.read_text():
    raise SystemExit('ERROR: HomeProxy tiny dependency was not enforced')

# OpenWrt snapshot's sing-box-tiny currently hardcodes with_quic and may also
# include with_gvisor unless SMALL_FLASH is set. Keep exactly the two features
# we need: uTLS (for Reality fingerprints) and Clash API for HomeProxy status.
sb = Path('feeds/packages/net/sing-box/Makefile')
if not sb.is_file():
    raise SystemExit('ERROR: OpenWrt sing-box Makefile missing')
src = sb.read_text()
old = """ifeq ($(BUILD_VARIANT),tiny)
ifeq ($(CONFIG_SMALL_FLASH),)
GO_PKG_TAGS:=with_gvisor
endif
GO_PKG_TAGS:=$(subst $(space),$(comma),$(strip $(GO_PKG_TAGS) with_quic with_utls with_clash_api badlinkname tfogo_checklinkname0))
else"""
new = """ifeq ($(BUILD_VARIANT),tiny)
# AX6 experimental small variant: VLESS Reality / Shadowsocks + HomeProxy only.
GO_PKG_TAGS:=$(subst $(space),$(comma),$(strip with_utls with_clash_api badlinkname tfogo_checklinkname0))
else"""
if src.count(old) != 1:
    raise SystemExit('ERROR: OpenWrt sing-box tiny build tags changed, review before proceeding')
sb.write_text(src.replace(old, new))
PY

printf 'Source and feed provenance:\n'
git rev-parse HEAD
for feed in feeds/luci feeds/packages feeds/nss; do
  git -C "$feed" rev-parse HEAD
done
printf 'Experimental PPE + Tiny source preparation complete. NOT flash verified.\n'
