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

echo "--- Checking cyclecloud accounts file to add users to sshd_config ---"
# Loop through text file that has users
cat $script_dir/cyclecloud_users_to_ssh.txt | while read line
do
	echo "--- User $line found to add to AllowUsers list ---"
	#echo "usermod -aG wheel $line"
	userlist="$userlist $line"
done
echo "--- Adding AllowUser $userlist to sshd_config  ---"

echo "--- Checking headnodes only file to add users to sshd_config ---"
# Loop through text file that has users
cat $script_dir/headnodes_groups_to_ssh.txt | while read line
do
	echo "--- Adding group $line to sshd_config  ---"
	printf "Match group $line \n    AllowUsers *\n"  >> /etc/ssh/sshd_config
done

echo "--- Checking allnodes file to add users to sshd_config ---"
# Loop through text file that has users
cat $script_dir/allnodes_groups_to_ssh.txt | while read line
do
	echo "--- Adding group $line to sshd_config  ---"	
	printf "Match group $line \n    AllowUsers *\n"  >> /etc/ssh/sshd_config
done

#echo "--- Modifying /etc/sudoers to allow NOPASSWD for wheel group ---"
#sudo sed --in-place 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

echo "--- add_wheel_group.sh complete! ---"