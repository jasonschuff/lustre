#!/bin/bash

# set up cycle vars
cluster_name=$(jetpack config cyclecloud.cluster.name)
ccuser=$(jetpack config cyclecloud.config.username)
ccpass=$(jetpack config cyclecloud.config.password)
ccurl=$(jetpack config cyclecloud.config.web_server)
mount_point=$(jetpack config lustre.mount_point)
ccnodename=$(jetpack config cyclecloud.node.name)

script_dir=$CYCLECLOUD_SPEC_PATH/files
chmod +x $script_dir/*.sh


jetpack log "Setting up ldap configuration on ${ccnodename}"
# Setup OpenLDAP Authorization and Configuration
$script_dir/authconfig.sh 

# Setup symbolic links to home folders
$script_dir/syslinkprofile.sh $mount_point

echo "--- setup_ldap.sh complete! ---"