#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Write an image to SD at 2 MB/s (avoids heat and voltage drops)."""
import os, time, sys

SRC = os.environ.get("DD_SRC", "/path/to/sdcard.img")
DST = os.environ.get("DD_DST", "/proc/1/root/dev/block/sdX")
RATE = 2 * 1024 * 1024          # 2 MiB/detik
CHUNK = 1024 * 1024             # tulis 1 MiB per putaran

total = os.path.getsize(SRC)
src = open(SRC, "rb")
dst = open(DST, "r+b", buffering=0)
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
        print(f"{written}/{total} ({written/total*100:.1f}%)", flush=True)

dst.flush()
os.fsync(dst.fileno())
src.close()
dst.close()
print(f"DONE {written} bytes", flush=True)
