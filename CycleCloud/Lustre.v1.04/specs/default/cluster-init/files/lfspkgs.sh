#!/bin/bash
yum -y install lustre kmod-lustre-osd-ldiskfs lustre-osd-ldiskfs-mount lustre-resource-agents e2fsprogs lustre-tests epel-release

echo "--- Lustre package installations complete. ---"

sed -i 's/ResourceDisk\.Format=y/ResourceDisk.Format=n/g' /etc/waagent.conf

systemctl restart waagent

weak-modules --add-kernel --no-initramfs

umount /mnt/resource
