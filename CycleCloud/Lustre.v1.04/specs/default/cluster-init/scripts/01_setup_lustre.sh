#!/bin/bash

# vars used in script
storage_importpath=""
storage_importpath2=""

# set up cycle vars
yum -y install epel-release
yum -y install jq

cluster_name=$(jetpack config cyclecloud.cluster.name)
ccuser=$(jetpack config cyclecloud.config.username)
ccpass=$(jetpack config cyclecloud.config.password)
ccurl=$(jetpack config cyclecloud.config.web_server)
cctype=$(jetpack config cyclecloud.node.template)
ccnodename=$(jetpack config cyclecloud.node.name)
echo " ****************     NODE NAME is $ccnodename     **************"

# Get Lustre information from front end
lustre_version=$(jetpack config lustre.version)
lustremain_version=${lustre_version:0:4}  # Get only the virst 4 digits from lustre for use in rpm package installs
use_nvme=$(jetpack config lustre.use_nvme)

# Get HSM variables from front end
use_hsm=$(jetpack config lustre.use_hsm)
use_raid=$(jetpack config lustre.use_raid)
storage_account=$(jetpack config lustre.storage_account)
storage_sas="$(jetpack config lustre.storage_sas)"
storage_container=$(jetpack config lustre.storage_container)
storage_importpath=$(jetpack config lustre.storage_importpath)

# Get second HSM variables from front end
use_hsm2=$(jetpack config lustre.use_hsm2)
storage_account2=$(jetpack config lustre.storage_account2)
storage_sas2="$(jetpack config lustre.storage_sas2)"
storage_container2=$(jetpack config lustre.storage_container2)
storage_importpath2=$(jetpack config lustre.storage_importpath2)

# Get Telegraf variables from front end
use_telegraf=$(jetpack config lustre.use_telegraf)
telegraf_url=$(jetpack config lustre.telegraf_url)
telegraf_token=$(jetpack config lustre.telegraf_token)
telegraf_org=$(jetpack config lustre.telegraf_org)
telegraf_bucket=$(jetpack config lustre.telegraf_bucket)

# Get log analytics variables from front end
use_log_analytics=$(jetpack config lustre.use_log_analytics)
log_analytics_name=$(jetpack config lustre.log_analytics.name)
log_analytics_workspace_id="$(jetpack config lustre.log_analytics.workspace_id)"
log_analytics_key=$(jetpack config lustre.log_analytics.key)

function isinstalled {
  if yum list installed "$@" >/dev/null 2>&1; then
    true
  else
    false
  fi
}

# Use NVME if checked
if [ "${use_nvme,,}" = "true" ]; then
	jetpack log "Attempting to use nvme devices on node ${ccnodename}"
	nvme=($(ls /dev/nvme*))
	# Look for nvme devices, report error if not found.
	if [ -z "$nvme" ]; then
		jetpack log "No nvme devices found on node ${ccnodename}" --level error
		mdt_device_list='/dev/sdb'
		ost_device_list=''
	else
		jetpack log "Found and using nvme device on node ${ccnodename}" 
		mdt_device_list='/dev/nvme*n1'
		ost_device_list='/dev/nvme*n1'
	fi
else
	# Check for NVME for MDS box even if NVME was not used for OSS
	if [ "$cctype" = "mds" ]; then
		nvme=($(ls /dev/nvme*))
		if [ -n "$nvme" ]; then
			jetpack log "There was nvme devices found on node ${ccnodename}, using for MDS" 
			mdt_device_list='/dev/nvme*n1'
		else
			# If no NVME device found, then use local device SDB
			mdt_device_list='/dev/sdb'
			if [ -d /dev/disk/azure/scsi1 ]; then
				mdt_device_list='/dev/disk/azure/scsi1/*'
				n_devices=$(echo $devices | wc -w)

				echo "Using $n_devices managed disks"
			else
				echo "ERROR: cannot find devices for storage"
				jetpack log "ERROR: cannot find devices for storage on node ${ccnodename}" --level error
				exit 1
			fi
		fi
	fi
	# Empty the OST device list, default when not using NVME
	ost_device_list=''
fi


