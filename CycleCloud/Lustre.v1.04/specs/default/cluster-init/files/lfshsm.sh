#!/bin/bash

# arg: $1 = lfsserver
# arg: $2 = storage account
# arg: $3 = storage sas
# arg: $4 = storage container
# arg: $5 = lustre version (default 2.12)
master=$1
storage_account=$2
storage_sas=$3
storage_container=$4
lustre_version=${5-2.12}
lemur_version=${6-2.1.3}

function isinstalled {
  if yum list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}

if isinstalled "lemur-azure-hsm-agent"; then
	echo "--- Lemur Azure HSM Agent detected as already installed, checking the version ---"
	PACKAGE_VERSION=$(rpm -q --queryformat '%{VERSION}' lemur-azure-hsm-agent)

	if [ "$PACKAGE_VERSION" = "$lemur_version" ]; then
		jetpack log "Lemur Azure HSM Agent $lemur_version detected as installed on node ${ccnodename}"
		echo "--- Lemur Azure HSM Agent $lemur_version detected as already installed, skipping install ---"
	else
		jetpack log "Lemur Azure HSM Agent $PACKAGE_VERSION detected, needs upgraded to $lemur_version"
		echo "--- Lemur Azure HSM Agent $PACKAGE_VERSION detected, needs upgraded to $lemur_version ---"
		yum -y upgrade \
		https://github.com/edwardsp/lemur/releases/download/${lemur_version}/lemur-azure-hsm-agent-${lemur_version}-lustre_${lustre_version}.x86_64.rpm \
		https://github.com/edwardsp/lemur/releases/download/${lemur_version}/lemur-azure-data-movers-${lemur_version}-lustre_${lustre_version}.x86_64.rpm
		
		echo "--- Lemur Azure HSM Agent $lemur_version ugpgraded ---"
	fi
else
	echo "--- Lemur Azure HSM Agent $lemur_version installing ---"
	yum -y install \
		https://github.com/edwardsp/lemur/releases/download/${lemur_version}/lemur-azure-hsm-agent-${lemur_version}-lustre_${lustre_version}.x86_64.rpm \
		https://github.com/edwardsp/lemur/releases/download/${lemur_version}/lemur-azure-data-movers-${lemur_version}-lustre_${lustre_version}.x86_64.rpm

	echo "--- Lemur Azure HSM Agent $lemur_version installed ---"
	
	weak-modules --add-kernel --no-initramfs
fi

mkdir -p /var/run/lhsmd
chmod 755 /var/run/lhsmd

mkdir -p /etc/lhsmd
chmod 755 /etc/lhsmd

cat <<EOF >/etc/lhsmd/agent
# Lustre NID and filesystem name for the front end filesystem, the agent will mount this
client_device="${master}@tcp:/LustreFS"

# Do you want to use S3 and POSIX, in this example we use az plugin
enabled_plugins=["lhsm-plugin-az"]

## Directory to look for the plugins
plugin_dir="/usr/libexec/lhsmd"

# TBD, I used 16
handler_count=4

# TBD
snapshots {
        enabled = false
}
EOF
chmod 600 /etc/lhsmd/agent

cat <<EOF >/etc/lhsmd/lhsm-plugin-az

az_kv_name=""
az_kv_secret_name=""

num_threads = 16

#
# One or more archive definition is required.
#
archive  "az-blob" {
    id = 1                           # Must be unique to this endpoint
    az_storage_account = "$storage_account"
	az_storage_sas = "$storage_sas"
	container = "$storage_container" # Container used for this archive
	root=""
    compression = "off"
    num_threads = 8
}
EOF
chmod 600 /etc/lhsmd/lhsm-plugin-az

cat <<EOF >/etc/systemd/system/lhsmd.service
[Unit]
Description=Lustre HSM Agent
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=simple
PIDFile=/run/lhsmd.pid
ExecStartPre=/bin/mkdir -p /var/run/lhsmd
ExecStart=/usr/sbin/lhsmd -config /etc/lhsmd/agent
User=root
RuntimeDirectory=lhsmd
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
chmod 600 /etc/systemd/system/lhsmd.service

systemctl daemon-reload
systemctl enable lhsmd
systemctl start lhsmd
