#!/bin/bash

# arg: $1 = storage account
# arg: $2 = storage sas
# arg: $3 = storage container
# arg: $4 = storage import path
storage_account=$1
storage_sas=$2
storage_container=$3
storage_pathfilter=$4

cat <<EOF >/etc/systemd/system/lustremetasync.service
[Unit]
Description=Handling directory/meta data backup on Lustre filesystem for Archive 1.
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=simple
ExecStart=/sbin/changelog-reader -account "$storage_account" -container "$storage_container" -mdt LustreFS-MDT0000 -userid cl2 -archiveid 1 -pathfilter "$storage_pathfilter"
Restart=always
Environment="STORAGE_SAS=$storage_sas"

[Install]
WantedBy=multi-user.target
EOF
chmod 600 /etc/systemd/system/lustremetasync.service

systemctl daemon-reload
systemctl enable lustremetasync
systemctl start lustremetasync


