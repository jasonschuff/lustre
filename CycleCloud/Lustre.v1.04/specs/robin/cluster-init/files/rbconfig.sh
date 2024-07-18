#!/bin/bash

mount_point=$(jetpack config lustre.mount_point)

db_password=$(jetpack config robinhood.db_password)
use_policy_file=$(jetpack config robinhood.use_policy_file)

if [ "${use_policy_file,,}" = "true" ]; then
	policy_file=$(jetpack config robinhood.policy_file)
	policy_file_include="%include \"$(jetpack config robinhood.policy_file)\""
	#sed "s#__MOUNT_POINT__#${mount_point}#g" policy_file
else
	policy_file_include="%include \"rb-def-policies.inc\""
	#unset policy_file
fi

echo "*** Installing MariaDB ***"
db_password=P@ssw0rd1
db_file=lustre_robinhood

yum install -y mariadb-server

echo "*** MariaDB installation finished ***"

echo "*** Starting MariaDB Service ***"
systemctl enable mariadb.service
systemctl start mariadb.service

echo "*** Creating Robinhood database ***" 
rbh-config create_db $db_file    'localhost' $db_password

echo "*** Database created ***"

echo "*** Creatng dbpassword file ***"
cat << EOF >/etc/robinhood.d/.dbpassword
$db_password
EOF
chmod 600 /etc/robinhood.d/.dbpassword
echo "*** DB Password File Created ***"

#echo "*** Making Robinhood logging directory at /var/log/robinhood/ ***"
#mkdir /var/log/robinhood

echo "*** Mount point is set to $mount_point ***"
echo "*** Configuring /etc/robinhood.d/lustreFS.conf from template ***"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
sed "s#__MOUNT_POINT__#${mount_point}#g;s#__DB_NAME__#${db_file}#g;s#__POLICY_FILE__#${policy_file_include}#g"  $DIR/lustreFS.conf.in >/etc/robinhood.d/lustreFS.conf
echo "*** lusreFS.conf Configured ***"

echo "*** Configuring /var/www/robinhood.d/config.php from template ***"
sed "s#__DB_NAME__#${db_file}#g;s#__DB_PASSWORD__#${db_password}#g"  $DIR/config.php.in >/var/www/robinhood/config.php
echo "*** config.php Configured ***"
echo "*** Starting http service ***"
systemctl start httpd

echo "*** Setting robinhood tuning settings for lustre client ***"
# Set up Robinhood specific tuning settings for Lustre client
lctl set_param llite.*.statahead_max=4
lctl set_param ldlm.namespaces.*.lru_size=100
lctl set_param ldlm.namespaces.*.lru_max_age=1200
lctl set_param mdc.*.max_rpcs_in_flight=64
echo "*** Robinhood tuning settings complete ***"