script_dir=$CYCLECLOUD_SPEC_PATH/files
chmod +x $script_dir/*.sh

if isinstalled "lustre"; then
	jetpack log "Lustre Packages detected as installed on node ${ccnodename}"
	echo "--- Lustre package detected as already installed, skipping install ---"
else
	jetpack log "Installing Lustre Packages on node ${ccnodename}"

	echo "--- Creating Lustre Yum Repo with version $lustre_version ---"
	# SETUP LUSTRE YUM REPO
	$script_dir/lfsrepo.sh $lustre_version

	echo "--- Installing Lustre packages ---"
	# INSTALL LUSTRE PACKAGES
	$script_dir/lfspkgs.sh
fi

# If MDS node, check for NVME and configure
if [ "$cctype" = "mds" ]; then
	n_devices=$(echo $mdt_device_list | wc -w)
	if [ "$n_devices" -gt "1" ]; then
		mdt_device=/dev/md10
		# RAID MDT DEVICES
		$script_dir/create_raid0.sh $mdt_device $mdt_device_list
	else
		mdt_device=$mdt_device_list
	fi
fi

# If not MDS node, loop through all attached disks that are not partitioned and form a raid device
if [ "$cctype" != "mds" ]; then

	# check if not using nvme storage
	if [ -z "$ost_device_list" ]; then
		
		if [ -d /dev/disk/azure/scsi1 ]; then
				ost_device_list='/dev/disk/azure/scsi1/*'
				n_devices=$(echo $ost_device_list | wc -w)

			echo "Using $n_devices managed disks"
		else
			echo "ERROR: cannot find devices for storage"
			jetpack log "ERROR: cannot find devices for storage on node ${ccnodename}" --level error
			exit 1
		fi
	fi
	
	n_ost_devices=$(echo $ost_device_list | wc -w)
	
	echo "Raid setting is: $use_raid"
	
	#check if we need to make raid device from UI setting
	if [ "$use_raid" = "True" ]; then
	
		echo "--- Raid setting enabled, attempting to create raid device ---"
		echo "--- Checking if we need to make a raid device if device count is greater than 1 on ost_device_list: $ost_device_list ---"

		#check if we need to make raid device if device count gt 1
		if [ "$n_ost_devices" -gt "1" ]; then
			ost_device=/dev/md10
			# RAID OST DEVICES
			
			jetpack log "Configurating raid for attached disks on node $ccnodename"
			echo "   Calling create_raid0.sh with variables ost_device $ost_device and ost_device_list $ost_device_list "
			$script_dir/create_raid0.sh $ost_device $ost_device_list
		else
			echo "   Only one block device found at $ost_device_list so no raid necessary"
			ost_device=$ost_device_list
		fi
	else
		echo "   Raid setting not enabled, not creating a raid device."
		ost_device=$ost_device_list
	fi
fi

# Retrieve the IP of the MDS server
echo "--- Retrieved mds_ip of $mds_ip ---"
mds_ip=$(curl -s -k --user $ccuser:$ccpass "$ccurl/clusters/$cluster_name/nodes" | jq -r '.nodes[] | select(.Template=="mds") | .IpAddress')


# Detect the node type, if MDS then run the install for MDS device
if [ "$cctype" = "mds" ]; then
	
	jetpack log "Setting up Lustre MDS node"
	echo "--- MDS node detected, running lfsmaster.sh script passing mdt_device $mdt_device ---"
	# SETUP MDS
	PSSH_NODENUM=0 $script_dir/lfsmaster.sh $mdt_device

else
	# Wait for MDS to be pingable by lfs command before creating OST devices
	jetpack log "Lustre node $ccnodename waiting for MDS node to start"
	echo "--- Non-MDS node detected, wait for the mds to start ---"
	modprobe lustre
	while ! lctl ping $mds_ip@tcp; do
		sleep 2
	done

	ccname=$(jetpack config azure.metadata.compute.name)
	
	# Get OST starting index from the last number of the OSS name
	ost_index=$(( (${ccnodename##*-}) -  1 )) 
	
	ost_index=$(( ( $ost_index * $n_ost_devices ) + 1 ))
	echo "--- ost_index has been updated to $ost_index ---"

	jetpack log "Setting up Lustre $ccnodename node"
	
	echo "--- executing lfsoss.sh script on OSS device with variables of $mds_ip and ost_device of $ost_device ---"
	PSSH_NODENUM=$(expr $ost_index) $script_dir/lfsoss.sh $mds_ip "$ost_device"
fi

if [ "${use_telegraf,,}" = "true" ]; then

	jetpack log "Installing telegraf on node $ccnodename"
	# Run the install for telegraf installation for reporting and graphs
	echo "--- Running lfstelegraf.sh script ---"
	$script_dir/lfstelegraf.sh
	echo "--- Finished running lfstelegraf.sh script ---"
fi

# If Use HSM was checked, run script to set up HSM service and plugins
if [ "${use_hsm,,}" = "true" ]; then

	# Detect the node type, if OSS then run the HSM install for OSS devices
	if [ "$cctype" = "mds" ]; then
		echo "--- MDS node detected, skipping HSM setup on MDS node --- "
		
	else

		jetpack log "Configuring HSM on node $ccnodename"
		echo "--- HSM enablement detected, executing lfshsm.sh script with storage_account $storage_account and storage_container $storage_container and lustre version $lustremain_version ---"

		$script_dir/lfshsm.sh $mds_ip $storage_account "$storage_sas" $storage_container $lustremain_version
	
		# If Use 2nd HSM was checked, run script to add second archive section to lhsm-plugin-az plugin
		if [ "${use_hsm2,,}" = "true" ]; then

			jetpack log "Configuring 2nd HSM on node $ccnodename"
			$script_dir/lfshsm2.sh $storage_account2 "$storage_sas2" $storage_container2 
			
		fi
	fi
fi

# If Use Log Analytics was checked, run script to setup log analytics data
if [ "${use_log_analytics,,}" = "true" ]; then

	jetpack log "Setting up Log Analytics on node $ccnodename"
	echo "--- Log Analytics enablement detected, executing lfsloganalytics.sh with variables log_analytics_name of $log_analytics_name and log_analytics_workspace_id of $log_analytics_workspace_id ---"
	$script_dir/lfsloganalytics.sh $log_analytics_name $log_analytics_workspace_id "$log_analytics_key"

fi

jetpack log "Setup Lustre Script completed on node $ccnodename"
echo "--- setup_lustre.sh script complete! ---"