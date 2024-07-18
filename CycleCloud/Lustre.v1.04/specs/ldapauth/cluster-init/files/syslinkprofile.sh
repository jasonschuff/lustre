# The path to the mount point
mount_point=$1

# Create symbolic links to home folders
echo "--- Creating symbolic links for home folder from ${mount_point}/home    ---"
for i in $(find ${mount_point}/home/* -maxdepth 0 -type d)
	do ln -s $i /home
done

echo "--- Symbolic links created ---" 