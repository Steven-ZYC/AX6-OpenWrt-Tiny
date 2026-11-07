#!/usr/bin/env bash
# Stage verified stock-layout variant as GitHub Action artifact.
set -Eeuo pipefail
(( $# == 4 )) || { echo 'Usage: stage-ax6-variant.sh tiny|tiny-plus TARGET_DIR OUTPUT_DIR REPORT_DIR' >&2; exit 2; }
variant="$1"; target="$2"; out="$3"; report="$4"
[[ "$variant" == tiny || "$variant" == tiny-plus ]] || exit 2
shopt -s nullglob
factory=("$target"/*redmi_ax6-stock*squashfs-factory.ubi)
upgrade=("$target"/*redmi_ax6-stock*squashfs-sysupgrade.bin)
manifest=("$target"/*redmi_ax6-stock*.manifest)
(( ${#factory[@]} == 1 && ${#upgrade[@]} == 1 && ${#manifest[@]} == 1 )) || {
  echo 'ERROR: expected exactly one factory UBI, sysupgrade BIN and stock manifest' >&2; exit 1;
}
repo="$(cd "$(dirname "$0")/.." && pwd)"
bash "$repo/scripts/verify-ax6-variant.sh" manifest "$variant" "${manifest[0]}"
mkdir -p "$out" "$report"
python3 "$repo/scripts/check-stock-image.py" "${upgrade[0]}" "${factory[0]}" > "$report/IMAGE-AUDIT.md"
cp "${factory[0]}" "$out/AX6-$variant-factory.ubi"
cp "${upgrade[0]}" "$out/AX6-$variant-sysupgrade.bin"
cp "${manifest[0]}" "$out/AX6-$variant.manifest"
cp "$report/IMAGE-AUDIT.md" "$out/AX6-$variant-IMAGE-AUDIT.md"
echo 'EXPERIMENTAL - No hardware flash, boot, Wi-Fi, NSS or TProxy tests.' > "$out/UNVERIFIED-$variant.txt"
(cd "$out" && sha256sum *.ubi *.bin > "SHA256SUMS-$variant")
cat "$report/IMAGE-AUDIT.md"
echo "PASS: $variant images and manifest staged."
