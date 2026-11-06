# 刷机安全说明 / Read before flashing

> **当前项目未完成真实设备验证。不提供「直接执行」的 mtd / ubiformat / bootloader 写入命令。**

## 为什么这个固件有风险？

Redmi AX6 使用 NAND / UBI，且新源码提供两种不同的 AX6 设备配置：

- `redmi_ax6`：上游名称对应 OpenWrt expanded layout。
- `redmi_ax6-stock`：上游名称对应 stock（原厂分区）布局。

本仓库仅选择 `redmi_ax6-stock`。**不要仅凭路由器外观、旧固件文件名、128 MiB Flash 总容量或 sysupgrade 包体积判断可以直接刷入。**

## 开始之前请完成

1. 核实铭牌型号：**Redmi AX6**，非 AX6S / AX6000。
2. SSH 检查并留存：`cat /proc/mtd`、`ubinfo -a`、`cat /etc/openwrt_release`、`df -h`、当前 `uboot-envtools` / bootloader 布局资料。
3. 备份当前有效配置、Wi-Fi 射频校准数据的可恢复副本，且确认备份 **实际可读、可恢复**；不要分享校准内容。
4. 确认当前 Bootloader、系统布局和可行的恢复方式（例如串口、已验证的安全恢复工具）。
5. 下载文件后检查 `SHA256SUMS`，并查看 `BUILD-REPORT.md`、`.manifest`、`.config`。
6. 首次建议在可物理接触的设备上测试，而非远程唯一上网路由器。
7. 有新版 `factory.ubi` 并不等于可以直接用 LuCI 的 Sysupgrade 上传它；`sysupgrade.bin` 也不一定适合任何现有固件版本。

## 首次启动测试清单

- [ ] 能正常启动、SSH / LuCI 访问、设置新 root 密码
- [ ] 有线 WAN 获取 IP、有线 LAN / DHCP 正常
- [ ] 2.4 GHz、5 GHz Wi-Fi 可用、加密和地区设置正确
- [ ] 普通 DNS、IPv4（以及需要的 IPv6）正常
- [ ] Firewall4 可启动，NAT / 转发可用
- [ ] HomeProxy 可启动 / 关闭，不会破坏原生 DNS 和联网
- [ ] VLESS Reality 节点真正连接成功
- [ ] Shadowsocks 节点真正连接成功
- [ ] 规则与 DNS 分流无明显泄漏，透明代理 TCP / UDP 功能符合预期
- [ ] 软重启和断电重启后稳定
- [ ] 能使用已验证的恢复路径回到上一版

确认测试通过后才应把 Release 从 **Pre-release** 升格为稳定版本。
