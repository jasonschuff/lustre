#!/bin/bash

# vars used in script
nodename=$(jetpack config cyclecloud.node.name)

# Get Telegraf variables from front end
use_telegraf=$(jetpack config lustre.use_telegraf)
telegraf_url=$(jetpack config lustre.telegraf_url)
telegraf_token=$(jetpack config lustre.telegraf_token)
telegraf_org=$(jetpack config lustre.telegraf_org)
telegraf_bucket=$(jetpack config lustre.telegraf_bucket)

echo "--- Downloading telegraf-1.19.3-1.x86_64.rpm ---"
wget https://dl.influxdata.com/telegraf/releases/telegraf-1.19.3-1.x86_64.rpm

echo "--- Installing telegraf-1.19.3-1.x86_64.rpm ---"
yum -y localinstall telegraf-1.19.3-1.x86_64.rpm

echo "--- Change permissions on /etc/telegraf to 777 ---"
chmod -R 777 /etc/telegraf

echo "*** Configuring /etc/telegraf/telegraf.conf from template ***"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
sed "s#__HOST_NAME__#${nodename}#g;s#__URL__#${telegraf_url}#g;s#__TOKEN__#${telegraf_token}#g;s#__ORG__#${telegraf_org}#g;s#__BUCKET__#${telegraf_bucket}#g"  $DIR/ProdTelegrafAgent.txt >/etc/telegraf/telegraf.conf

echo "--- Enable and start telegraf ---"
systemctl enable telegraf
systemctl start telegraf
echo "--- Telegraf script completed! ---"