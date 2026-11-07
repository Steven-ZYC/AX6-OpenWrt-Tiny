#!/usr/bin/env python3
"""Fail closed on AX6 stock-layout image size / UBI / sysupgrade structure.

Policy: 28 MiB maximum factory UBI (the usual stock rootfs/rootfs_1 MTD is
0x023c0000 = 35.75 MiB). Reserves 7.75 MiB nominal headroom for UBI,
bad blocks and variations. This is a CI guard, NOT proof of flash safety.
"""
from __future__ import annotations

import pathlib
import struct
import sys
import tarfile

MIB = 1024 * 1024
STOCK_MTD_BYTES = 0x023C0000
MAX_FACTORY_BYTES = 28 * MIB
PEB_BYTES = 128 * 1024


def check(sysupgrade: pathlib.Path, factory: pathlib.Path) -> str:
    if not sysupgrade.is_file() or not factory.is_file():
        raise ValueError("both factory.ubi and sysupgrade.bin must exist")
    if "redmi_ax6-stock" not in sysupgrade.name or not sysupgrade.name.endswith("-sysupgrade.bin"):
        raise ValueError("unexpected sysupgrade filename; expected AX6 stock layout")
    if "redmi_ax6-stock" not in factory.name or not factory.name.endswith("-factory.ubi"):
        raise ValueError("unexpected factory UBI filename; expected AX6 stock layout")
    factory_bytes = factory.stat().st_size
    upgrade_bytes = sysupgrade.stat().st_size
    if factory_bytes > MAX_FACTORY_BYTES:
        raise ValueError(f"factory UBI {factory_bytes} bytes exceeds the stock-layout hard cap {MAX_FACTORY_BYTES} bytes")
    if not factory_bytes or factory_bytes % PEB_BYTES:
        raise ValueError("factory UBI is not an exact multiple of 128 KiB erase blocks")
    if upgrade_bytes > MAX_FACTORY_BYTES:
        raise ValueError("sysupgrade archive exceeds 28 MiB conservative policy cap")

    volume_ids: set[int] = set()
    with factory.open("rb") as handle:
        for index in range(factory_bytes // PEB_BYTES):
            block = handle.read(PEB_BYTES)
            if block[:4] != b"UBI#":
                raise ValueError(f"factory UBI missing EC header at erase block {index}")
            vid_offset = struct.unpack_from(">I", block, 16)[0]
            if vid_offset + 12 > PEB_BYTES or block[vid_offset:vid_offset + 4] != b"UBI!":
                raise ValueError(f"factory UBI has invalid VID header at erase block {index}")
            volume_ids.add(struct.unpack_from(">I", block, vid_offset + 8)[0])
    if not {0, 1}.issubset(volume_ids):
        raise ValueError("expected both kernel (volume 0) and rootfs (volume 1) in factory UBI")

    try:
        with tarfile.open(sysupgrade, "r:*") as archive:
            entries = {pathlib.PurePosixPath(m.name).name: m for m in archive.getmembers() if m.isfile()}
            if "kernel" not in entries or "root" not in entries or "CONTROL" not in entries:
                raise ValueError("sysupgrade must contain kernel, root and CONTROL entries")
            kernel_bytes = entries["kernel"].size
            root_bytes = entries["root"].size
            if not (0 < kernel_bytes < MAX_FACTORY_BYTES and 0 < root_bytes < MAX_FACTORY_BYTES):
                raise ValueError("empty or unusually oversized kernel/rootfs in sysupgrade")
    except (tarfile.TarError, OSError) as exc:
        raise ValueError(f"invalid sysupgrade tar archive: {exc}") from exc

    return "\n".join((
        f"- **HARD SIZE GATE: PASS** (28 MiB maximum factory UBI)",
        f"- Stock reference MTD partition: {STOCK_MTD_BYTES / MIB:.2f} MiB; reserved nominal headroom: {(STOCK_MTD_BYTES - MAX_FACTORY_BYTES) / MIB:.2f} MiB",
        f"- Factory UBI: **{factory_bytes / MIB:.2f} MiB** ({factory_bytes} bytes; {factory_bytes // PEB_BYTES} × 128 KiB erase blocks)",
        f"- Sysupgrade image: **{upgrade_bytes / MIB:.2f} MiB** ({upgrade_bytes} bytes)",
        f"- Sysupgrade kernel: {kernel_bytes / MIB:.2f} MiB; SquashFS root: {root_bytes / MIB:.2f} MiB",
        "- **NOT a flash-safety certification**: verify /proc/mtd, active slot, UBI bad blocks, bootloader and upgrade method on the actual AX6.",
    ))


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3:
            raise ValueError("usage: check-stock-image.py PATH_TO_SYSUPGRADE_BIN PATH_TO_FACTORY_UBI")
        print(check(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])))
    except ValueError as exc:
        print(f"ERROR: AX6 stock-layout image rejected: {exc}", file=sys.stderr)
        sys.exit(1)
