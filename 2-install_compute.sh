#!/bin/bash
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
##########install ftp 
install_ftp () {
yum install ftp -y
}
###########install_kvm
install_kvm () {
yum -y install qemu-kvm libvirt virt-install bridge-utils
modprobe kvm 
lsmod | grep kvm
systemctl start libvirtd 
systemctl enable libvirtd 
systemctl status libvirtd 
virsh -c qemu:///system list
}
#nested You must open the host-passthrough firstly!
nested () {
egrep -i '(vmx|svm)' /proc/cpuinfo
cat << EOF >  /etc/modprobe.d/kvm-nested.conf
options kvm_intel nested=1
EOF
modprobe -r kvm_intel
modprobe kvm_intel  
lsmod | grep kvm 
cat /sys/module/kvm_intel/parameters/nested
}
######install nova
install_nova () {
yum --enablerepo=openstack-kilo,epel install openstack-nova-compute openstack-nova-api openstack-nova-network -y
yum --enablerepo=openstack-kilo,epel install openstack-nova-novncproxy -y
#[4] Configure Nova.  
mv /etc/nova/nova.conf /etc/nova/nova.conf.bak
cat << EOF > /etc/nova/nova.conf
[DEFAULT]
my_ip=192.168.1.137
use_ipv6=false
state_path=/var/lib/nova
enabled_apis=ec2,osapi_compute,metadata
osapi_compute_listen=0.0.0.0
osapi_compute_listen_port=8774
rootwrap_config=/etc/nova/rootwrap.conf
api_paste_config=/etc/nova/api-paste.ini
auth_strategy=keystone
log_dir=/var/log/nova
memcached_servers=192.168.1.138:11211
scheduler_driver=nova.scheduler.filter_scheduler.FilterScheduler
notification_driver=nova.openstack.common.notifier.rpc_notifier
rpc_backend = rabbit
# Configure Networking

[vnc]
vnc_enabled=true
novncproxy_host=0.0.0.0
novncproxy_port=6080
novncproxy_base_url=http://192.168.1.137:6080/vnc_auto.html 
vncserver_listen=0.0.0.0
vncserver_proxyclient_address=192.168.1.137

[glance]
host=192.168.1.138
port=9292
protocol=http

[oslo_concurrency]
lock_path=/var/lib/nova/tmp 

[oslo_messaging_rabbit]
rabbit_host=192.168.1.138
rabbit_port=5672
rabbit_userid=guest
rabbit_password=password

[database]
connection=mysql://nova:password@192.168.1.138/nova

[keystone_authtoken]
auth_uri=http://192.168.1.138:5000
auth_url=http://192.168.1.138:35357
auth_plugin=password
project_domain_id=default
user_domain_id=default
project_name=service
username=nova
password=servicepassword 
EOF

chmod 640 /etc/nova/nova.conf 
chgrp nova /etc/nova/nova.conf 

for service in metadata-api compute novncproxy; do
 systemctl start openstack-nova-$service
 systemctl enable openstack-nova-$service
 systemctl status openstack-nova-$service
done 
cat << EOF > ~/keystonerc 
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=adminpassword
export OS_AUTH_URL=http://192.168.1.138:35357/v3
EOF
chmod 600 ~/keystonerc 
source ~/keystonerc 
echo "source ~/keystonerc " >> ~/.bash_profile 
glance image-list
nova image-list
nova-manage service list
}

#select table
echo "Select a operation:"
select opt in install_ftp install_kvm install_nova nested Exit
do 
	case $opt in 
	install_ftp)
		install_ftp;;
	install_kvm)
		install_kvm;;
	nested)
		nested;;
	install_nova)
		install_nova;;
	Exit)
		exit 0;;
	*)
	  echo "Please select a number from 1 to 5 !"
		continue;;
	esac
done
