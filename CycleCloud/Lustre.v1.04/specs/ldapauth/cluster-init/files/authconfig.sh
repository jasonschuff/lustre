echo "--- Installing open ldap components ---"
yum -y install openldap-clients
yum -y install openldap 
yum -y install nss-pam-ldapd
echo "--- Restarting nscd service and nslcd service ---"
systemctl enable nscd
systemctl enable nslcd
echo "--- Running authconfig to attach to ldap server ---"
authconfig --enableldap --enableldapauth --ldapserver=192.168.212.101 --ldapbasedn="dc=cm,dc=cluster" \
--enablelocauthorize --enablepamaccess --enablemkhomedir --enablecachecreds --enablecache --updateall
echo "--- Restarting nscd service and nslcd service ---"
systemctl restart nslcd
systemctl restart nscd
echo "--- Restarting sshd service ---"
systemctl restart sshd