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


## 五、实验 CI/CD 的使用（新增）

本项目现在分为**生产基线**与**实验验证**两条互不替代的工作流：

| 工作流 | 触发方式 | 实际行为 | 输出 |
| --- | --- | --- | --- |
| `.github/workflows/build.yml` | 原有计划任务/手动 | ImmortalWrt 25.12 的 Tiny + HomeProxy + sing-box-tiny | 通过大小检查才有原有固件 Artifacts |
| `.github/workflows/lint.yml` | PR/Push | 脚本和安全门槛回归测试 | CI 结果 |
| `.github/workflows/ppe-only-experiment.yml` | PR 自动预检；手动选择 full_compile 才完整编译 | 上游 `ppe-nss` + 临时 AX6 stock Profile，**只验证 PPE 有线转发基础配置** | 仅构建日志、元数据报告；**不上传固件** |

实验 Profile 在 `configs/redmi-ax6-ppe-only-stock.config` 中。为了隔离网络数据路径问题，**这一版不是完整的 Tiny 用户功能构建**，暂时不含 Argon、HomeProxy 和 sing-box-tiny，也不启用 `nss-wifi-drv`。

在 PR 中，实验工作流会自动执行 `source-guard`，检查 PPE 内核配置与 AX6 stock 设备定义；不会自动启动漫长的固件编译。**GitHub 的 `workflow_dispatch` 通常需要工作流文件先存在于默认分支**；进入默认分支后可在 Actions 中选 `Experimental PPE-only AX6 stock (not flashable)` → Run workflow → `full_compile=true`。这是人工触发的诊断编译，避免 PR 每次更新都重复占用多个小时的 GitHub Runner。

`full_compile` 将：
1. 克隆上游的 `ppe-nss` 分支，并要求与预检的 commit 完全一致，防止上游 rebase 时错用不同版本。
2. 添加经过严格字符串匹配的 AX6 stock Profile；若上游定义变化则停止构建，而不是猜测补丁如何应用。
3. 执行 `make defconfig`、校验唯一 stock 目标和排除 NSS Wi-Fi，随后下载及编译。
4. 要求生成且只生成一个 stock `factory.ubi` 和 `sysupgrade.bin`，用原有 `scripts/check-stock-image.py` 校验 UBI 格式、sysupgrade 结构和 **28 MiB 硬限制**。
5. 只上传 `ppe-report/` 下的配置、上游源码 SHA、包清单和审计结果。**不会上传 `.ubi` 或 `.bin`**，也不会执行发布/刷机步骤。

安全说明：成功编译及 UBI 检查**不能证明** stock Profile 的设备树/bootloader/刷写流程与真实设备匹配。后续仍须审核真实分区布局和恢复能力，在实际测试硬件上完成端口、无线、PPE offload 流表与代理绕过风险测试，再开始整合用户功能。
