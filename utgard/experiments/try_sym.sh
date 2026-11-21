#!/system/bin/sh
# If SLOT_PHYS=0x20df7a0 is correct and KLN_ADDR=0xffffffc00111e5d0 is right,
# kallsyms_lookup_name("memcpy") must return a real kernel address.
D=/data/local/tmp
GW=$D/gaw64
KF=$D/kfunc_new
KLN=ffffffc00111e5d0
SLOT=20df7a0

echo "=== write KLN ($KLN) to slot $SLOT"
$GW $SLOT $KLN 2>&1 | tail -2

echo "=== resolve memcpy via slot"
$KF sym memcpy 2>&1 | tail -2

echo "=== resolve kallsyms_lookup_name itself"
$KF sym kallsyms_lookup_name 2>&1 | tail -2

echo "=== box alive?"
echo OK
