#!/bin/bash

lustre_mgs="$1"
storage_account="$2"
storage_sas="$3"
storage_container="$4"
github_release="v1.0.3"
os_version="almalinux87"

lfs_mount=/amlfs

# we still need to disable selinux for the lustremetasync to work
if [ "$os_version" == "almalinux87" ]; then
    setenforce 0
    sed -i 's/SELINUX=.*$/SELINUX=disabled/g' /etc/selinux/config
fi

retry_command() {
    local cmd=$1
    local retries=${2:-5}
    local delay=${3:-10}
    local pre_retry_cmd=${4:-""}

    for ((i=0; i<retries; i++)); do
        echo "Running command: $cmd"
        $cmd

        if [ $? -eq 0 ]; then
            echo "Command succeeded!"
            return 0
        else
            if [ -n "$pre_retry_cmd" ]; then
                echo "Running pre-retry command: $pre_retry_cmd"
                $pre_retry_cmd
            fi
            echo "Command failed. Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay*2))
        fi
    done

    echo "Command failed after $retries retries."
    exit 1
}

# publisher: 'Canonical'
# offer: '0001-com-ubuntu-server-focal'
# sku: '20_04-lts-gen2'
# version: 'latest'
function install_deps_ubuntu_2204 {
    retry_command "apt update"
    retry_command "apt install -y mysql-server libmysqlclient-dev libjemalloc2"
    systemctl enable mysql
    systemctl start mysql

    retry_command "apt install -y ca-certificates curl apt-transport-https lsb-release gnupg"
    source /etc/lsb-release
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/amlfs-${DISTRIB_CODENAME}/ ${DISTRIB_CODENAME} main" | tee /etc/apt/sources.list.d/amlfs.list
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
    retry_command "apt update"
    retry_command "apt install -y amlfs-lustre-client-2.15.1-24-gbaa21ca=$(uname -r)"
}

function install_deps_almalinux_87 {
    retry_command "yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm" 5 10 "dnf clean packages"

    retry_command "dnf install -y jemalloc" 5 10 "dnf clean packages"

    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    DISTRIB_CODENAME=el8
    REPO_PATH=/etc/yum.repos.d/amlfs.repo
    echo -e "[amlfs]" > ${REPO_PATH}
    echo -e "name=Azure Lustre Packages" >> ${REPO_PATH}
    echo -e "baseurl=https://packages.microsoft.com/yumrepos/amlfs-${DISTRIB_CODENAME}" >> ${REPO_PATH}
    echo -e "enabled=1" >> ${REPO_PATH}
    echo -e "gpgcheck=1" >> ${REPO_PATH}
    echo -e "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> ${REPO_PATH}
    retry_command "dnf install -y amlfs-lustre-client-2.15.1_29_gbae0abe-$(uname -r | sed -e "s/\.$(uname -p)$//" | sed -re 's/[-_]/\./g')-1" 5 10 "dnf clean packages"
}

if [ "$os_version" == "ubuntu2004" ]; then
    install_deps_ubuntu_2204
elif [ "$os_version" == "almalinux87" ]; then
    install_deps_almalinux_87
else
    echo "Unsupported OS version: $os_version"
    exit 1
fi

###############################################
# Install dependencies
###############################################

cd /tmp
wget -O - https://github.com/edwardsp/lfsazsync/releases/download/${github_release}/${os_version}-lemur.tgz | tar zx
cd lemur
mv azure-import changelog-reader lhsmd /sbin/.
mkdir -p /usr/libexec/lhsmd
mv lhsm-plugin-az /usr/libexec/lhsmd/.
cd ..
rmdir lemur


###############################################
# lhsmd setup
###############################################
mkdir -p /var/run/lhsmd
chmod 755 /var/run/lhsmd

mkdir -p /etc/lhsmd
chmod 755 /etc/lhsmd

cat <<EOF >/etc/lhsmd/agent
# Lustre NID and filesystem name for the front end filesystem, the agent will mount this
client_device="${lustre_mgs}@tcp:/lustrefs"

# Do you want to use S3 and POSIX, in this example we use POSIX
enabled_plugins=["lhsm-plugin-az"]

## Directory to look for the plugins
plugin_dir="/usr/libexec/lhsmd"

# TBD, I used 16
handler_count=16

# TBD
snapshots {
        enabled = false
}
EOF
chmod 600 /etc/lhsmd/agent

cat <<EOF >/etc/lhsmd/lhsm-plugin-az
num_threads=16
az_storage_account="$storage_account"
az_storage_sas="?$storage_sas"
az_kv_name=""
az_kv_secret_name=""
bandwidth=0
exportprefix=""
archive "archive1" {
    id=1
    num_threads=16
    root=""
    compression="off"
    container="$storage_container"
}
EOF
chmod 600 /etc/lhsmd/lhsm-plugin-az

lhsmd_log_rotate_file="/etc/logrotate.d/lhsmd"
cat <<EOF > $lhsmd_log_rotate_file
/var/log/lhsmd.log {
    compress
    weekly
    rotate 6
    notifempty
    missingok
}
EOF
chmod 644 $lhsmd_log_rotate_file

cat <<EOF >/etc/systemd/system/lhsmd.service
[Unit]
Description=The lhsmd server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=simple
PIDFile=/run/lhsmd.pid
ExecStartPre=/bin/mkdir -p /var/run/lhsmd
ExecStart=/sbin/lhsmd -config /etc/lhsmd/agent
Restart=always
StandardOutput=append:/var/log/lhsmd.log
StandardError=inherit

[Install]
WantedBy=multi-user.target
EOF
chmod 600 /etc/systemd/system/lhsmd.service

systemctl daemon-reload
systemctl enable lhsmd
systemctl start lhsmd


