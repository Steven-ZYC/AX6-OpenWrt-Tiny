# AX6 硬件加速实施路线：PPE 优先、NSS Wi-Fi 随后

> 状态：**基线审查与迁移前置条件**。本文件不表示当前镜像已获得 PPE/NSS 硬件加速，也不授权直接刷机。

## 一、已确认的源码事实（2026-11-07）

- 本仓库使用 ImmortalWrt `openwrt-25.12`，`qualcommax/ipq807x` 和 `redmi_ax6-stock`（原厂分区）。
- 该分支的 `target/linux/qualcommax/Makefile` 使用 Linux **6.12**，默认有线数据路径为 `kmod-qca-nss-dp`（依赖 `kmod-qca-ssdk`）。名称中的 NSS **不代表已启用 NSS 固件硬件卸载**。
- [openwrt-ppe-nss](https://github.com/JuliusBairaktaris/openwrt-ppe-nss/tree/ppe-nss) 则使用 Linux **6.18**，`qca_edma` + `qca_ppe` 数据路径及 fw4 flowtable；`nss-wifi-drv` 加速 Wi-Fi。新架构不需要传统 `qca-nss-ecm`。
- 已检查该 PPE/NSS 分支的 `target/linux/qualcommax/image/ipq807x.mk`：存在 `redmi_ax6`，但**没有** `redmi_ax6-stock`。因此绝不能通过简单修改本仓库的目标名称，把扩容布局当作原厂布局使用。
- 当前源码没有经核实可直接开启的新 `qca_ppe` 数据路径：**不要在本仓库 25.12 配置中盲目加入 `kmod-qca-ppe`，或把 LuCI 的 Hardware Flow Offloading 开关当成硬件工作证明**。

权威参考：[ImmortalWrt 25.12 target](https://github.com/immortalwrt/immortalwrt/blob/openwrt-25.12/target/linux/qualcommax/Makefile) · [原厂 AX6 设备定义](https://github.com/immortalwrt/immortalwrt/blob/openwrt-25.12/target/linux/qualcommax/image/ipq807x.mk) · [PPE/NSS 源码](https://github.com/JuliusBairaktaris/openwrt-ppe-nss) · [OpenWrt Flow Offloading 文档](https://openwrt.org/docs/guide-user/perf_and_log/flow_offloading)

## 二、实施顺序与准入条件

### 阶段 0：现有 ImmortalWrt 25.12 基线（当前）

保持现有路由功能、Argon、HomeProxy、`sing-box-tiny`、AX6 stock 设备选择与 **Factory UBI ≤28 MiB** 检查不变。

编译时执行 `scripts/audit-datapath.sh .config ../dist/DATAPATH-AUDIT.md`，输出**源码层面的审计结果**。出现不认识的上游设备定义，尤其缺少明确 stock Profile 时直接阻止后续构建。保存包清单、Build Report 和镜像体积。

不能声称这一阶段已经启用 PPE；不能把 `qca-nss-dp` 等同于 NSS 固件加速。

### 阶段 1：PPE-only 实验构建（尚未启用）

在**独立实验分支/工作流**中选择明确包含 `qca_edma` / `qca_ppe` 的上游源码及内核，暂时不启用 `nss-wifi-drv`。

迁移之前必须全部满足：

1. 审核/移植 AX6 **stock 布局**的设备定义，并逐项核实设备树、MTD/UBI 分区、image recipe、sysupgrade 兼容性和恢复路径；绝不直接复用原有 `redmi_ax6` 扩容镜像。
2. `make defconfig` 仍明确选择唯一的 `redmi_ax6-stock`，且所有必要以太网、交换机、Wi-Fi 和校准数据驱动齐全。
3. 执行相同的镜像格式、坏块裕量和 **Factory UBI ≤28 MiB** 严格检查；超限停止，不发布刷机包。
4. 生成独立的实验构建产物和完整包清单；首次必须先验证救援手段，再测实际转发能力。
5. 在真机上观察 PPE 流表/统计以及 CPU、吞吐量，证明加速发生，而不只是界面显示选项。

### 阶段 2：NSS Wi-Fi（仅在阶段 1 安全且稳定后）

为与已验证的 PPE 数据路径兼容的内核添加 `nss-wifi-drv`、匹配的 NSS Firmware 和 ath11k 支持。**不自动加入**完整的旧 `qca-nss-drv` / ECM / NSS qdisc 套件。再次执行相同的空间、刷机、Wi-Fi 稳定性检查，并比较 NSS 开关前后性能。

## 三、必须实测的场景

| 场景 | 目的 |
| --- | --- |
| WAN ↔ 有线 LAN（IPv4/IPv6、NAT） | 测真实 PPE 卸载与 CPU 占用 |
| PPPoE / VLAN（如实际使用） | 验证 WAN 特殊封装 |
| WAN ↔ 2.4/5 GHz Wi-Fi | 测实际无线数据路径 |
| 本地路由、DNS、DHCP、防火墙 | 确保基础业务未被破坏 |
| HomeProxy + VLESS Reality / Shadowsocks、TProxy | 保证代理流量没有被 Flow Offload 绕过 |
| 重启、升级、断电恢复 | 检查可靠性和原厂分区安全 |

**重要：** 测速时区分 CPU 上运行的 sing-box 加解密与纯路由/NAT。PPE/NSS 不能直接加速 sing-box 的用户态加密计算；加速路径必须保证防火墙、代理规则仍生效。软件 Flow Offload 也不能不经验证直接全局启用。

## 四、发布决策

当前主构建维持 **AX6 stock / ImmortalWrt 25.12**。完成安全适配与实际测试前，PPE-only 和 PPE+NSS 都不得被标记为可安全刷入的生产版本。发布测试版前，需人工核对真实分区与恢复方式；GitHub Actions 的构建成功不代表刷机安全。
