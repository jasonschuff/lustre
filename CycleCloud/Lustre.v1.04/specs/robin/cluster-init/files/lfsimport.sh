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
storage_importpath=$5

cd $lfs_mount
export STORAGE_ACCOUNT=$storage_account
export STORAGE_SAS="$storage_sas"

# Check if import path is blank, if so don't use the -path option during import
if [ $storage_importpath = ""]; then
	/usr/sbin/azure-import -account ${storage_account} -container ${storage_container} -archiveid 1 -parallel 32 > /var/log/lustreimport.log 2>&1 & 
	echo "--- Creating /usr/sbin/importblob1.sh script to be able to run imports manually at a later time ---"
# Create Import script to be able to run manually
cat <<EOF >/usr/sbin/importblob1.sh
#!/bin/bash

storage_account=$1
storage_sas=$2
storage_container=$3
lfs_mount=$4
storage_importpath=$5

cd $lfs_mount
export STORAGE_ACCOUNT=$storage_account
export STORAGE_SAS="$storage_sas"
/usr/sbin/azure-import -account ${storage_account} -container ${storage_container} -archiveid 1 -parallel 32 

EOF
chmod 770 /usr/sbin/importblob1.sh
echo "--- Created file /usr/sbin/importblob1.sh ---"

# Use -path option during import to only import the specified path	
else
	/usr/sbin/azure-import -account ${storage_account} -container ${storage_container} -archiveid 1 -parallel 32 -path $storage_importpath

echo "--- Creating /usr/sbin/importblob1.sh script to be able to run imports manually at a later time ---"
# Create Import script to be able to run manually
cat <<EOF >/usr/sbin/importblob1.sh
#!/bin/bash

storage_account=$1
storage_sas=$2
storage_container=$3
lfs_mount=$4
storage_importpath=$5

cd $lfs_mount
export STORAGE_ACCOUNT=$storage_account
export STORAGE_SAS="$storage_sas"
/usr/sbin/azure-import -account ${storage_account} -container ${storage_container} -archiveid 1 -parallel 32 -path $storage_importpath

EOF
chmod 770 /usr/sbin/importblob1.sh
echo "--- Created file /usr/sbin/importblob1.sh ---"
	

fi



