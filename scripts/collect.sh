#!/usr/bin/env bash
# Run in ImmortalWrt source tree after make; first argument is output folder.
set -Eeuo pipefail
out="${1:?Usage: scripts/collect.sh OUTDIR}"
mkdir -p "$out"
out="$(realpath "$out")"
folder='bin/targets/qualcommax/ipq807x'
[[ -d "$folder" ]] || { echo "ERROR: target output directory not found: $folder" >&2; exit 1; }
shopt -s nullglob
firmwares=("$folder"/*redmi_ax6-stock*squashfs-sysupgrade.bin)
if (( ${#firmwares[@]} != 1 )); then
  printf 'ERROR: expected exactly one stock-layout sysupgrade image, found %d\n' "${#firmwares[@]}" >&2
  exit 1
fi
images=("$folder"/*redmi_ax6-stock*squashfs-*.bin "$folder"/*redmi_ax6-stock*squashfs-*.ubi)
for f in "${images[@]}"; do cp -v "$f" "$out/"; done
for f in "$folder"/*.manifest "$folder"/*.buildinfo "$folder"/profiles.json; do
  [[ -f "$f" ]] && cp -v "$f" "$out/"
done
cp .config "$out/build.config"
manifest_files=("$out"/*.manifest)
if (( ${#manifest_files[@]} == 0 )); then
  echo 'ERROR: package manifest missing; cannot verify core selection.' >&2; exit 1
fi
for f in "${manifest_files[@]}"; do
  awk '{print $1}' "$f" | grep -Fxq 'sing-box-tiny' || {
    echo "ERROR: sing-box-tiny absent in $f" >&2; exit 1;
  }
  if awk '{print $1}' "$f" | grep -Fxq 'sing-box'; then
    echo 'ERROR: full sing-box found in manifest; refusing artifact.' >&2; exit 1
  fi
  awk '{print $1}' "$f" | grep -Fxq 'luci-app-homeproxy' || {
    echo 'ERROR: HomeProxy missing in manifest.' >&2; exit 1;
  }
done
file="${firmwares[0]}"
bytes="$(stat -c '%s' "$file")"
size_mib="$(awk -v b="$bytes" 'BEGIN {printf "%.2f", b/1048576}')"
warn_above_mib=30
{
  echo '# AX6 OpenWrt Tiny — build report'
  echo
  echo "- Build UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "- ImmortalWrt branch: $(git branch --show-current)"
  echo "- ImmortalWrt source commit: \`$(git rev-parse HEAD)\`"
  for feed in feeds/luci feeds/packages; do
    if [[ -e "$feed/.git" ]]; then
      echo "- $feed commit: \`$(git -C "$feed" rev-parse HEAD)\`"
    fi
  done
  echo "- Device: Redmi AX6 (stock partition layout only)"
  echo "- Firmware sysupgrade archive size: **$size_mib MiB** ($bytes bytes)"
  if (( bytes > warn_above_mib*1048576 )); then
    echo "- Size target: **ABOVE** experimental $warn_above_mib MiB goal (not necessarily unsafe/safe)."
  else
    echo "- Size target: within experimental $warn_above_mib MiB goal (not a flashing guarantee)."
  fi
  echo '- Hardware validation: **NOT PERFORMED by GitHub Actions**.'
  echo '- Never choose image solely by archive size. Confirm physical flash layout before flashing.'
} > "$out/BUILD-REPORT.md"
(cd "$out" && artifacts=(./*.bin ./*.ubi); (( ${#artifacts[@]} > 0 )) || exit 1; sha256sum "${artifacts[@]}" > SHA256SUMS)
cat "$out/BUILD-REPORT.md"
