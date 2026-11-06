#!/usr/bin/env bash
# Fast no-network checks for repository scripts and workflow helpers.
set -Eeuo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash -n "$repo"/scripts/*.sh "$repo/tests/smoke.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/scripts" "$work/feeds/luci/applications/luci-app-homeproxy"
printf '#!/bin/sh\nexit 0\n' > "$work/scripts/feeds"
chmod +x "$work/scripts/feeds"
printf 'LUCI_DEPENDS:= \\\n  +sing-box \\\n  +firewall4\n' > "$work/feeds/luci/applications/luci-app-homeproxy/Makefile"
(cd "$work" && bash "$repo/scripts/prepare.sh")
grep -q '^  +sing-box-tiny' "$work/feeds/luci/applications/luci-app-homeproxy/Makefile"
cp "$repo/configs/redmi-ax6-stock.config" "$work/.config"
(cd "$work" && bash "$repo/scripts/check-config.sh")
# Regression test: expanded layout must fail.
printf 'CONFIG_TARGET_DEVICE_qualcommax_ipq807x_DEVICE_redmi_ax6=y\n' >> "$work/.config"
if (cd "$work" && bash "$repo/scripts/check-config.sh" >/dev/null 2>&1); then
  echo 'ERROR: expanded layout incorrectly accepted' >&2; exit 1
fi
printf 'SMOKE TESTS PASSED\n'
