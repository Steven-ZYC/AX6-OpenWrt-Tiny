# Redmi AX6: original 2023 Snapshot networking packages vs PPE + Tiny (2026)

This review uses the package manifest extracted from the **user's actual original**
`openwrt-ipq807x-generic-redmi_ax6-squashfs-nand-{factory.ubi,sysupgrade.bin}`,
not a generic LEDE package list.

- Original: LEDE/OpenWrt SNAPSHOT `r5935-26f363463`, Linux **5.10.176**, opkg,
  239 installed packages, sysupgrade 27.24 MiB, factory UBI 28.50 MiB.
- PPE-only feasibility build: OpenWrt/PPE Linux **6.18**; 167 packages;
  factory UBI 13.62 MiB, sysupgrade 12.88 MiB. No proxies.
- Proposed combined build: OpenWrt/PPE Linux 6.18, AX6 **stock** profile,
  LuCI/Argon/HomeProxy/sing-box-tiny, NSS Wi-Fi and PPE traffic support.
  **Not yet proven to compile or boot**. The 28 MiB factory hard gate remains.
- No old .ipk or kernel modules can be copied over: different kernel ABIs,
  libc/package manager, nftables firewall and driver datapath.

## Qualcomm datapath inventory

| Component | Old 5.10 Snapshot | Combined 6.18 proposal | Decision / risk |
|---|---|---|---|
| `qca_edma` / `qca_ppe` (kernel) | Older `kmod-qca-nss-dp` path | Upstream kernel EDMA/PPE | INCLUDE; not a standalone 5.10 kmod |
| `ppe-help` | Not present | Included | INCLUDE; information only, not proof of active PPE |
| `kmod-nft-offload` | iptables/legacy accelerated stack | Included | INCLUDE; fw4 flowtable, leave hardware offload disabled until TProxy tests |
| `kmod-nss-wifi-drv` and `ATH11K_NSS_WIFI` | Old `kmod-qca-nss-drv-64` | Included from PPE 6.18 source | INCLUDE new driver; never mix old NSS host stack |
| `nss-firmware-ipq807x` | Old `nss-firmware-ipq8074` | New feed, NSS 12.5 | INCLUDE if new Wi-Fi offload driver selected; firmware adds storage cost |
| `tc-tiny` and `kmod-sched-*` | Not generally selected | flower/prio/mqprio/red/actions | INCLUDE minimal PPE tc support; runtime SQM needs separate testing |
| `qca-ppe-qos`, `luci-app-qca-ppe-qos` | Not present | **NOT** in default build | Upstream requires a patched SQM feed and custom LuCI fork; cannot blindly enable without a compatible patchset |
| `dcb`, `devlink`, `ethtool-full`, advanced `kmod-sched-ets/gred` | Not present | Not in minimum config | Optional advanced PPE QoS diagnostics; decide after size/performance results |
| `kmod-qca-nss-dp`, `kmod-qca-ssdk-nohnat` | Present | Excluded | Old 5.10 network stack, incompatible/redundant with new EDMA/PPE |
| `kmod-qca-nss-drv-bridge-mgr-64`, `...pppoe-64`, `...vlan-mgr-64` | Present | Excluded | Vendor NSS APIs do not map to new PPE switchdev/flowtable |
| `kmod-qca-nss-ecm-64`, `kmod-shortcut-fe`, `kmod-shortcut-fe-drv`, `luci-app-turboacc` | Present | Excluded | Parallel acceleration paths/UI; risk to offload and nftables state |
| `kmod-cryptodev` | Present | Excluded | Kernel-specific crypto character device, not required for VLESS/Reality |
| `kmod-tcp-bbr` | Present | Deferred | TCP congestion control choice, NOT PPE hardware acceleration; modern kernel Kconfig/ABI differs |

## Old Snapshot network-related packages: user decision queue

These are the **remaining optional extras**. None below is automatically
selected as an add-on to the new Tiny profile.

