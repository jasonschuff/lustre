#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 {all|new|synchro|released|modified}"
    exit 1
fi

# Define the input parameter
status=$1

# Determine the output file name based on the input parameter
case "$status" in
    all)
        output_file="/lustre/all_entries.csv"
        sql_where_clause=""
        ;;
    new)
        output_file="/lustre/new_entries.csv"
        sql_where_clause="WHERE ENTRIES.lhsm_status = 'new'"
        ;;
    synchro)
        output_file="/lustre/synchro_entries.csv"
        sql_where_clause="WHERE ENTRIES.lhsm_status = 'synchro'"
        ;;
    released)
        output_file="/lustre/released_entries.csv"
        sql_where_clause="WHERE ENTRIES.lhsm_status = 'released'"
        ;;
    modified)
        output_file="/lustre/modified_entries.csv"
        sql_where_clause="WHERE ENTRIES.lhsm_status = 'modified'"
        ;;
    *)
        echo "Invalid parameter. Use {all|new|synchro|released|modified}."
        exit 1
        ;;
esac

# Define the output file paths
header_file="/lustre/header.csv"
data_file="/lustre/data.csv"
temp_output_file="/lustre/temp_output.csv"

# Remove the files if they exist
rm -f "$header_file" "$data_file" "$output_file" "$temp_output_file"

# Create the header file
echo '"ID","FileName","LHSMStatus","LastAccess","LastMod","Type","UID","GID","Path","HSMState"' > "$header_file"

# Run the SQL command to export the data to a temporary data file
mysql -D lustre_robinhood -e "
SELECT 
    ENTRIES.id AS ID,
    NAMES.name AS FileName,
    ENTRIES.lhsm_status AS LHSMStatus,
    ENTRIES.last_access AS LastAccess,
    ENTRIES.last_mod AS LastMod,
    ENTRIES.type AS Type,
    ENTRIES.uid AS UID,
    ENTRIES.gid AS GID
INTO OUTFILE '$data_file'
FIELDS TERMINATED BY ','
ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
FROM 
    ENTRIES
LEFT JOIN 
    NAMES ON ENTRIES.id = NAMES.id
$sql_where_clause;
"

# Check if data_file has content
if [ ! -s "$data_file" ]; then
    echo "No data was exported. Please check the SQL query and the database contents."
    exit 1
fi

# Create the temp output file
touch "$temp_output_file"

# Add path and HSM state information to the CSV
cat "$header_file" > "$output_file"

# Read the data file and process each entry
while IFS= read -r line; do
    # Skip the header line
    if [[ "$line" == *"ID"* ]]; then
        continue
    fi

    # Split the line into fields
    IFS=',' read -r id name status last_access last_mod type uid gid <<< "$line"

    # Strip quotes from the id
    id=${id//\"/}
    name=${name//\"/}
    status=${status//\"/}
    last_access=${last_access//\"/}
    last_mod=${last_mod//\"/}
    type=${type//\"/}
    uid=${uid//\"/}
    gid=${gid//\"/}

    # Query the path using lfs fid2path
    path=$(lfs fid2path /lustre "$id" 2>/dev/null)
    if [ -z "$path" ]; then
        continue
    fi

    # Query the HSM state using lfs hsm_state and format the output
    hsm_state=$(lfs hsm_state "$path" 2>/dev/null | awk -F': ' '{print $2}')
    if [ -z "$hsm_state" ]; then
        continue
    fi

    # Append the result to the temp output file with the path and HSM state included
    echo "\"$id\",\"$name\",\"$status\",\"$last_access\",\"$last_mod\",\"$type\",\"$uid\",\"$gid\",\"$path\",\"$hsm_state\"" >> "$temp_output_file"
done < "$data_file"

# Concatenate the header and temp_output_file to create the final output
cat "$header_file" "$temp_output_file" > "$output_file"

# Clean up temporary files
rm -f "$header_file" "$data_file" "$temp_output_file"

echo "Results written to $output_file"
