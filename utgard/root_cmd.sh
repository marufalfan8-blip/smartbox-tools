#!/system/bin/sh
# INTENDED FOR THE ANDROID DEVICE (not the chroot). Runs as root via roothelper.sh.
# Example root payload run by the Utgard chain (see run.sh / roothelper.sh).
# Replace with your own command. Everything writes to /data/local/tmp.
echo "root payload ran at $(date)" > /data/local/tmp/root_payload.log
echo "uid: $(id)" >> /data/local/tmp/root_payload.log