| Package(s) in original Snapshot | Function | Relation/conflict with PPE + Tiny | Recommendation |
|---|---|---|---|
| `dnsmasq-full` | Extended DNS and DHCP including filtering / sets | Can replace standard dnsmasq, but **do not install both**; old ipset rules differ from nftset | **Conditional** if DNS filtering with nftsets needed |
| `chinadns-ng` | Split domestic/foreign DNS resolution | Duplicates some HomeProxy/sing-box DNS routing, may conflict with DNS hijack/loop rules | **Do not add by default** |
| `pdnsd-alt`, `dns2socks`, `dns2tcp` | DNS cache / send DNS via TCP or SOCKS | Overlaps sing-box DNS transports; extra listeners may conflict | **Do not add** unless special use |
| `ddns-scripts`, `ddns-scripts_aliyun`, `ddns-scripts_dnspod` | Dynamic DNS for changing WAN IPv4/IPv6 | Normally no PPE conflict; cloud credential/storage overhead | **Good optional** for remote access |
| `nlbwmon`, `luci-app-nlbwmon` | Per-host bandwidth statistics in LuCI | May undercount fastpathed hardware-offloaded traffic | **Optional with caveat** |
| `luci-app-arpbind` | IP/MAC static ARP binding UI | Generally independent of PPE but custom version may be obsolete | **Optional**, static DHCP leases may suffice |
| `luci-app-autoreboot` | Scheduled reboot UI | No inherent PPE clash, causes service interruption | **Not needed by default** |
| `luci-app-filetransfer` | Upload/download via LuCI | No datapath clash, larger management/attack surface | **Optional** |
| `ttyd`, `luci-app-ttyd` | Browser terminal | No PPE clash, but security and space overhead | **Optional with LAN-only access** |
| `tcping`, `ethtool`, `ip-full`, `curl` | TCP probe, Ethernet link/driver diagnostics, IP administration, HTTP client | No fundamental PPE clash; `ethtool` especially useful to debug hardware | **Useful tools if space permits** |
| `kmod-macvlan` | Virtual MAC interfaces | Not needed for ordinary single-WAN home use; may alter acceleration path | **Conditional** |
| `kmod-br-netfilter` | Bridge packets to netfilter hooks | Could interact with bridged NSS Wi-Fi traffic; requires targeted testing | **Conditional, do not auto-add** |
| `iptables`, `iptables-mod-tproxy`, `iptables-mod-fullconenat`, `ipset`, `kmod-ipt-*` | Old firewall3/iptables/TProxy/IP sets | Modern base is firewall4/nftables, with `kmod-nft-tproxy`; rules not portable | **Exclude old stack** |
| `luci-app-ssr-plus`, `xray-core`, `v2ray-plugin`, `trojan`, `shadowsocks-rust-sslocal/ssserver`, `shadowsocksr-libev-*`, `simple-obfs-client`, `microsocks`, `ipt2socks` | Legacy proxy protocols/GUI, independent binaries | Overlaps HomeProxy + sing-box-tiny; major flash size cost and ports/rules conflict risk | **Exclude redundant cores** |
| `ppp`, `ppp-mod-pppoe`, `kmod-pppoe` | ISP WAN PPPoE dial-up | Required if WAN is PPPoE; relies on correct modern kernel modules | **Keep OpenWrt target defaults if needed** |
| `ath11k-firmware-ipq8074`, `ipq-wifi-redmi_ax6`, `kmod-ath11k*` | AX6 wireless operation/calibration | Required; must use firmware/driver paired to 6.18 + NSS Wi-Fi selection | **Keep modern matching build dependencies** |

## Important unresolved compatibility items

1. Hardware offload `flow_offloading_hw` vs HomeProxy nftables TProxy.
   Proxy-destined traffic must not get accelerated around netfilter policy.
2. NSS Wi-Fi requires correct stock DTS and calibration; compiling is not
   evidence of offload functionality. Mesh and NSS firmware 12.5 differ.
3. The OpenWrt master sing-box-tiny recipe hardcodes extra Go build tags.
   The new preparation script guards and removes QUIC/gVisor for minimum
   VLESS Reality + Shadowsocks + Clash API support. This is an experimental
   recipe change, and its final binary must be runtime-tested.
4. ImmortalWrt 25.12 HomeProxy + Argon are imported as **two isolated package
   folders** rather than overwriting the Linux 6.18 OpenWrt feeds. Their
   compatibility with current LuCI/ucode must pass the GitHub build.
5. The combined image can exceed 28 MiB even though the PPE-only image passed.
   Build must refuse to publish an over-limit image.
6. `factory.ubi` vs `sysupgrade.bin`, UBI bad blocks, the active boot slot,
   MAC addresses and original stock SMEM partitioning remain unverified on hardware.
7. `qca-ppe-qos` needs the upstream builder-specific patched feeds; **not**
   silently added because its packaging is not yet part of the simple safe build.

**User decision pending:** enable any optional software in the table above
only after checking firmware size and identifying a real use case. Don't port
the 2023 binaries or iptables/NSS acceleration drivers.
