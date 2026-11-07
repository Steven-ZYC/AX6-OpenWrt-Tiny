# AX6 Tiny and Tiny Plus — dual-variant release contract

**Hardware:** Redmi AX6 (IPQ8071A), original 128 MiB NAND / **stock partition layout only**.
Do not confuse with AX6S, AX6000, expanded NAND layouts or alternate U-Boot partition maps.

## The two images in every release

| Feature | Tiny | Tiny Plus |
|---|---|---|
| OpenWrt PPE/EDMA (Linux 6.18 upstream) | Yes | Yes |
| NSS Wi-Fi driver + matching NSS firmware | Yes | Yes |
| Stock NAND DTS, 28 MiB factory size gate | Yes | Yes |
| Firewall4, nftables + PPE flow-offload kernel support | Yes | Yes |
| Qualcomm tc/PPE flow and queue modules | Yes | Yes |
| LuCI, HTTPS, Argon, Simplified Chinese | Yes | Yes |
| HomeProxy, HomeProxy Chinese translation | **No** | **Yes** |
| sing-box-tiny (uTLS + Clash API, no QUIC/gVisor) | **No** | **Yes** |
| nftables TProxy kernel module | **No** | **Yes** |
| VLESS Reality / Shadowsocks | **No proxy client** | **Target features (runtime verification needed)** |

Tiny and Tiny Plus share the SAME source revision and foundational network
packages. Only the Plus variant may install proxy-related packages. The
build checks the **actual installed manifest**, not just the requested config.

## GitHub Release contents

Every version tag (for instance `v0.1.0-rc1`) must contain four separate raw
firmware files, two `.manifest` files and `SHA256SUMS`.

- `AX6-tiny-v0.1.0-rc1-factory.ubi`
- `AX6-tiny-v0.1.0-rc1-sysupgrade.bin`
- `AX6-tiny-plus-v0.1.0-rc1-factory.ubi`
- `AX6-tiny-plus-v0.1.0-rc1-sysupgrade.bin`

**Factory and Sysupgrade are different formats and upgrade paths.**
A ZIP downloaded from Actions is just a container for these raw firmware
files; do not flash the ZIP. A matching filename and a size gate do not
certify flash safety.

## Build / publishing workflow

1. Source: pinned PPE commit `7d65a3ed836a0071e2f19a5944682f457e02efe0`.
2. On PR, `.github/workflows/release-variants.yml` builds **both**
   variants as independent jobs, never publishing a GitHub Release.
3. After `make defconfig`, enforce target selection, NSS, PPE, LuCI,
   Chinese translation and the variant-specific proxy policy.
4. After compiling, check the real package manifest and apply the **28 MiB
   hard factory UBI gate** plus sysupgrade structural validation.
5. Upload each variant's raw `.ubi`, `.bin`, manifest and audit records to
   GitHub Actions.
6. To publish, merge approved changes to `main`, use
   `Build and release AX6 Tiny + Tiny Plus (stock NAND)` →
   **Run workflow** on main, enter a new release candidate version
   (e.g. `v0.1.0-rc1`) and set `publish_prerelease=true`.
7. The release job checks the presence and SHA256 of all four binaries,
   both manifests and the common source/feeds fingerprints, and creates
   **one experimental Pre-release** only if every check passes.

No scheduled run or pull request can automatically publish firmware.
Existing release tags are not silently overwritten.

## Hardware validation gates still open

Successful builds are **not proof of bootability**. Before recommending
the images for flashing, verify:

- Real device `/proc/mtd`, UBI geometry, bad blocks and active slot,
  vendor boot flags, bootloader and a known-good recovery route.
- MAC address allocation and wireless calibration from the stock DTS;
  both radios, DHCP, DNS, firewall and reboot behavior.
- PPE routed/NAT flows and NSS Wi-Fi offload under normal traffic.
- **Tiny Plus:** HomeProxy DNS/IPv4/IPv6, VLESS Reality, Shadowsocks,
  TProxy rule matching and hardware-offload exclusions.
- Version-to-version upgrade path and retained configuration.

The release status must remain **experimental Pre-release** until those
hardware checks pass. The previous ImmortalWrt 25.12 build.yml is a
separate historical pipeline, **not** one of these two PPE variants.
