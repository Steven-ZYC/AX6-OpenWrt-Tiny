# Redmi AX6 刷机说明

适用于 **Redmi AX6 原厂 NAND 分区**（`redmi_ax6-stock`）。本流程使用 Release 中的 **Factory UBI**，不使用 `sysupgrade.bin`。

## 双系统分区

| 槽位 | 分区 | `flag_boot_rootfs` |
|---|---|---|
| Slot 0 | `/dev/mtd12`（`rootfs`） | `0` |
| Slot 1 | `/dev/mtd13`（`rootfs_1`） | `1` |

AX6 有两个系统槽位。启动时只使用其中一个；可将新固件写入另一个槽位，保留旧系统以便切回。

以下是**已实机验证**的路径：从 Slot 0 的 LEDE 启动，将 Tiny Plus 写入 Slot 1。

## 刷入 Slot 1

**1. 确认当前分区**

通过 SSH 执行：

```sh
cat /proc/mtd
fw_printenv flag_boot_rootfs flag_last_success
```

确认 `mtd12=rootfs`、`mtd13=rootfs_1` 且 `flag_boot_rootfs=0`。**不符则不要执行下方写入命令。**

**2. 上传并写入镜像**

从 [Releases](https://github.com/Steven-ZYC/AX6-OpenWrt-Tiny/releases) 下载对应的 `AX6-tiny-plus-<版本>-factory.ubi`，核对 SHA256 后上传至路由器的 `/tmp/AX6-tiny-plus-factory.ubi`。

```sh
sha256sum /tmp/AX6-tiny-plus-factory.ubi
ubiformat /dev/mtd13 -y -f /tmp/AX6-tiny-plus-factory.ubi
```

**3. 写入成功后切换启动槽位**

```sh
fw_setenv flag_last_success 1
fw_setenv flag_boot_rootfs 1
fw_printenv flag_boot_rootfs flag_last_success
sync
reboot
```

新系统的默认管理地址为 `192.168.123.1`（适用于当前 RC2 首次启动配置）。

## 切回 Slot 0

若新系统仍可通过 SSH 操作：

```sh
fw_setenv flag_try_sys1_failed 0
fw_setenv flag_ota_reboot 0
fw_setenv flag_last_success 0
fw_setenv flag_boot_rootfs 0
sync
reboot
```

旧系统仍保留在 `mtd12`。若新系统无法启动且无法连接 SSH，则需使用设备的引导恢复方式；**双分区不代表一定会自动回退**。
