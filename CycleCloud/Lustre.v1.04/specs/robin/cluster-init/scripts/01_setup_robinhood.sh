#!/bin/bash

# vars used in script
yum -y install epel-release
yum -y install jq

# set up cycle parameters
cluster_name=$(jetpack config cyclecloud.cluster.name)
ccuser=$(jetpack config cyclecloud.config.username)
ccpass=$(jetpack config cyclecloud.config.password)
ccurl=$(jetpack config cyclecloud.config.web_server)
cctype=$(jetpack config cyclecloud.node.template)
ccnodename=$(jetpack config cyclecloud.node.name)

# lustre parameters
lustre_version=$(jetpack config lustre.version)
lustremain_version=${lustre_version:0:4}
mount_point=$(jetpack config lustre.mount_point)
lustre_name=$(jetpack config lustre.cluster_name)
execute_post_script=$(jetpack config lustre.execute_post_script)
post_script_path=$(jetpack config lustre.post_script_path)

# Get HSM parameters from front end
use_hsm=$(jetpack config lustre.use_hsm)
storage_account=$(jetpack config lustre.storage_account)
storage_sas="$(jetpack config lustre.storage_sas)"
storage_container=$(jetpack config lustre.storage_container)
storage_importpath=$(jetpack config lustre.storage_importpath)

# Get second HSM parameters from front end
use_hsm2=$(jetpack config lustre.use_hsm2)
storage_account2=$(jetpack config lustre.storage_account2)
storage_sas2="$(jetpack config lustre.storage_sas2)"
storage_container2=$(jetpack config lustre.storage_container2)
storage_importpath2=$(jetpack config lustre.storage_importpath2)

# Get robinhood parameters from front end
#db_password=$(jetpack config robinhood.db_password)
use_policy_file=$(jetpack config robinhood.use_policy_file)
policy_file=$(jetpack config robinhood.policy_file)


function isinstalled {
  if yum list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}

