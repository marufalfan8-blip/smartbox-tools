#!/bin/bash
# SPDX-License-Identifier: MIT
# Restore host access (/proc /sys /tmp) after reboot, for chroot sessions.
# Auto-sourced from ~/.bashrc; can also be run manually at any time.
# Never bind /proc/1/root/* (that would overlay its own source).
# No `set -u` here: this file is sourced from .bashrc/.zshrc and changing the
# parent shell's options would cause surprises.

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

# Device nodes are read directly from /proc/1/root/dev/block (do not bind).
# Do NOT call `exit` at the end: this file is sourced from .bashrc/.zshrc and
# an `exit` would close the user's interactive shell. Reaching EOF returns 0.
