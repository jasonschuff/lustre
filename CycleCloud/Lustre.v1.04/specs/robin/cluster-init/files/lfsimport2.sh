#!/bin/bash

# arg: $1 = storage account
# arg: $2 = storage sas
# arg: $3 = storage container
# arg: $4 = lustre mount (default=/lustre)
# arg: $5 = storage import path
storage_account=$1
storage_sas=$2
storage_container=$3
lfs_mount=${4:-/lustre}
storage_importpath2=$5

cd $lfs_mount
export STORAGE_ACCOUNT=$storage_account
export STORAGE_SAS="$storage_sas"
/usr/sbin/azure-import -account ${storage_account} -container ${storage_container} -archiveid 2 -path $storage_importpath2

echo "--- Creating /usr/sbin/importblob2.sh script to be able to run imports manually at a later time ---"
# Create Import script to be able to run manually
cat <<EOF >/usr/sbin/importblob2.sh
#!/bin/bash

storage_account=$1
storage_sas=$2
storage_container=$3
lfs_mount=$4
storage_importpath2=$5

cd $lfs_mount
export STORAGE_ACCOUNT=$storage_account
export STORAGE_SAS="$storage_sas"
/usr/sbin/azure-import -account ${storage_account} -container ${storage_container} -archiveid 2 -path $storage_importpath2

EOF
chmod 770 /usr/sbin/importblob2.sh
echo "--- Created file /usr/sbin/importblob2.sh ---"
