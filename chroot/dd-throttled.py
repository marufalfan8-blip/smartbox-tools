#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Write an image to SD at 2 MB/s (avoids heat and voltage drops).

Usage:
    DD_SRC=img DD_DST=/dev/block/sdX CONFIRM=yes python3 dd-throttled.py

DD_DST must be a block device, and CONFIRM=yes is required to avoid accidents.
"""
import fcntl
import os
import stat
import struct
import sys
import time

SRC = os.environ.get("DD_SRC", "/path/to/sdcard.img")
DST = os.environ.get("DD_DST", "/proc/1/root/dev/block/sdX")
RATE = 2 * 1024 * 1024          # 2 MiB/detik
CHUNK = 1024 * 1024             # tulis 1 MiB per putaran
BLKGETSIZE64 = 0x80081272       # Linux ioctl: block device size in bytes


def die(message):
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(2)


if os.environ.get("CONFIRM") != "yes":
    die("refusing to write: set CONFIRM=yes after double-checking DD_DST")

if not os.path.isfile(SRC):
    die(f"source image not found: {SRC}")

try:
    dst_mode = os.stat(DST).st_mode
except OSError as exc:
    die(f"cannot stat DD_DST ({DST}): {exc}")
if not stat.S_ISBLK(dst_mode):
    die(f"DD_DST is not a block device: {DST}")

total = os.path.getsize(SRC)
if total == 0:
    die(f"source image is empty: {SRC}")

src = open(SRC, "rb")
dst = open(DST, "r+b", buffering=0)

# st_size is usually 0 for block devices; ask the kernel for the real capacity.
try:
    dev_size = struct.unpack(
        "Q", fcntl.ioctl(dst.fileno(), BLKGETSIZE64, b"\0" * 8))[0]
except OSError:
    dev_size = os.fstat(dst.fileno()).st_size
if dev_size and total > dev_size:
    die(f"image ({total} bytes) is larger than {DST} ({dev_size} bytes)")

print(f"Writing {SRC} -> {DST} ({total} bytes) at 2 MiB/s", flush=True)
start = time.monotonic()
written = 0

while True:
    data = src.read(CHUNK)
    if not data:
        break
    dst.write(data)
    os.fsync(dst.fileno())
    written += len(data)
    target = written / RATE
    elapsed = time.monotonic() - start
    if elapsed < target:
        time.sleep(target - elapsed)
    if written % (64 * 1024 * 1024) < CHUNK:
        print(f"{written}/{total} ({written / total * 100:.1f}%)", flush=True)

dst.flush()
os.fsync(dst.fileno())
src.close()
dst.close()
print(f"DONE {written} bytes", flush=True)
