#!/bin/bash

# arg: $1 = lfsmaster
# arg: $2 = device (e.g. L=/dev/sdb Lv2=/dev/nvme0n1)
master=$1
devices=$2
index=$(($PSSH_NODENUM))

echo "--- OSS index number is: $index --- "
echo "--- Device list is: $devices --- "
ndevices=$(wc -w <<<$devices)

for device in $devices; do

    mkfs.lustre \
        --fsname=LustreFS \
        --backfstype=ldiskfs \
        --reformat \
        --ost \
        --mgsnode=$master \
        --index=$index \
        --mountfsoptions="errors=remount-ro" \
        $device

    mkdir /mnt/oss${index}
    echo "$device /mnt/oss${index} lustre noatime,nodiratime,nobarrier 0 2" >> /etc/fstab

    index=$(( $index + 1 ))

done

echo "--- Mounting disks to their oss folder structure using fstab --- "

mount -a

echo "--- Mounting disks completed --- "

