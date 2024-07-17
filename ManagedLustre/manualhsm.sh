#!/bin/bash

#HSM SCRIPT

#function to check if date entered is valid
is_valid_date() {
	date -d "$1" >/dev/null 2>$1
	}

#function logging
log_out() {
	#printf '%(%Y/%m/%d %H:%M:%S)T %p\n' $1 $2 >> /var/log/manualhsm.log
	echo $(date '+%Y/%m/%d %H:%M:%S') $1 $2 >> /var/log/manualhsm.log
	}
export -f log_out

#prompt for valid folder path
while true; do
	read -p "Enter folder path: " folder_path
	
	if [ -d "$folder_path" ]; then
		echo "valid path"
		break #exit if valid
	else
		echo "Invalid folder path"
	fi
done

#prompt and check if input is valid date
while true; do
	read -p "Enter a date (YYYY-MM-DD): " input_date

	if is_valid_date "$input_date"; then
		echo "Valid date"
		#add day to date for -newermt to grab entered date
		input_date=$(date -d "$input_date + 1 days")
		break #exit if valid
	else
		echo "Date not valid. Please use YYYY-MM-DD format"
	fi
done
	
#read archive/release
#prompt for action
while true; do
	read -p "Select an action (a=archive / r=release): " input_action
	
	if [ "$input_action" == "a" ]; then
		input_action="archive"
		break
	elif [ "$input_action" == "r" ]; then
		input_action="release"
		break
	else
		echo "Invalid option.  Please choose either 'a' for archive or 'r' for release."
	fi
done

#count number of files
echo "Counting number of files to $input_action ..."
count_files=$(find $folder_path -type f ! -newermt "$input_date" | wc -l)
echo "Total file count = $count_files"
read -p "Do you wish to continue? (y,n): " choice

if [ "$choice" == "y" ]; then

	#Actions
	
	#Append log
	#echo "$(date +"%Y/%m/%d %H:%M:%S") $input_action job started" >> /var/log/manualhsm.log
	log_out $input_action "job started"
	
	#Archive
	if [ $input_action == "archive" ]; then
		#echo "archiving $folder_path, date: $input_date"
		#find $folder_path -type f ! -newermt "$input_date" -printf '%(%Y/%m/%d %H:%M:%S)T archiving %p\n' >> /var/log/manualhsm.log -exec lfs hsm_archive {} \;
		find $folder_path -type f ! -newermt "$input_date" -printf '%TY/%Tm/%Td %TH:%TM:%TS archiving %p\n' -exec lfs hsm_archive {} \; -exec bash -c 'log_out "archiving" "$0"' {} \;
	fi
	
	#archving is required before releasing
	#Release
	if [ $input_action == "release" ]; then
		#echo "releasing $folder_path, date: $input_date"
		#find $folder_path -type f ! -newermt "$input_date" -printf '%(%Y/%m/%d %H:%M:%S)T archiving %p\n' >> /var/log/manualhsm.log -exec lfs hsm_release {} \; -printf '%(%Y/%m/%d %H:%M:%S)T releasing %p\n' >> /var/log/manualhsm.log -exec lfs hsm_release {} \;
		find $folder_path -type f ! -newermt "$input_date" -printf '%TY/%Tm/%Td %TH:%TM:%TS archiving %p\n' -exec lfs hsm_release {} \; -printf '%TY/%Tm/%Td %TH:%TM:%TS releasing %p\n' -exec lfs hsm_release {} \; -exec bash -c 'log_out "releasing" "$0"' {} \;
	fi
fi
