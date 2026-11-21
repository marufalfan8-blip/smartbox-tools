#!/bin/bash
# Mount host filesystems into the Ubuntu chroot (run from Termux via `su`).
# Set CHROOT_DIR to your chroot path (see .env.example).
set -e
ROOT="${CHROOT_DIR:-/path/to/chroot}"
MOUNT_POINT="${TERMUX_HOME:-/data/data/com.termux/files/home}"
mount -t proc proc "$ROOT/proc" 2>/dev/null || true
mount -o ro -t sysfs sys "$ROOT/sys" 2>/dev/null || true
mount --rbind /dev "$ROOT/dev" 2>/dev/null || true
mount --rbind /dev/pts "$ROOT/dev/pts" 2>/dev/null || true
mount -t tmpfs -o nodev,nosuid,size=512M tmpfs "$ROOT/tmp" 2>/dev/null || true
cp -f "$MOUNT_POINT/usr/etc/resolv.conf" "$ROOT/etc/resolv.conf" 2>/dev/null || true
echo "MOUNT_OK"
