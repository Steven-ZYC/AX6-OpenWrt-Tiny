# 编译指南 / Building Guide

## 1. 版本与硬件

- 源码：`immortalwrt/immortalwrt` 的 `openwrt-25.12` 分支。
- Target：`qualcommax/ipq807x`；**仅** `redmi_ax6-stock` 原厂布局。
- Firmware 不是官方 ImmortalWrt Release，而是基于上游自行构建的实验产品。
- 当前包版本随上游 feeds 更新；请查构建时的 `*.manifest`。

## 2. GitHub Actions

1. Actions → `Build Redmi AX6 Tiny` → Run workflow。
2. 首次选 `publish_prerelease=false`。
3. 构建步骤依次是克隆源码、feeds 更新、HomeProxy 依赖替换、`.config`/`make defconfig`、配置检查、源码下载、编译、manifest 检查、Artifact 上传。
4. 若需要实验性 Release，可在手动触发时选 `publish_prerelease=true`；会显示 **Pre-release**，不是稳定版。
5. 定时任务每周跑一次，失败不会发布 Release。

**注意**：GitHub-hosted Runner 的磁盘、RAM、工作时长可能无法满足未来的上游构建要求。完整 OpenWrt 编译并非一定能在 GitHub 免费资源内成功；如遇 OOM / disk full，应先查日志，不要盲目增加并行度。

## 3. Ubuntu 24.04 手工编译

先安装这些基本依赖：

```bash
sudo apt update
sudo apt install -y build-essential ccache clang flex bison g++ gawk \
  gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev \
  python3 python3-setuptools python3-pyelftools rsync unzip \
  zlib1g-dev file wget swig time curl xz-utils zstd \
  subversion libelf-dev ca-certificates squashfs-tools
```

在项目仓库与 `openwrt` 源码同级的前提下：

```bash
git clone --depth 1 -b openwrt-25.12 https://github.com/immortalwrt/immortalwrt.git openwrt
cd openwrt
bash ../AX6-OpenWrt-Tiny/scripts/prepare.sh
cp ../AX6-OpenWrt-Tiny/configs/redmi-ax6-stock.config .config
make defconfig
bash ../AX6-OpenWrt-Tiny/scripts/check-config.sh .config
make download -j4
make -j2 V=sc
bash ../AX6-OpenWrt-Tiny/scripts/collect.sh ../AX6-OpenWrt-Tiny/dist
```

构建后检查：

```bash
cat ../AX6-OpenWrt-Tiny/dist/BUILD-REPORT.md
cat ../AX6-OpenWrt-Tiny/dist/SHA256SUMS
grep -E '^(sing-box(-tiny)?|luci-app-homeproxy) ' ../AX6-OpenWrt-Tiny/dist/*.manifest
```

## 4. 代理核心的精简原理

`luci-app-homeproxy` 原版 Makefile 的依赖是 `+sing-box`，ImmortalWrt feed 的 `sing-box-tiny` 同时声明 `PROVIDES:=sing-box`。为保证行为明确，本项目在 `feeds update` 之后、`feeds install` 之前，把 HomeProxy 的声明依赖替换成 `+sing-box-tiny`，再用 `.config` 和最终 manifest 验证不存在完整版。

目前配置保留 `uTLS` 和 `Clash API`；停用 QUIC、gVisor、WireGuard、Tailscale、gRPC 等可选特性。改动这些编译选项后必须验证 Reality / Shadowsocks 节点、DNS 分流、Firewall4 TProxy / UDP 和 IPv6 是否正常。

## 5. 调试优先级

1. `prepare.sh` 失败：上游 HomeProxy 路径或依赖声明变化，先审查 Makefile，不能直接忽略检查。
2. `make defconfig` 后失去 tiny：检查 feeds 依赖以及 `CONFIG_PACKAGE_sing-box-tiny=y` 是否仍有效。
3. `make` OOM / disk full：关注构建日志、降低并发、使用自托管 Runner。
4. `collect.sh` 未找到固件：先看 `bin/targets/qualcommax/ipq807x/` 的实际文件名，再判断是否设备 Profile 变更。
5. `collect.sh` 报完整版 sing-box：保持失败，不要发布含有两个代理核心的固件。
6. 刷机后无法联网：保留串口 / 网络恢复路径；需要在真机检查，不应仅依赖 Actions 静态验证。

## 6. 2026-11-07：Kconfig 自循环依赖修正

当前 25.12 稳定分支存在上游包元数据逻辑问题。它可能使 `dnsdist`、`snort3`、`knot-resolver`、`luci-app-weechat` 等未被选中的包也在 `make defconfig` 阶段报出 self-dependency。这里并不是要安装这些服务，也不应通过随意删除软件包来绕过报错。

本仓库在 `scripts/prepare.sh` 阶段引入了 [OpenWrt PR #26444](https://github.com/openwrt/openwrt/pull/26444) 的 *package-metadata* 修复补丁。若上游已经包含相同修复则跳过；否则严格应用补丁，失败时中止，不会静默忽略。上游合并后可以移除此临时 backport。

另一个独立问题是设备 Profile：**单设备构建**应选择 `CONFIG_TARGET_qualcommax_ipq807x_DEVICE_redmi_ax6-stock=y`；`CONFIG_TARGET_DEVICE_...` 属于 **TARGET_MULTI_PROFILE 多设备构建菜单**，不能据此判断单设备是否正确选中。固定检查已加入 `scripts/check-config.sh`。

## 7. 原厂分区是硬条件，而非体积建议

Redmi AX6 stock 的两个 rootfs MTD 分区通常各约 35.75 MiB（0x023c0000），但 UBI 的保留块、坏块和具体设备状态影响可用空间。项目以 **factory.ubi ≤28 MiB** 为保守硬限（预留约 7.75 MiB 标称空间），`scripts/check-stock-image.py` 同时验证 UBI 头、Kernel/RootFS 卷、sysupgrade tar 结构与字节数。超过 28 MiB 的镜像将令构建失败，**不会产生可供下载的成功构建 Artifact**。

实际的 2026-11-06 Build #2：用户看到的约 42 MiB 是 **Factory + Sysupgrade + 元数据** 的合集 ZIP，不是单固件；其中 factory 22.25 MiB、sysupgrade 21.24 MiB，sysupgrade 内 kernel 5.32 MiB、root 15.91 MiB。两种镜像的用途不同，不能混刷。

为防止混淆，GitHub Actions 现在分别生成三个 Artifact：stock-sysupgrade、stock-factory、stock-metadata。**CI 检查通过不等于真机验证**；刷机前必须核实 `cat /proc/mtd`、`ubinfo -a`、当前 rootfs 槽位、坏块及已有 Bootloader 布局，按照适用的官方设备说明升级。
