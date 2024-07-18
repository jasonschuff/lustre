#!/bin/bash

# set up cycle vars
yum -y install epel-release
yum -y install jq
cluster_name=$(jetpack config cyclecloud.cluster.name)
ccuser=$(jetpack config cyclecloud.config.username)
ccpass=$(jetpack config cyclecloud.config.password)
ccurl=$(jetpack config cyclecloud.config.web_server)
ccnodename=$(jetpack config cyclecloud.node.name)

lustre_name=$(jetpack config lustre.cluster_name)
lustre_version=$(jetpack config lustre.version)
mount_point=$(jetpack config lustre.mount_point)


function isinstalled {
  if yum list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}

declare -i x=0

jetpack log "Waiting for MDS node to start before installing lustre client on $ccnodename"
echo "--- Waiting for the mds to start before installing lustre client ---"
while true; do
        #echo mds_state="$(curl -s -k --user $ccuser:$ccpass "$ccurl/clusters/$lustre_name/nodes")"
        mds_state="$(curl -s -k --user $ccuser:$ccpass "$ccurl/clusters/$lustre_name/nodes" | jq -r '.nodes[] | select(.Template=="mds") | .State')"
        if [ "$mds_state" = "Started" ]; then
                jetpack log "Mounting the lustre client on ${ccnodename} to connect to $lustre_name"
				echo "--- MDS detected as started so moving on ---"
                break
        elif  [ $x -gt 60 ]; then # Wait up to 30 minutes
                jetpack log "Lustre client mounting on ${ccnodename} timed out waiting for MDS node to start" -level error --priority low
                echo "--- Timed out waiting for MDS node to be detected as running ---"
				exit 1
                break
        fi
        #echo $x
        ((x++))
        sleep 30
done

mds_ip=$(curl -s -k --user $ccuser:$ccpass "$ccurl/clusters/$lustre_name/nodes"| jq -r '.nodes[] | select(.Template=="mds") | .IpAddress')

script_dir=$CYCLECLOUD_SPEC_PATH/files
chmod +x $script_dir/*.sh

if isinstalled "lustre-client"; then
	jetpack log "Lustre client already installed, skipping install"
	echo "--- Lustre client already installed, skipping install ---"
else
	jetpack log "Installing Lustre client"
	echo "--- Installing Lustre Client ---"
	# SETUP LUSTRE YUM REPO
	$script_dir/lfsrepo.sh $lustre_version
	
	yum install -y kmod-lustre-client lustre-client
	weak-modules --add-kernel $(uname -r)
fi	

$script_dir/lfsclient.sh $mds_ip $mount_point

echo "--- setup_lustre_client.sh script completed ---"