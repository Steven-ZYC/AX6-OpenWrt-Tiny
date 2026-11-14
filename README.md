<div align="center">

# AX6-OpenWrt-Tiny

**Redmi AX6 原厂 NAND 布局的轻量 OpenWrt 固件**

Qualcomm PPE / EDMA · NSS Wi-Fi · LuCI / Argon · 可选 HomeProxy + sing-box-tiny

[![Build Tiny + Tiny Plus](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/actions/workflows/release-variants.yml/badge.svg)](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/actions/workflows/release-variants.yml)
[![Base: OpenWrt PPE/NSS](https://img.shields.io/badge/base-OpenWrt%20PPE%2FNSS-0066cc)](https://github.com/JuliusBairaktaris/openwrt-ppe-nss/tree/ppe-nss)
[![Device: Redmi AX6 stock](https://img.shields.io/badge/device-Redmi%20AX6%20stock-228b55)](configs/redmi-ax6-ppe-tiny-stock.config)
[![License: MIT](https://img.shields.io/badge/build_scripts-MIT-blue.svg)](LICENSE)

[**下载固件**](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/releases) · [**构建记录**](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/actions/workflows/release-variants.yml) · [**功能与版本说明**](docs/RELEASE-VARIANTS.md) · [**刷机说明**](docs/FLASHING.md)

</div>

## 项目简介

AX6-OpenWrt-Tiny 专为 **Redmi AX6（IPQ8071A，128 MiB NAND，原厂分区）** 构建，在保留 Qualcomm 硬件加速、无线网络及 LuCI 管理界面的同时，尽量缩小固件体积。

当前主线采用 **OpenWrt PPE/NSS（Linux 6.18）**，提供两个版本：

- **Tiny**：精简路由固件，包含 PPE/EDMA、NSS Wi-Fi、Firewall4、LuCI 和 Argon。
- **Tiny Plus**：在 Tiny 基础上增加 HomeProxy、sing-box-tiny、TProxy 和常用 LuCI 工具。

**当前发布： [v0.1.0-rc2](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/releases/tag/v0.1.0-rc2)**（2026-11-14）。项目已在 **Redmi AX6 原厂分区实机进行测试**；RC 版本继续用于完善兼容性和功能验证。

## 高通硬件加速架构

Redmi AX6 搭载高通 IPQ8071A。我们的固件以 **Linux 6.18 + PPE / EDMA + NSS Wi-Fi** 发挥芯片的网络加速能力：**EDMA** 负责高速收发，**PPE** 将符合条件的路由、NAT 流量交由硬件转发，**NSS Wi-Fi** 优化无线数据路径，并与 Firewall4 / nftables 协同工作。

旧式方案常依赖 NSS/ECM、Shortcut-FE 等厂商驱动与旧内核补丁。我们采用 **PPE 主导转发、NSS 专注无线** 的新架构，减少旧组件堆叠：**数据通路更清晰，更贴近新内核，后续维护也更轻便。**

## 功能对比

| 功能 | Tiny | Tiny Plus |
|---|:---:|:---:|
| Qualcomm PPE / EDMA、NSS Wi-Fi | ✅ | ✅ |
| Firewall4 / nftables | ✅ | ✅ |
| LuCI、HTTPS、Argon、简体中文 | ✅ | ✅ |
| HomeProxy + sing-box-tiny | — | ✅ |
| VLESS Reality / Shadowsocks | — | ✅ |
| nftables TProxy | — | ✅ |
| LuCI 网页终端（ttyd） | — | ✅ |
| LuCI 文件管理与上传下载 | — | ✅ |
| 系统计划任务（Cron） | ✅ | ✅ |
| 配置备份、恢复与固件升级页面 | ✅ | ✅ |

Tiny Plus 仅保留一个代理核心：**sing-box-tiny**。当前编译选项保留 uTLS、Clash API，移除 QUIC 和 gVisor 相关功能，以控制体积。Hysteria2、TUIC、WireGuard 等不属于该版本的预设功能范围。

两个版本均使用 `redmi_ax6-stock` 设备配置，并在构建时检查 **Factory UBI ≤ 28 MiB**。

## 上游与技术路线

| 层次 | 使用的上游或配置 |
|---|---|
| 系统主体 | [JuliusBairaktaris/openwrt-ppe-nss](https://github.com/JuliusBairaktaris/openwrt-ppe-nss/tree/ppe-nss)，`ppe-nss` 分支 |
| Linux 内核 | 6.18 |
| PPE / EDMA | 该分支的 Qualcomm 网络数据路径 |
| NSS Wi-Fi | [nss-packages](https://github.com/JuliusBairaktaris/nss-packages) feed 与匹配的无线驱动、固件 |
| HomeProxy / Argon | [ImmortalWrt LuCI](https://github.com/immortalwrt/luci/tree/openwrt-25.12) 的指定软件包 |
| sing-box-tiny | OpenWrt packages feed；由本项目进一步精简编译选项 |
| AX6 原厂分区支持 | 参考 ImmortalWrt 25.12 的 stock 布局，在构建阶段适配 PPE/NSS 源码 |
| 设备 Target / Profile | `qualcommax/ipq807x` / `redmi_ax6-stock` |

新版 Tiny / Tiny Plus 以 **OpenWrt PPE/NSS** 为基础，参考 ImmortalWrt 25.12 适配 AX6 原厂分区，并选用其 HomeProxy / Argon 软件包。旧版 ImmortalWrt 构建保留在 [`build.yml`](.github/workflows/build.yml)。

新版工作流将 PPE 主源码固定在以下 commit，便于复现：

```text
7d65a3ed836a0071e2f19a5944682f457e02efe0
```

Feeds 可能随上游更新；发布包附带 `PPE-SOURCE-SHA.txt`、`IMMORTALWRT-LUCI-SHA.txt`、manifest 等溯源信息。

## 下载与刷机

在 [Releases](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/releases) 中，每个 RC 版本统一提供四个镜像：

| 版本 | Factory | Sysupgrade |
|---|---|---|
| Tiny | `AX6-tiny-<版本>-factory.ubi` | `AX6-tiny-<版本>-sysupgrade.bin` |
| Tiny Plus | `AX6-tiny-plus-<版本>-factory.ubi` | `AX6-tiny-plus-<版本>-sysupgrade.bin` |

- **Factory UBI** 和 **Sysupgrade BIN** 适用于不同的刷入方式，不要混用。
- 固件目标为 **Redmi AX6 原厂 NAND 分区**，不适用于 AX6S、AX6000 或扩容分区配置。
- 原厂 AX6 使用双系统槽位；升级前应核对当前 U-Boot、分区及 `flag_boot_rootfs` 状态。LuCI 的标准升级界面不等于已经验证过的双槽自动回滚方案。

首次刷机、跨固件迁移和恢复操作请参考 [刷机说明](docs/FLASHING.md)。常规 LuCI 配置备份不等于完整 NAND / ART / U-Boot 备份。

## RC2 首次启动配置

下面的值适用于 **v0.1.0-rc2 及使用相同首次启动配置的后续构建**，在全新安装、清空配置或恢复出厂设置时生效；保留原有设置升级时，通常不会覆盖用户配置。

| 项目 | 默认值 |
|---|---|
| LAN / LuCI | `192.168.123.1` |
| 2.4 GHz SSID | `Not your internet^_^` |
| 5 GHz SSID | `Not your internet^_^ 5G` |
| 无线加密 | WPA2/WPA3 Personal（`sae-mixed`） |
| 初始 Wi-Fi 密码 | `password123` |
| DNS Rebind Protection | 关闭，兼容部分校园 DNS 返回内网地址的情况 |
| LuCI 网页终端 | 仅 Tiny Plus；通过 `/bin/login` 登录 |

**首次连接后请修改 Wi-Fi 密码并设置 root 密码。** 初始密码已公开；不需要校园 DNS 兼容设置时，建议恢复 DNS Rebind Protection：

```sh
uci set dhcp.@dnsmasq[0].rebind_protection='1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

两个版本均可在 LuCI「系统 → 计划任务」中按需添加 Cron，例如每周日 05:00 重启：

```cron
0 5 * * 0 /sbin/reboot
```

默认不安排定时重启。Tiny Plus 另外提供网页终端和文件管理器。

## 编译

推荐在 **Ubuntu 24.04** 上使用 [GitHub Actions](.github/workflows/release-variants.yml) 编译。工作流分别构建 Tiny 与 Tiny Plus，并检查实际安装包清单、源码版本、镜像结构、SHA256 和 28 MiB Factory UBI 体积限制。

本地构建 Tiny Plus 的核心步骤：

```bash
git clone https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny.git
cd AX6-OpenWrt-Tiny

git clone --depth 1 --branch ppe-nss \
  https://github.com/JuliusBairaktaris/openwrt-ppe-nss.git ppe-source
cd ppe-source
git fetch --depth 1 origin 7d65a3ed836a0071e2f19a5944682f457e02efe0
git checkout --detach 7d65a3ed836a0071e2f19a5944682f457e02efe0

bash ../scripts/prepare-ppe-tiny.sh
cp ../configs/redmi-ax6-ppe-tiny-plus-stock.config .config
make defconfig
bash ../scripts/verify-ax6-variant.sh config tiny-plus .config
make download -j4
make -j2 V=sc
```

Tiny 版本请改用 [`configs/redmi-ax6-ppe-tiny-stock.config`](configs/redmi-ax6-ppe-tiny-stock.config)，校验命令的 `tiny-plus` 相应改成 `tiny`。系统需要预先安装 OpenWrt 的编译依赖，具体配置与发布流程以 [`release-variants.yml`](.github/workflows/release-variants.yml) 为准。

## 仓库结构

```text
.github/workflows/   GitHub Actions（双版本构建、历史构建、检查）
configs/             Tiny / Tiny Plus 及实验版配置
scripts/             源码适配、feeds 准备、校验与产物整理
files/               固件首次启动配置
patches/             历史构建所需补丁
docs/                构建、功能、硬件加速与刷机说明
tests/               构建脚本与配置检查
```

## 参考与致谢

- [OpenWrt](https://github.com/openwrt/openwrt) · [ImmortalWrt](https://github.com/immortalwrt/immortalwrt)
- [JuliusBairaktaris/openwrt-ppe-nss](https://github.com/JuliusBairaktaris/openwrt-ppe-nss) · [nss-packages](https://github.com/JuliusBairaktaris/nss-packages)
- [SagerNet/sing-box](https://github.com/SagerNet/sing-box) · [jerrykuku/luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon)
- [hochenchong/Actions-OpenWrt](https://github.com/hochenchong/Actions-OpenWrt) · [fichenx/Actions-OpenWrt](https://github.com/fichenx/Actions-OpenWrt) · [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)（构建流程与文档参考）

本仓库的自有脚本和文档按 [MIT License](LICENSE) 发布；上游源码与固件内的软件包遵循各自许可证。

---

<div align="center">

**Small firmware. Clear choices. Reproducible builds.**

</div>
