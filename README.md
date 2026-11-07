<div align="center">

# AX6-OpenWrt-Tiny

**为 Redmi AX6（IPQ8071A）打造的轻量、可复现、自动构建固件**  
**Tiny（纯路由加速） · Tiny Plus（增加 HomeProxy / sing-box-tiny） · 原厂 NAND 布局**

[![Build AX6](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/actions/workflows/build.yml/badge.svg)](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/build_scripts-MIT-blue.svg)](LICENSE)
[![ImmortalWrt](https://img.shields.io/badge/base-ImmortalWrt%2025.12-0066cc)](https://github.com/immortalwrt/immortalwrt/tree/openwrt-25.12)
[![Device](https://img.shields.io/badge/device-Redmi%20AX6%20stock-green)](configs/redmi-ax6-stock.config)

[**编译状态 / Actions**](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/actions) · [**下载 / Releases**](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/releases) · [**编译选项**](configs/redmi-ax6-stock.config) · [**刷机注意事项**](docs/FLASHING.md)

</div>

> [!WARNING]
> **实验性项目：PPE + Tiny Plus 已完成云编译；尚未验证 Redmi AX6 真机刷入、Wi-Fi / NAT / 代理功能。** 首次成功构建 ≠ 可以安全刷机。此仓库目前面向 **Redmi AX6 原厂分区（stock layout）**，不是 AX6S、AX6000，也不是扩容 / 自定义 U-Boot 布局。务必先读 [刷机安全说明](docs/FLASHING.md)。

## PPE 双版本固件（新路线）

**每次 Release 只使用一个版本号，同时提供 Tiny 和 Tiny Plus 两个版本，各有 Factory UBI 与 Sysupgrade BIN，共四个镜像。**

| 项目 | Tiny | Tiny Plus |
| :-- | :-- | :-- |
| 高通 PPE / EDMA、NSS Wi-Fi | ✅ | ✅ |
| LuCI / HTTPS / Argon / 简体中文 | ✅ | ✅ |
| Firewall4 / nftables | ✅ | ✅ |
| HomeProxy / sing-box-tiny / VLESS Reality / Shadowsocks | ❌ 不包含代理包 | ✅ 打包代理功能 |
| nftables TProxy | ❌ 不包含 | ✅ |
| 原厂分区 28 MiB Factory UBI 硬门槛 | ✅ | ✅ |

[**双版本完整说明**](docs/RELEASE-VARIANTS.md) · [**双版本 CI / Pre-release 工作流**](.github/workflows/release-variants.yml) · [**查看 Releases**](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/releases)

> **安全提醒：** 已通过的 GitHub 构建并不等于真机启动或刷写安全认证。首次双版本发布仅标记为 **Pre-release**，固件必须针对 Redmi AX6 **stock NAND** 分区核实，不能与 expanded layout 混用。下文 ImmortalWrt 25.12 描述为独立的旧版编译路线；本双版本基于 Linux 6.18 的 PPE 实验源。

---

## 项目介绍

这是一个**尽可能小，但不牺牲基础路由功能与长期可维护性**的 Redmi AX6 固件构建仓库。核心原则是：

- **只保留一个代理核心**：`sing-box-tiny`，由 HomeProxy 管理；不打包 Xray、SSR Plus、Passwall、OpenClash 等功能重叠的核心。
- **保留好用的 LuCI**：包含 Argon、HomeProxy 和中文翻译；不为极限压缩删除网络、防火墙或必要硬件驱动。
- **追求固件体积可量化**：参考旧固件的 SquashFS **1024 KiB 块大小**思路，生成 manifest、完整 `.config`、SHA256 与体积报告。XZ 算法是否实际采用应检查最终生成的文件系统，不能单凭配置片段推断。
- **可复现、易更新**：GitHub Actions 定期或手动从上游源码构建；发布包记录上游 Git commit 和所打包的软件包。
- **先确认 PPE，再考虑 NSS Wi-Fi**：当前 25.12 使用旧的 `qca-nss-dp` 数据路径，并不等于已有新 `qca_ppe` 硬件 Flow Offload。迁移安全门槛与实验计划见 [硬件加速路线](docs/HARDWARE-ACCELERATION.md)。

### 固件信息

| 项目 | 说明 |
| :-- | :-- |
| 设备 | **Redmi AX6**（不是 AX6S、AX6000） |
| SoC / Flash | Qualcomm IPQ8071A / 128 MiB NAND |
| 系统源码 | [ImmortalWrt `openwrt-25.12`](https://github.com/immortalwrt/immortalwrt/tree/openwrt-25.12) |
| Target | `qualcommax / ipq807x` |
| Device Profile | **`redmi_ax6-stock`**（原厂布局） |
| 内核 | 上游该分支 Linux 6.12 系列；最终小版本以构建报告为准 |
| 管理界面 | LuCI + Argon（版本随 ImmortalWrt 对应 feeds） |
| 代理界面 / 核心 | HomeProxy + `sing-box-tiny`（默认不包含完整版） |
| 代理协议目标 | VLESS + Reality、Shadowsocks（以真实节点验证为准） |
| 透明代理 | Firewall4 + nftables TProxy 相关依赖 |
| 压缩块大小 | SquashFS 1024 KiB；压缩算法需检查实际镜像 |
| 存储优化目标 | ****Factory UBI ≤28 MiB 硬性限制**** sysupgrade 包，**超过则构建失败；仍须检查设备实际分区和坏块 |
| 默认 LAN IP / 凭据 | 以构建时上游默认值为准；**不预置通用密码** |
| PPE / NSS / Wi-Fi | 当前保留旧驱动与 Wi-Fi 支持，**未验证 PPE/NSS 加速**；构建报告附静态数据路径审计 |

## 构建状态与下载

| 变体 | Profile | 工作流 | 下载 | 备注 |
| :-- | :-- | :-- | :-- | :-- |
| **AX6 Tiny · stock** | [`redmi_ax6-stock`](configs/redmi-ax6-stock.config) | [![Build](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/actions/workflows/build.yml/badge.svg)](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/actions/workflows/build.yml) | [Actions Artifacts](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/actions) · [Releases](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/releases) | **实验性，待首编与实机验证** |

自动构建产物包含镜像、`*.manifest`、`build.config`、`BUILD-REPORT.md`、`DATAPATH-AUDIT.md` 和 `SHA256SUMS`。每次成功构建的三个独立 Artifact 在 Actions → 对应 run → **Artifacts** 下载（默认保留 14 天）。固件分三个独立 Artifact：**Sysupgrade、Factory UBI、元数据报告**，避免把整个合集 ZIP 大小误认为单个可刷入镜像。若 Factory UBI 大于 28 MiB，构建直接失败，不上传任何固件。只有在手动构建时选择 `publish_prerelease=true` 才会创建标记为 **Pre-release** 的测试发布；定时构建不会自动发布可刷写固件。

## 集成组件

| 类别 | 集成内容 | 新手理解 |
| :-- | :-- | :-- |
| Web 后台 | **LuCI + HTTPS** | 浏览器里管理路由器和网络设置 |
| 界面主题 | **Argon** | 更现代的后台外观 |
| 代理管理 | **HomeProxy** | 填入节点、管理规则、决定哪些连接走代理 |
| 代理引擎 | **sing-box-tiny** | 实际执行 VLESS Reality、Shadowsocks 等网络连接 |
| 防火墙 | **firewall4 / nftables** | 负责路由器基础防护和透明流量处理 |
| 无线驱动 | **上游 AX6 驱动和 Wi-Fi 固件** | 让 2.4/5 GHz 无线网络正常工作 |
| DNS / DHCP | **保留系统默认组件** | 域名解析、向设备分配 LAN 地址 |

`sing-box-tiny` 主要保留 uTLS 与 Clash API，关闭 QUIC、gVisor、WireGuard、Tailscale、gRPC 等可选功能。**因此不保证 Hysteria2、TUIC、WireGuard 等协议可用。** 若以后需要某项协议，必须重新启用对应的核心编译特性并实测。

<details>
<summary><strong>为什么不把所有插件全部装进去？</strong></summary>

此项目**有意不打包**：OpenClash、SSR Plus、Passwall、Xray、V2Ray-plugin、Trojan 独立核心、Docker、Samba、DLNA、FTP、AdGuard Home、SmartDNS、TTyD、额外主题、多数 VPN 工具。它们并不是「没用」，而是不属于本项目最小目标。部分系统包会因依赖自动出现，不建议在构建后直接在路由器上强删。

</details>

## CI/CD工作流（GitHub Actions）

本项目工作流默认每周日 03:17 UTC（香港时间 11:17）自动尝试构建一次，方便发现上游兼容性变化。Actions 资源、计费、磁盘空间限制以 GitHub 当前账户计划和官方规则为准。

## 本地编译（Ubuntu 24.04）

适合想自行修改功能的人。需要充足硬盘空间；完整工具链和 sing-box 编译不适合直接在 AX6 上执行。

```bash
git clone -b openwrt-25.12 --depth 1 https://github.com/immortalwrt/immortalwrt.git openwrt
cd openwrt
bash ../AX6-OpenWrt-Tiny/scripts/prepare.sh
cp ../AX6-OpenWrt-Tiny/configs/redmi-ax6-stock.config .config
make defconfig
bash ../AX6-OpenWrt-Tiny/scripts/check-config.sh .config
make download -j4
make -j2 V=sc
bash ../AX6-OpenWrt-Tiny/scripts/collect.sh ../AX6-OpenWrt-Tiny/dist
```

上面假设 `openwrt/` 和 `AX6-OpenWrt-Tiny/` 位于同一个目录，且本地已经装好 OpenWrt 编译依赖。完整说明见 [编译说明](docs/BUILDING.md)。

## 目录结构

```text
AX6-OpenWrt-Tiny/
├── .github/workflows/           # build.yml 自动编译 / lint.yml 快速检查
├── tests/smoke.sh               # 不联网的构建配方回归测试
├── configs/
│   └── redmi-ax6-stock.config     # 精简配置（stock layout）
├── scripts/
│   ├── prepare.sh                 # feeds + HomeProxy tiny-core 依赖补丁
│   ├── check-config.sh            # 阻止选错 AX6 Profile / 完整版 sing-box
│   └── collect.sh                 # 检查 manifest、生成 SHA256 / 报告
├── docs/
│   ├── BUILDING.md                # 开发、编译及调试
│   ├── FLASHING.md                # 刷机前必须阅读
│   └── DESIGN.md                  # 为什么这样精简
├── LICENSE
└── README.md
```

## 构建兼容性说明

ImmortalWrt 25.12 的包元数据生成器可能触发上游已知的 Kconfig 自循环依赖（例如 dnsdist/snort3）。本项目临时 backport [OpenWrt PR #26444](https://github.com/openwrt/openwrt/pull/26444)，并修正单设备 stock Profile 检查。参见 [编译指南](docs/BUILDING.md#6-2026-11-07kconfig-自循环依赖修正)。补丁不改变固件中的代理规则或额外安装这些软件包。

## 常见问题

**Q：可以直接把生成的 `factory.ubi` 刷进去吗？**  
A：不能单凭文件名决定。`factory.ubi` 与 `sysupgrade.bin` 适用的升级路径不同，且 stock 和 expanded 布局**不能混用**。从第三方 LEDE 迁移到新固件时，先核对 `/proc/mtd`、UBI、Bootloader、当前刷机方式及官方设备说明。

**Q：为什么不是最新 sing-box？**  
A：首版优先让同一稳定分支的 HomeProxy 与 sing-box 同步。上游 feeds 的核心版本会在 `*.manifest` 体现；不能把版本号当作兼容性验证。

**Q：为什么要修改 HomeProxy Makefile？**  
A：ImmortalWrt 25.12 的 HomeProxy 仍写了 `+sing-box` 依赖；脚本将其替换为明确的 `+sing-box-tiny`，并检查最终包清单，降低误打包完整版核心的风险。

**Q：为什么没有直接继承旧固件的 NSS / Turbo ACC？**  
A：不同内核和数据路径并不自动兼容。先稳定实现网络和无线，再独立比较 Flow Offload / NSS 的性能与兼容性。

**Q：30 MiB 是硬限制吗？**  
A：**原来的 30 MiB 优化目标已提升为硬性检查：Factory UBI 必须 ≤28 MiB**。AX6 原厂 rootfs/rootfs_1 典型为 35.75 MiB，但 UBI 必须预留坏块等开销。28 MiB 是保守构建准入阈值，不是刷入保证。

## 参考、致谢与归属

项目的**文档组织方式、自动构建流程设计与实践**参考了以下仓库，特此说明：

- [**fichenx/Actions-OpenWrt**](https://github.com/fichenx/Actions-OpenWrt) — 重点参考其详细的 README 组织结构、设备 / 固件变体表、编译状态和下载入口、构建缓存、构建信息与发布展示方式。**本项目不直接复制其固件配置或插件大合集**。
- [**hochenchong/Actions-OpenWrt**](https://github.com/hochenchong/Actions-OpenWrt) — 参考其 Redmi AX6 专项 GitHub Actions 工作流、源码拉取、`.config` 装载和自动发布的思路；不沿用其 2023 年 LEDE 回退提交。
- [**P3TERX/Actions-OpenWrt**](https://github.com/P3TERX/Actions-OpenWrt) — 以上自动编译模板的重要源头。
- [**ImmortalWrt**](https://github.com/immortalwrt/immortalwrt) · [**OpenWrt**](https://github.com/openwrt/openwrt) — 路由操作系统和构建系统。
- [**ImmortalWrt LuCI / HomeProxy**](https://github.com/immortalwrt/luci) · [**SagerNet/sing-box**](https://github.com/SagerNet/sing-box) · [**jerrykuku/luci-theme-argon**](https://github.com/jerrykuku/luci-theme-argon) — 核心应用与主题上游。

本仓库自己的工作流、辅助脚本和文字使用 [MIT License](LICENSE)；**编译生成的固件及其中组件分别遵循其各自开源许可证（例如 GPL）**，不因本仓库使用 MIT 而变更。请在重新分发二进制时遵守对应许可证和源码提供义务。

---

<div align="center">

**Small firmware. Clear choices. Reproducible builds.**  
*精简的是重复功能，不是必要的网络安全和硬件支持。*

</div>
