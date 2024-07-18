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

echo "--- Checking file to add users to wheel group ---"
# Loop through text file that has users
cat $script_dir/users_to_wheel.txt | while read line
do
	echo "--- Adding user $line to wheel group ---"
	#echo "usermod -aG wheel $line"
	usermod -aG wheel $line
done

#echo "--- Modifying /etc/sudoers to allow NOPASSWD for wheel group ---"
#sudo sed --in-place 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

echo "--- add_wheel_group.sh complete! ---"