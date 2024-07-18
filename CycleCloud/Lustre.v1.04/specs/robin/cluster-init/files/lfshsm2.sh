#!/bin/bash

# arg: $1 = storage account
# arg: $2 = storage sas
# arg: $3 = storage container

storage_account=$1
storage_sas=$2
storage_container=$3

cat <<EOF >>/etc/lhsmd/lhsm-plugin-az

##
archive  "az-blob2" {
    id = 2                           # Must be unique to this endpoint
    az_storage_account = "$storage_account"
	az_storage_sas = "$storage_sas"
	container = "$storage_container" # Container used for this archive
	root=""
    compression = "off"
    num_threads = 8
}
EOF

systemctl restart lhsmd
