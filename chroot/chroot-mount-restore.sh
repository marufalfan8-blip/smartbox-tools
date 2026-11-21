#!/bin/bash
# Restore host access (/proc /sys /tmp) after reboot, for chroot sessions.
# Auto-sourced from ~/.bashrc; can also be run manually at any time.
# Never bind /proc/1/root/* (that would overlay its own source).
set -u

# /proc: check it is actually populated, not just a mountpoint
if [ ! -d /proc/1 ] || [ ! -r /proc/1/cmdline ]; then
  mount -t proc proc /proc 2>/dev/null || true
fi

# /sys
if [ ! -d /sys/class ]; then
  mount -o ro -t sysfs sys /sys 2>/dev/null || true
fi

# /tmp tmpfs
if ! grep -q ' /tmp ' /proc/self/mounts 2>/dev/null; then
  mount -t tmpfs -o nodev,nosuid,size=512M tmpfs /tmp 2>/dev/null || true
fi

# device nodes are read directly from /proc/1/root/dev/block (do not bind)
[ -d /proc/1/root ] || exit 1
exit 0
