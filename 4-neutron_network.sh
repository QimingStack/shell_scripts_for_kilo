#!/bin/bash
#OpenStack Liberty : Configure Neutron(Network Node)
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

install () {
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf 
echo 'net.ipv4.conf.default.rp_filter=0' >> /etc/sysctl.conf 
echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.conf 
sysctl -p 
yum --enablerepo=openstack-kilo,epel install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y
#[4] Configure Neutron Server.
################################# /etc/neutron/neutron.conf
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
sed -i '60s/^# core_plugin =/core_plugin = ml2/g' /etc/neutron/neutron.conf
sed -i '69s/^# service_plugins =/service_plugins = router/g' /etc/neutron/neutron.conf
sed -i '84s/^# auth_strategy = keystone/auth_strategy = keystone/g' /etc/neutron/neutron.conf
#sed -i '110s/# dhcp_agent_notification/dhcp_agent_notification/g' /etc/neutron/neutron.conf
sed -i '121s/# allow_overlapping_ips = False/allow_overlapping_ips = True/g' /etc/neutron/neutron.conf
sed -i '179s/# router_scheduler_driver/router_scheduler_driver/g' /etc/neutron/neutron.conf
#sed -i '343s/# notify_nova_on_port_status_changes/notify_nova_on_port_status_changes/g' /etc/neutron/neutron.conf
#sed -i '347s/# notify_nova_on_port_data_changes/notify_nova_on_port_data_changes/g' /etc/neutron/neutron.conf
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

sed -i '/\[oslo_messaging_rabbit\]/a\rabbit_host = 192.168.1.138 \
rabbit_port = 5672 \
rabbit_userid = guest \
rabbit_password = password' /etc/neutron/neutron.conf 
chmod 640 /etc/neutron/neutron.conf 
chgrp neutron /etc/neutron/neutron.conf 

################################# /etc/neutron/l3_agent.ini 
cp /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.bak
#chgrp neutron /etc/neutron/l3_agent.ini
sed -i '11s/# interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/interface_driver =neutron.agent.linux.interface.OVSInterfaceDriver/g' /etc/neutron/l3_agent.ini  
sed -i '/^# external_network_bridge = br-ex/a\external_network_bridge = ovs' /etc/neutron/l3_agent.ini 

################################# /etc/neutron/dhcp_agent.ini 
cp /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.bak 
#chgrp neutron /etc/neutron/dhcp_agent.ini
sed -i '16s/^#interface_driver =/interface_driver =/g' /etc/neutron/dhcp_agent.ini   
sed -i '34s/^#dhcp_driver/dhcp_driver/g' /etc/neutron/dhcp_agent.ini 
#sed -i '/^#enable_isolated_metadata/a\enable_isolated_metadata = True' /etc/neutron/dhcp_agent.ini 

################################# /etc/neutron/metadata_agent.ini 
cp /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.org
chgrp neutron /etc/neutron/metadata_agent.ini
sed -i '6s/^auth_url/# auth_url/g' /etc/neutron/metadata_agent.ini
sed -i '7s/^auth_region/# auth_region/g' /etc/neutron/metadata_agent.ini 
sed -i '12s/admin_tenant_name/# admin_tenant_name/g' /etc/neutron/metadata_agent.ini
sed -i '13s/admin_user/# admin_user/g' /etc/neutron/metadata_agent.ini
sed -i '14s/admin_password/# admin_password/g' /etc/neutron/metadata_agent.ini

sed -i '14 a\auth_uri = http://192.168.1.138:5000 \
auth_url = http://192.168.1.138:35357 \
auth_region = RegionOne \
auth_plugin = password \
project_domain_id = default \
user_domain_id = default \
project_name = service \
username = neutron \
password = servicepassword' /etc/neutron/metadata_agent.ini 

sed -i 's/# nova_metadata_ip = 127.0.0.1/nova_metadata_ip = 192.168.1.138/g' /etc/neutron/metadata_agent.ini 
sed -i 's/# nova_metadata_port = 8775/nova_metadata_port = 8775/g' /etc/neutron/metadata_agent.ini 
sed -i 's/# metadata_proxy_shared_secret =/metadata_proxy_shared_secret = snowopenstack/g' /etc/neutron/metadata_agent.ini
################################# /etc/neutron/plugins/ml2/ml2_conf.ini
cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.org
chgrp neutron /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i 's/^# type_drivers = local,flat,vlan,gre,vxlan/type_drivers = flat,vlan,gre/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i 's/^# tenant_network_types = local/tenant_network_types = vlan,gre/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i 's/^# mechanism_drivers =/mechanism_drivers = openvswitch/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i 's/^# enable_security_group = True/enable_security_group = True/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i '90 a\firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver' /etc/neutron/plugins/ml2/ml2_conf.ini

cd /etc/neutron/plugins/openvswitch
mv ovs_neutron_plugin.ini ovs_neutron_plugin.ini.bak
cd -
ln -sv /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
ln -sv /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini
systemctl start openvswitch 
systemctl enable openvswitch 
ovs-vsctl add-br br-int 
ovs-vsctl list-br
for service in dhcp-agent l3-agent metadata-agent openvswitch-agent; do
	systemctl start neutron-$service
	systemctl enable neutron-$service
done 

}

remove () {
ovs-vsctl del-br br-int 
sed -i '/^net.ipv4.ip_forward=1/d'  /etc/sysctl.conf 
sed -i '/^net.ipv4.conf.default.rp_filter=0/d'  /etc/sysctl.conf 
sed -i '/^net.ipv4.conf.all.rp_filter=0/d'  /etc/sysctl.conf 
sysctl -p 
rm -f  /etc/neutron/plugin.ini 
systemctl stop openvswitch
systemctl disable openvswitch 
for service in dhcp-agent l3-agent metadata-agent openvswitch-agent; do
	systemctl stop neutron-$service
	systemctl disable neutron-$service
done 
rm -f /etc/neutron/neutron.conf;mv /etc/neutron/neutron.conf.bak /etc/neutron/neutron.conf
rm -f /etc/neutron/l3_agent.ini;mv /etc/neutron/l3_agent.ini.bak /etc/neutron/l3_agent.ini
rm -f /etc/neutron/dhcp_agent.ini ;mv /etc/neutron/dhcp_agent.ini.bak /etc/neutron/dhcp_agent.ini 
rm -f /etc/neutron/metadata_agent.ini;mv /etc/neutron/metadata_agent.ini.bak /etc/neutron/metadata_agent.ini
rm -f /etc/neutron/plugins/ml2/ml2_conf.ini;mv /etc/neutron/plugins/ml2/ml2_conf.ini.bak /etc/neutron/plugins/ml2/ml2_conf.ini

#yum -y remove openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch openstack-neutron-common

}

status () {
systemctl status openvswitch  neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent neutron-openvswitch-agent
}
start () {
systemctl start openvswitch  neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent neutron-openvswitch-agent
}

stop () {
systemctl stop openvswitch  neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent neutron-openvswitch-agent
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
			fi
			;;
	  remove)
			if [ -f /var/ins.lock ] 
			then 
				rm -f /var/ins.lock;
				remove
			else
				echo Has been unloaded. ;
			fi;;
	  status)
	    status;;
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
