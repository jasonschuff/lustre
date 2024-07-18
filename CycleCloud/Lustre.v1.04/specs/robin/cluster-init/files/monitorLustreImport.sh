#!/bin/bash

jetpack log "Monitoring Lustre Import log @ /var/log/lustreimport"
echo "--- Waiting for Lustre import to finish ---"
# File to be monitored
importlogfile=/var/log/lustreimport.log

# Previous file size
prev_size=-1

# Check interval in seconds
interval=60

# Interval for updating jetpack log in UI
jetpackUpdateInterval=600 # Every 10 minutes
elapsted_time_since_update=0

total_elapsed_time=0

while true
do
  # Get current file size
  curr_size=$(stat -c%s "$importlogfile")
   
  # Check if file size has changed
  if [ $prev_size -eq $curr_size ]; then
    echo "File $importlogfile has stopped updating. Lustre Import finished"
	jetpack log "Lustre file import has finished"
    break
  else
    prev_size=$curr_size
    
	if [ $elapsted_time_since_update -ge $jetpackUpdateInterval ]; then
		elapsed_minutes=$((total_elapsed_time / 60))
		echo "Lustre file import has been running for $elapsed_minutes minutes"
		jetpack log "Lustre file import has been running for $elapsed_minutes minutes"
		elapsted_time_since_update=60
		# Delay the default system termination by 1 hour
		jetpack keepalive 
	else
		echo "File $importlogfile is still updating"
		elapsted_time_since_update=$((elapsted_time_since_update + interval))
	fi
  fi

  # Wait for specified interval
  sleep $interval
  total_elapsed_time=$((total_elapsed_time + interval))
done

jetpack log "Lustre file import from blob has completed."

# Run initial scan of the file systemctl
jetpack log "Running initial file scan on Robinhood"
echo "--- Running initial Robinhood scan ---"
robinhood --scan --once -d

# Start the Robinhood service
jetpack log "Starting Robinhood service"
echo "--- Starting Robinhood service ---"
systemctl start robinhood.service
systemctl enable robinhood.service
