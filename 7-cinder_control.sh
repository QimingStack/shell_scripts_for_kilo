#!/bin/bash
#OpenStack Liberty : Configure Neutron(Compute Node)
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
#[1] 	Change the kernel parameters for rp_filter. 
echo 'net.ipv4.conf.default.rp_filter=0' >> /etc/sysctl.conf 
echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.conf  
sysctl -p 
#[2] 	Install some packages for Compute Node. 
yum --enablerepo=openstack-kilo,epel install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y
#[3] 	Configure as a Compute Node. 

######################### /etc/neutron/neutron.conf
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
######################### /etc/neutron/plugins/ml2/ml2_conf.ini
cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.bak
sed -i 's/^# type_drivers = local,flat,vlan,gre,vxlan/type_drivers = flat,vlan,gre/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i 's/^# tenant_network_types = local/tenant_network_types = vlan,gre/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i 's/^# mechanism_drivers =/mechanism_drivers = openvswitch/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i 's/^# enable_security_group = True/enable_security_group = True/g' /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i '/^enable_security_group = True/a\firewall_driver =neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver' /etc/neutron/plugins/ml2/ml2_conf.ini
cd /etc/neutron/plugins/openvswitch/
mv ovs_neutron_plugin.ini ovs_neutron_plugin.ini.bak
cd - #change back to original-directory
ln -sv /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
ln -sv /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini

#################################  /etc/nova/nova.conf
cp /etc/nova/nova.conf /etc/nova/nova.conf.bak
chgrp nova /etc/nova/nova.conf
sed -i '/^# Configure Networking/a\network_api_class=nova.network.neutronv2.api.API \
security_group_api=neutron \
linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver \
firewall_driver=nova.virt.firewall.NoopFirewallDriver \
metadata_listen=0.0.0.0 \
metadata_host=192.168.1.138 \
vif_plugging_is_fatal=True \
vif_plugging_timeout=300 ' /etc/nova/nova.conf 

# add follows to the ned : Neutron auth info
cat << EOF >> /etc/nova/nova.conf
[neutron]
service_metadata_proxy=True
metadata_proxy_share_secret=snowopenstack
url=http://192.168.1.138:9696
auth_strategy=keystone
admin_auth_url=http://192.168.1.138:35357/v2.0
admin_tenant_name=service
admin_username=neutron
admin_password=servicepassword
default_tenant_id=default
EOF

systemctl start openvswitch 
systemctl enable openvswitch
ovs-vsctl add-br br-int 
ovs-vsctl list br 
systemctl restart openstack-nova-compute openstack-nova-metadata-api 
systemctl start neutron-openvswitch-agent 
systemctl enable neutron-openvswitch-agent 
neutron agent-list
}

remove () {
ovs-vsctl del-br br-int
sed -i '/^net.ipv4.conf.default.rp_filter=0/d'  /etc/sysctl.conf 
sed -i '/^net.ipv4.conf.all.rp_filter=0/d'  /etc/sysctl.conf 
rm -f /etc/nova/nova.conf;mv /etc/nova/nova.conf.bak /etc/nova/nova.conf
rm -f /etc/neutron/plugins/ml2/ml2_conf.ini;mv /etc/neutron/plugins/ml2/ml2_conf.ini.bak /etc/neutron/plugins/ml2/ml2_conf.ini
sysctl -p 
rm -f  /etc/neutron/plugin.ini 
systemctl stop openvswitch
systemctl disable openvswitch
systemctl restart openstack-nova-compute openstack-nova-metadata-api 
systemctl stop neutron-openvswitch-agent 
systemctl disable neutron-openvswitch-agent  
#yum -y remove openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch   openstack-neutron-common
}

status () {
systemctl status openvswitch openstack-nova-compute openstack-nova-metadata-api neutron-openvswitch-agent
}
stop () {
systemctl stop openvswitch openstack-nova-compute openstack-nova-metadata-api neutron-openvswitch-agent
}
start () {
systemctl start openvswitch openstack-nova-compute openstack-nova-metadata-api neutron-openvswitch-agent
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
	    status;;
	  stop)
	    stop;;
	  start)
	    start;;
	  restart)
	    stop
	    start ;; 
		Exit)
			exit 0;;
		*)
			echo "Please select a number from 1 to 7 !"
			continue;;
	esac
done

