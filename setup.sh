#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# One-time setup: Termux mount helper + Python dependency check.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

INSTALL=0
[ "${1:-}" = "--install" ] && INSTALL=1

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found. Install it in the chroot/Termux first." >&2
  exit 1
fi

if [ "$INSTALL" -eq 1 ]; then
  python3 -m pip install -r requirements.txt
fi

if python3 -c 'import usb.core' >/dev/null 2>&1; then
  echo "OK    pyusb"
else
  echo "MISS  pyusb (run: ./setup.sh --install)" >&2
fi
if python3 -c 'import pyamlboot' >/dev/null 2>&1; then
  echo "OK    pyamlboot (pip package, used by pyamlboot/ scripts)"
else
  echo "MISS  pyamlboot (optional; only for pyamlboot/ scripts)" >&2
fi

if [ -n "${CHROOT_DIR:-}" ] && [ ! -d "$CHROOT_DIR" ]; then
  echo "WARN  CHROOT_DIR '$CHROOT_DIR' does not exist — set it in .env" >&2
fi

# Only copy when TERMUX_HOME is set explicitly. Never write into the Termux
# home from the chroot via a host path — that would make the file root-owned.
termux_home="${TERMUX_HOME:-}"
if [ -n "$termux_home" ] && [ -d "$termux_home" ]; then
  cp -f termux/chroot-mount.sh "$termux_home/chroot-mount.sh"
  chmod 700 "$termux_home/chroot-mount.sh"
  echo "OK    copied termux/chroot-mount.sh -> $termux_home/chroot-mount.sh"
  echo "      (run this from Termux so the file stays owned by the Termux user)"
else
  echo "TODO  copy termux/chroot-mount.sh to your Termux home (\$TERMUX_HOME)"
fi

echo "Setup done. Next: source .env, then ./smartbox check"
