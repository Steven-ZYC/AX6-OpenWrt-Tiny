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
| LuCI browser terminal (luci-app-ttyd + ttyd) | **No** | **Yes** |
| LuCI File Manager / uploads (luci-app-filemanager) | **No** | **Yes** |
| LuCI Scheduled Reboot (luci-app-autoreboot; disabled by default) | **No** | **Yes** |
| Standard LuCI config backup / restore / firmware upload | **Yes** | **Yes** |
| VLESS Reality / Shadowsocks | **No proxy client** | **Target features (runtime verification needed)** |

Tiny and Tiny Plus share the SAME source revision and foundational network
packages. Only the Plus variant may install proxy-related packages. The
build checks the **actual installed manifest**, not just the requested config.

## RC2 first-boot defaults (NOT in published RC1)

The next build embeds `files/etc/uci-defaults/95-ax6-tiny-firstboot` in
**both** variants. New installations / clean-overlay boots use:

- LAN: `192.168.123.1`.
- 2.4 GHz: `Not your internet^_^`.
- 5 GHz: `Not your internet^_^ 5G`.
- WPA2/WPA3 Personal transitional mode (`sae-mixed`), known shared
  default password `password123` (no spaces), both radios enabled.
- DNS rebind protection **disabled**, for environments where campus
  DNS intentionally returns private addresses.
- Plus variant adds the LuCI interactive terminal with `/bin/login`
  authentication expectation. **Do not bypass login or expose port 7681 on WAN.**

**Security warning:** Common/public Wi-Fi credentials and global DNS rebind
exceptions are insecure outside a controlled environment. Set a strong
router administrator password immediately and rotate both Wi-Fi passwords.
Re-enable DNS rebind protection via
`uci set dhcp.@dnsmasq[0].rebind_protection=1`, then commit and restart
dnsmasq. Prefer per-domain exemptions if they meet campus needs.

This initial-default script is a build overlay, not an auto-migration tool;
preserved user configurations and existing radio interfaces must be validated
after upgrade. Changing this branch does **not** modify the already published
`v0.1.0-rc1` binaries. The stock-layout and 28 MiB size audits remain mandatory.

**Backup / Flash Firmware** is provided by `luci-mod-system`, which both
variants already pull in via `luci`. Plus explicitly pins it as a required
package and checks the installed manifest. File Manager is sourced from the
current OpenWrt LuCI feed. Scheduled Reboot comes from the vetted
ImmortalWrt 25.12 LuCI app (as HomeProxy and Argon do). Scheduled reboot
stays **disabled** until explicitly configured.

**IMPORTANT:** LuCI's standard firmware-upload/upgrade page is NOT a
validated dual-slot auto-updater for Redmi AX6 stock NAND. The current
custom platform upgrade logic selects a UBI partition based on the
`flag_boot_rootfs` value and does not promise inactive-slot writes or
automatic rollback. Do not encourage novice users to force a factory UBI
through LuCI sysupgrade. Config backups are NOT raw NAND backups. File
Manager's LuCI ACL grants extensive filesystem access, so strong admin
credentials, non-default Wi-Fi passwords and LAN-only management matter.

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
