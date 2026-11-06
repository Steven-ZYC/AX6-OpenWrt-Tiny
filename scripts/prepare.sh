#!/usr/bin/env bash
# Run in ImmortalWrt source root, after git clone, before applying config.
set -Eeuo pipefail

[[ -x ./scripts/feeds ]] || { echo 'ERROR: run in the ImmortalWrt source root.' >&2; exit 1; }

printf '::group::Update feeds\n'
./scripts/feeds update -a
printf '::endgroup::\n'

# Upstream HomeProxy declares +sing-box. The tiny package provides the
# virtual sing-box name, but relying on variant selection is brittle.
# Fail closed if upstream changed the dependency unexpectedly.
hp='feeds/luci/applications/luci-app-homeproxy/Makefile'
[[ -f "$hp" ]] || { echo "ERROR: Missing $hp; upstream layout changed." >&2; exit 1; }
if grep -Eq '^[[:space:]]*\+sing-box-tiny([[:space:]\\]|$)' "$hp"; then
  echo 'HomeProxy already requires sing-box-tiny.'
elif grep -Eq '^[[:space:]]*\+sing-box([[:space:]\\]|$)' "$hp"; then
  sed -i -E 's/^([[:space:]]*)\+sing-box([[:space:]\\]|$)/\1+sing-box-tiny\2/' "$hp"
  echo 'Patched HomeProxy: +sing-box => +sing-box-tiny.'
else
  echo 'ERROR: HomeProxy dependency pattern changed; review upstream before building.' >&2
  exit 1
fi
grep -Eq '^[[:space:]]*\+sing-box-tiny([[:space:]\\]|$)' "$hp" || {
  echo 'ERROR: HomeProxy tiny dependency not found after patch.' >&2; exit 1;
}

printf '::group::Install feeds\n'
./scripts/feeds install -a
printf '::endgroup::\n'
