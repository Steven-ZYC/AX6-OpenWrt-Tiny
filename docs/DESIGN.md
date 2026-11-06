# 精简设计说明

## 改善空间来自哪里？

旧版 LEDE AX6 固件打包了 Xray、v2ray-plugin、Shadowsocks Rust 客户端 / 服务端等多个代理可执行文件。大量功能重叠，因此即使旧固件使用 SquashFS XZ 高压缩，仍有许多可裁减的空间。

本项目：

- 用一个 `sing-box-tiny` 取代多代理核心路线。
- 保留 Argon + HomeProxy + 必要 LuCI / Firewall4 / Wi-Fi 驱动。
- 保留新版软件包管理和主线安全维护路径，而非长期锁定 2023 年的 LEDE Commit。
- 设置 1024 KiB SquashFS block size；**压缩算法和真实效果仍需对最终镜像测量**。
- 明确选择 stock 分区，不随意更改 Bootloader、MTD 分区或 ART / calibration 数据。

## 为什么不盲删依赖库？

- `kmod-*`：多数是内核模块（硬件驱动、协议支持）。
- `lib*`：多个软件共用的运行库。
- `luci-app-*`：通常是网页管理应用，底层功能还依赖后台程序。
- `luci-theme-*`：网页主题。

建议先在 `.config` 禁用不需要的顶层功能，然后让 `make defconfig` 解析依赖，最后通过 `manifest` 排查体积。不要在已经刷入的路由器上凭名字直接删除基础包。

## 注意事项

- HomeProxy 功能依赖随版本变化；`PROVIDES:=sing-box` 不等同于已经证明所有运行时 API 兼容。
- 保留 Clash API 和 uTLS 主要是为了兼容常见 HomeProxy / VLESS Reality 场景。不是说它们被所有节点强制要求。
- 关闭 QUIC 和 gVisor 可能限制某些场景；需要时重新启用。
- 不预装大型规则集不等于无需规则；用户可选择按需下载更新，并留意 Overlay 剩余容量。
- 30 MiB 是实验性体积目标，不是安全刷机判断规则。