script_dir=$CYCLECLOUD_SPEC_PATH/files
chmod +x $script_dir/*.sh

if isinstalled "robinhood"; then
	jetpack log "Robinhood Packages detected as installed on node ${ccnodename}"
	echo "--- Robinhood package detected as already installed, skipping install ---"
else
	echo "--- Installing Robinhood packages ---"

	jetpack log "Installing Robinhood packages"
	# INSTALL Robinhood PACKAGES
	$script_dir/rhpkgs.sh $lustremain_version
fi

if isinstalled "robinhood" != true; then
	jetpack log "Robinhood Packages failed to install on node ${ccnodename}" --level error
	echo "--- Robinhood package failed to install, exiting script ---"
	exit 1
fi

jetpack log "Configuring the robinhood database and policy file"
# Configure Robinhood DB and policy file
echo "--- Configuring Robinhood  ---"
$script_dir/rbconfig.sh

echo "--- Copying lfs_hsm_remove.sh custom script local"
sudo cp $script_dir/lfs_hsm_remove.sh /usr/sbin/lfs_hsm_remove.sh
chmod +x /usr/sbin/lfs_hsm_remove.sh

echo "--- Copying rb-def-policies.inc local"
sudo cp $script_dir/rb-def-policies.inc /etc/robinhood.d/

# Run initial scan of the file systemctl
#jetpack log "Running initial file scan on Robinhood"
#echo "--- Running initial Robinhood scan ---"
#sudo robinhood --scan --once

# If Use HSM was checked, run script to set up HSM service and plugins
if [ "${use_hsm,,}" = "true" ]; then

	# Initialize the variable to keep track of whether all oss-node states have been checked
	all_oss_nodes_started="false"
		
	jetpack log "Checking that all OSS nodes have started before importing data"
	echo "Checking that all OSS nodes have started before importing data"
	
	# Loop through the array and check each oss node state
	while [ "$all_oss_nodes_started" == "false" ]
	do
	  # Assume that all values have started
	  all_oss_nodes_started="true"
	  
	  # Retrieve OSS node states
	  echo "Retrieving node states"
	  oss_node_states="$(curl -s -k --user $ccuser:$ccpass "$ccurl/clusters/$cluster_name/nodes" | jq -r '.nodes[] | select(.Template=="oss") | .State')"
	  
	  # Loop through the array and check each value for a not started
	  
	  for node_state in ${oss_node_states}
	  do
		echo "Node_state is: $node_state"
		if [ "$node_state" != "Started" ]
		then
		  # If any oss node is not started, set the variable to false and break out of the loop
		  echo "Node state reported as not started. "
		  all_oss_nodes_started="false"
		  sleep 30
		  break
		else
		  echo "All OSS nodes have started"
		fi
	  done
	done

	# If we get here, all values are "Started"
	echo "All oss-nodes are 'Started', moving on to import"
	jetpack log "All OSS nodes have been started"

	jetpack log "Setting up Lustre/HSM Metadata Monitoring Service for 1st blob storage on node $ccnodename"
	# Create Metadata service using changelog_reader 
	echo "   -- Executing lustremetadata.sh to monitor metadata from 1st blob storage, storage_account:$storage_account, storage_container:$storage_container, storage_importpath:$storage_importpath  --"
	$script_dir/lustremetadata.sh $storage_account "$storage_sas" $storage_container $storage_importpath
	
	jetpack log "Importing data from 1st blob storage on node $ccnodename"
	# Import data from 1st blob storage setup within HSM
	echo "   -- Executing lfsimport.sh to import data from 1st blob storage, storage_account:$storage_account, storage_container:$storage_container, storage_importpath:$storage_importpath  --"
	$script_dir/lfsimport.sh $storage_account "$storage_sas" $storage_container /lustre $storage_importpath
	

	# If Use 2nd HSM was checked, run script to add second archive section to lhsm-plugin-az plugin
	if [ "${use_hsm2,,}" = "true" ]; then
	
		jetpack log "Setting up Lustre/HSM Metadata Monitoring Service for 2nd blob storage on node $ccnodename"
		# Create Metadata service using changelog_reader 
		echo "   -- Executing lustremetadata.sh to monitor metadata from 2nd blob storage, storage_account:$storage_account2, storage_container:$storage_container2, storage_importpath:$storage_importpath2  --"
		$script_dir/lustremetadata2.sh $storage_account2 "$storage_sas2" $storage_container2 $storage_importpath2
		
		jetpack log "Importing data from 2nd blob storage on node $ccnodename"
		# Import data from 2nd blob storage setup within HSM
		echo "   -- Executing lfsimport2.sh to import data from 2nd blob storage, storage_account:$storage_account2, storage_container:$storage_container2, storage_importpath:$storage_importpath2  --"
		$script_dir/lfsimport2.sh $storage_account2 "$storage_sas2" $storage_container2 /lustre $storage_importpath2
	
	fi

fi

# Call Monitor script and detach process
echo "--- Calling the lustre update monitor script ---"
$script_dir/monitorLustreImport.sh > /var/log/monitorImport.log 2>&1 &

# Execute Post-Script if enabled
if [ "${execute_post_script,,}" = "true" ]; then
		
	jetpack log "Executing Post-Script $post_script_path"
	echo "--- Executing post-script $post_script_path ---"
	chmod +x $post_script_path
	$post_script_path
	echo "--- Post-Script completed ---"
fi

# Run initial scan of the file systemctl
#jetpack log "Running initial file scan on Robinhood"
#echo "--- Running initial Robinhood scan ---"
#robinhood --scan --once -d

# Start the Robinhood service
jetpack log "Starting Robinhood service"
#echo "--- Starting Robinhood service ---"
#systemctl start robinhood.service
#systemctl enable robinhood.service

# Start the web service to host the Robinhood web server
echo "*** Starting http service ***"
sudo systemctl start httpd.service
sudo systemctl enable httpd.service

#jetpack log "NOTICE: Check the /var/log/lustreimport.log to see if import finished. Then start robinhood services and run robinhood --scan --once"
jetpack log "setup_robinhood script completed"
echo "--------------------------------------------"
echo "--- setup_robinhood.sh script complete! ---"