#!/bin/sh
#OpenStack Liberty : Configure Neutron(Control Node)
#Configure OpenStack Network Service (Neutron). 
#
#For this example, Install Neutron Server on Control Node which Keystone/Glance/Nova API are already installed, and Install DHCP Agent, L3 Agent, L2 Agent, Metadata Agent on Network Node, and also Install L2 Agent on Compute Node on here. ( it's possible to install on a server as All-in-One, though, if you want ) 
#
#Neutron needs a plugin software, it's possible to choose it from some softwares. This example chooses ML2 plugin. ( it uses Open vSwitch under the backend ) 
#
#                                    |
#+------------------+                |                 +------------------------+
#| [ Control Node ] |                |                 |    [ Network Node ]    |
#|     Keystone     |192.168.1.138   |    192.168.1.136|        DHCP Agent      |
#|      Glance      |----------------+-----------------|        L3 Agent        |
#|     Nova API     |eth0            |             eth0|        L2 Agent        |
#|  Neutron Server  |                |                 |     Metadata Agent     |
#+------------------+                |                 +------------------------+
#                                eth0|192.168.1.137
#                          +--------------------+
#                          |  [ Compute Node ]  |
#                          |    Nova Compute    |
#                          |      L2 Agent      |
#                          +--------------------+
#
controller=192.168.1.138
MYSQLRPW=123
MYSQLDB=neutron_ml2
MYSQLPW=password
MYSQLUSER=neutron
KENUSER=neutron
KENSRV=neutron
KENPW=servicepassword

install () {
#[1] Add user or service for Neutron to Keystone. 
# add neutron user (set in service project) 
openstack user create --project service --password servicepassword neutron
# add neutron user in admin role
openstack role add --project service --user neutron admin
# add service entry for neutron
openstack service create --name neutron --description "Openstack Network Service" network
openstack endpoint create \
--publicurl http://192.168.1.138:9696 \
--adminurl http://192.168.1.138:9696 \
--internalurl http://192.168.1.138:9696 \
--region RegionOne network

#[2] Add a User and Database on MariaDB for Neutron.

cat << EOF > neutron.sql
create database $MYSQLDB; 
grant all privileges on $MYSQLDB.* to $MYSQLUSER@'localhost' identified by '$MYSQLPW'; 
grant all privileges on $MYSQLDB.* to $MYSQLUSER@'%' identified by '$MYSQLPW'; 
flush privileges; 
exit 
EOF
mysql -u root -p$MYSQLRPW  < neutron.sql
rm -f neutron.sql
#[3] Install Neutron Server. 
yum --enablerepo=openstack-kilo,epel install openstack-neutron openstack-neutron-ml2 -y
#[4] Configure Neutron Server.
######################### /etc/neutron/neutron.conf
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
sed -i '60s/^# core_plugin =/core_plugin = ml2/g' /etc/neutron/neutron.conf
sed -i '69s/^# service_plugins =/service_plugins = router/g' /etc/neutron/neutron.conf
sed -i '84s/^# auth_strategy = keystone/auth_strategy = keystone/g' /etc/neutron/neutron.conf
sed -i '110s/# dhcp_agent_notification/dhcp_agent_notification/g' /etc/neutron/neutron.conf
sed -i '121s/# allow_overlapping_ips = False/allow_overlapping_ips = True/g' /etc/neutron/neutron.conf
sed -i '179s/# router_scheduler_driver/router_scheduler_driver/g' /etc/neutron/neutron.conf
sed -i '343s/# notify_nova_on_port_status_changes/notify_nova_on_port_status_changes/g' /etc/neutron/neutron.conf
sed -i '347s/# notify_nova_on_port_data_changes/notify_nova_on_port_data_changes/g' /etc/neutron/neutron.conf
sed -i '556s/# rpc_backend=rabbit/rpc_backend=rabbit/g' /etc/neutron/neutron.conf
sed -i '561s/# control_exchange=openstack/control_exchange=neutron/g' /etc/neutron/neutron.conf
sed -i '703s/auth_uri/#auth_uri/g' /etc/neutron/neutron.conf
sed -i '704s/identity_uri/#identity_uri/g' /etc/neutron/neutron.conf
sed -i '705s/admin_tenant_name/#admin_tenant_name/g' /etc/neutron/neutron.conf
sed -i '706s/admin_user/#admin_user/g' /etc/neutron/neutron.conf
sed -i '707s/admin_password/#admin_password/g' /etc/neutron/neutron.conf
sed -i '707 a\auth_uri = http:\/\/192.168.1.138:5000 \
auth_url = http:\/\/192.168.1.138:35357 \
auth_plugin = password \
project_domain_id = default \
user_domain_id = default \
project_name = service \
username = neutron \
password = servicepassword' /etc/neutron/neutron.conf

sed -i '720s/# connection = mysql:\/\/root:pass@127.0.0.1:3306\/neutron/\
connection = mysql:\/\/neutron:password@192.168.1.138\/neutron_ml2/g' /etc/neutron/neutron.conf

sed -i '/\[nova\]/a\auth_url = http:\/\/192.168.1.138:35357 \
auth_plugin = password \
project_domain_id = default \
user_domain_id = default \
region_name = RegionOne \
project_name = service \
username = nova \
password = servicepassword' /etc/neutron/neutron.conf

sed -i '/\[oslo_messaging_rabbit\]/a\rabbit_host = 192.168.1.138 \
rabbit_port = 5672 \
rabbit_userid = guest \
rabbit_password = password' /etc/neutron/neutron.conf 

######################### /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i 's/^# type_drivers = local,flat,vlan,gre,vxlan/type_drivers = flat,vlan,gre/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i 's/^# tenant_network_types = local/tenant_network_types = vlan,gre/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i 's/^# mechanism_drivers =/mechanism_drivers = openvswitch/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i 's/^# enable_security_group = True/enable_security_group = True/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i '/^enable_security_group = True/a\firewall_driver =neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver' /etc/neutron/plugins/ml2/ml2_conf.ini

######################### /etc/nova/nova.conf 
sed -i '/^# Configure Networking/a\network_api_class=nova.network.neutronv2.api.API \
security_group_api=neutron \
linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver \
firewall_driver=nova.virt.firewall.NoopFirewallDriver' /etc/nova/nova.conf 
cat << EOF >> /etc/nova/nova.conf
[neutron]
url=http://192.168.1.138:9696
auth_strategy=keystone
admin_auth_url=http://192.168.1.138:35357/v2.0
admin_tenant_name=service
admin_username=neutron
admin_password=servicepassword
EOF

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini 
neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head
chgrp nova /etc/nova/nova.conf
systemctl start neutron-server 
systemctl enable neutron-server 
systemctl restart openstack-nova-api 
}

