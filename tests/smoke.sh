#!/usr/bin/env bash
# Fast no-network checks for repository scripts and workflow helpers.
set -Eeuo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash -n "$repo"/scripts/*.sh "$repo/tests/smoke.sh"
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
printf 'SMOKE TESTS PASSED\n'
