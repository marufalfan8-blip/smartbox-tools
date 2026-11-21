#!/bin/bash
# SPDX-License-Identifier: MIT
# Mount host filesystems into the Ubuntu chroot (run from Termux via `su`).
# Set CHROOT_DIR to your chroot path (see .env.example).
set -e
ROOT="${CHROOT_DIR:-/path/to/chroot}"
TERMUX_PREFIX="${TERMUX_PREFIX:-/data/data/com.termux/files/usr}"

# Fail clearly instead of printing MOUNT_OK on a non-existent chroot.
if [ ! -d "$ROOT" ]; then
  echo "ERROR: chroot directory '$ROOT' does not exist. Set CHROOT_DIR." >&2
  exit 1
fi

mount -t proc proc "$ROOT/proc" 2>/dev/null || true
mount -o ro -t sysfs sys "$ROOT/sys" 2>/dev/null || true
mount --rbind /dev "$ROOT/dev" 2>/dev/null || true
mount --rbind /dev/pts "$ROOT/dev/pts" 2>/dev/null || true
mount -t tmpfs -o nodev,nosuid,size=512M tmpfs "$ROOT/tmp" 2>/dev/null || true
# Copy Termux's resolver config. Warn instead of failing the whole mount
# when it is missing (DNS inside the chroot will not work without it).
if [ -f "$TERMUX_PREFIX/etc/resolv.conf" ]; then
  cp -f "$TERMUX_PREFIX/etc/resolv.conf" "$ROOT/etc/resolv.conf"
else
  echo "WARN: $TERMUX_PREFIX/etc/resolv.conf not found; DNS inside the chroot may not work" >&2
fi
echo "MOUNT_OK"