remove () {
openstack endpoint delete $(openstack endpoint list |grep $KENSRV|awk '{print $2}' )
openstack service delete $KENSRV
openstack user delete $KENUSER

cat << EOF > neutron.sql
drop database $MYSQLDB; 
flush privileges; 
exit 
EOF
mysql -u root -p$MYSQLRPW  < neutron.sql
rm -f neutron.sql
systemctl stop neutron-server 
systemctl disable neutron-server 
yum -y remove openstack-neutron openstack-neutron-ml2 
sed -i '/network_api_class=nova.network.neutronv2.api.API/,/^firewall_driver=nova.virt.firewall.NoopFirewallDriver/d' /etc/nova/nova.conf 
sed -i '/^\[neutron\]/,/admin_password=servicepassword/d' /etc/nova/nova.conf
rm -rf /etc/neutron
rm -rf /var/log/neutron

systemctl restart openstack-nova-api 

}
# status of services
status () {
systemctl status neutron-server  openstack-nova-api 
}
stop () {
systemctl stop neutron-server  openstack-nova-api 
}
start () {
systemctl start neutron-server  openstack-nova-api 
}
#select table
echo "Select a operation:"
select opt in install remove status start stop restart  Exit
do 
	case $opt in
	install)
		if [ -f /var/ins.lock ] 
		then 
			echo Has already been installed. ;
		else
			touch /var/ins.lock;
			install
		fi;;
	remove)
		if [ -f /var/ins.lock ] 
		then 
			rm -f /var/ins.lock;
			remove
		else
			echo Has been unloaded. ;
		fi;;
	status)
	 	status ;;
	stop)
	  stop;;
	start)
	  start;;
	restart)
	  stop
	  start;;
	Exit)
		exit 0;;
	*)
			echo "Please select a number from 1 to 7 !"
			continue;;
	esac
done
