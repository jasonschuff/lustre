#!/bin/bash

fsroot="$1"
fullpath="$2"
archive_id="$3"
fid="$4"

echo "$1 $2 $3 $4" >>/var/log/lfs_hsm_remove.log

if [[ $fullpath = *${fsroot}/secondContainer/* ]]; then
    echo "Found Scratch Path, changing archive_id to 2" >> /var/log/lfs_hsm_remove.log
    archive_id=2
else
    echo "No Scratch Path found, changing archive_id to 1" >> /var/log/lfs_hsm_remove.log
    archive_id=1
fi

lfs hsm_remove --data "{\"file_id\":\"${fullpath#${fsroot}/}\"}" --archive ${archive_id} --mntpath ${fsroot} ${fid}