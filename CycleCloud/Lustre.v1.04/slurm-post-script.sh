# Create symbolic links to home folders
mount_point=$(jetpack config lustre.mount_point)

mkdir /data
chmod 777 /data
echo "--- Creating symbolic links for scratch folder from ${mount_point}/scratch    ---"
ln -s ${mount_point}/archive2/scratch /data/scratch
echo "--- Creating symbolic links for data folder from ${mount_point}/apps    ---"
ln -s ${mount_point}/archive1/apps /data/apps
echo "--- Creating symbolic links for pic folder from ${mount_point}/pic    ---"
ln -s ${mount_point}/archive1/pic /data/pic

echo "--- Symbolic links created ---" 