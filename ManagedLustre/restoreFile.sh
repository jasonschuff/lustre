#!/bin/bash

# Read command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --blob-path) item_to_restore="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Validate blob_path
if [[ -z "$item_to_restore" ]]; then
    echo "Usage: $0 --blob-path <item_to_restore>  Use / for root"
    exit 1
fi

# Read values from configuration files
storage_sas=$(grep 'STORAGE_SAS=' /etc/azurestorage.env | cut -d '=' -f 2- | sed 's/\"//g')
storage_account=$(grep 'az_storage_account=' /etc/lhsmd/lhsm-plugin-az | awk -F '=' '{print $2}' | sed 's/\"//g')
storage_container=$(grep 'container=' /etc/lhsmd/lhsm-plugin-az | awk -F '=' '{print $2}' | sed 's/\"//g')

# Get the path where Lustre is mounted
mount_root=$(grep -- '-mountroot' /lib/systemd/system/lustremetasync.service | awk '{for(i=1;i<=NF;i++) if ($i == "-mountroot") print $(i+1)}' | sed 's/\"//g')

if [[ "$item_to_restore" == "/" ]]; then
    restore_location="$mount_root"
    azure_import_cmd="azure-import -account $storage_account -container $storage_container -archiveid 1"
else
    #item_to_restore=$(basename "$item_to_restore")
    restore_location="${mount_root}/${item_to_restore}"
    azure_import_cmd="azure-import -account $storage_account -container $storage_container -archiveid 1 -path $item_to_restore"
fi

# Remove leading '/' from item_to_restore if it exists as the path doesn't require it
[[ $item_to_restore == /* ]] && item_to_restore="${item_to_restore:1}"



# Validate that required values are not empty
if [[ -z "$storage_sas" || -z "$storage_account" || -z "$storage_container" ]]; then
    echo "One or more required configurations are missing."
    exit 1
fi

# Change directory to the mount_root before importing files
cd "$mount_root" || { echo "Failed to change directory to $mount_root"; exit 1; }

# Logic to restore the file using azure-import
export STORAGE_ACCOUNT=$storage_account
export STORAGE_SAS="$storage_sas"
#azure-import -account ${storage_account} -container ${storage_container} -archiveid 1 -path $item_to_restore
eval $azure_import_cmd

# Verify that the item_to_restore now exists under the restore_location
echo "Checking if $restore_location exists"
if [[ -f "$restore_location" ]]; then
    echo "File $item_to_restore exists under $restore_location after import. Restored Successfully."
elif [[ -d "$restore_location" ]]; then
    echo "Directory $item_to_restore exists under $restore_location after import. Restored Successfully."
else
    echo "Neither a file nor a directory named $item_to_restore exists under $restore_location after import."
    exit 1
fi