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

NTPSERVER="192.168.2.16"

#######disable_sellinux_firewall
disable_sellinux_firewall () {
systemctl stop firewalld
systemctl disable firewalld
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
reboot
}
######config NTP(chrony)
config_chrony () {
sed -i '/^server 0.centos.pool.ntp.org iburst/,/^server 3.centos.pool.ntp.org iburst/s/^/#/g' /etc/chrony.conf 
sed -i "/^#server 3.centos.pool.ntp.org iburst/a\server $NTPSERVER iburst" /etc/chrony.conf 
#attention here $NTPSERVER use ""
systemctl restart chronyd 
systemctl enable chronyd
chronyc sources -v
}
######YUM---local-iso epel openstack-kilo###########
yum_iso_epel_kilo () {
mkdir /etc/yum.repos.d/bak
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak

#mkdir /etc/yum.repos.d/bak2
#mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak2

cat << EOF >  /etc/yum.repos.d/local-iso.repo
[iso]
name=local-iso
baseurl=http://192.168.1.114
enabled=1
gpgcheck=0
EOF
#EOF should touch to the beginning of the line
wget http://192.168.2.250/conf2repos/epel.txt -P /etc/yum.repos.d/
if [ -f /etc/yum.repos.d/epel.txt ] 
then 
	mv /etc/yum.repos.d/epel.txt /etc/yum.repos.d/epel.repo
else
	wget http://192.168.2.250/conf2repos/epel.txt -P /etc/yum.repos.d/
	mv /etc/yum.repos.d/epel.txt /etc/yum.repos.d/epel.repo
fi
		
wget http://192.168.2.250/conf2repos/openstack-kilo.txt -P /etc/yum.repos.d/
if [ -f /etc/yum.repos.d/openstack-kilo.txt ] 
then 
	mv /etc/yum.repos.d/openstack-kilo.txt /etc/yum.repos.d/openstack-kilo.repo
else
	wget http://192.168.2.250/conf2repos/openstack-kilo.txt -P /etc/yum.repos.d/
	mv /etc/yum.repos.d/openstack-kilo.txt /etc/yum.repos.d/openstack-kilo.repo
fi	
}
##########install ftp 
install_ftp () {
yum install ftp -y
}
##########install mariadb
install_mysql () {
yum -y install mariadb-server 
sed -i '/^\[mysqld\]/a\character-set-server=utf8' /etc/my.cnf 
systemctl start mariadb 
systemctl enable mariadb
systemctl status mariadb 
mysql_secure_installation 
}
##########install rabbitmq-server memcached
install_rab_mem () {
PWD=password
yum  --enablerepo=epel install rabbitmq-server memcached -y
#sed -i '/^127/s/$/  control/g' /etc/hosts
systemctl start rabbitmq-server memcached 
systemctl enable rabbitmq-server memcached
systemctl status rabbitmq-server memcached  
rabbitmqctl change_password guest $PWD
}
############install keystone
install_keystone () {
MYSQLPWD=123
yum  -y --enablerepo=openstack-kilo,epel install openstack-keystone openstack-utils python-openstackclient httpd #mod_wsgi
rm -f /etc/httpd/conf.d/welcom.conf 
cat << EOF > create.sql
create database keystone;
grant all privileges on keystone.* to keystone@'localhost' identified by 'password';
grant all privileges on keystone.* to keystone@'%' identified by 'password';
flush privileges;
exit
EOF
mysql -u root -p$MYSQLPWD  < create.sql
rm -f create.sql
sed -i '12s/#admin_token = ADMIN/admin_token = admintoken/' /etc/keystone/keystone.conf
sed -i '419s/#connection = mysql:\/\/keystone:keystone@localhost\/keystone/connection = mysql:\/\/keystone:password@192.168.1.138\/keystone/' /etc/keystone/keystone.conf
sed -i '1627s/#certfile = \/etc\/keystone\/ssl\/certs\/signing_cert.pem/certfile = \/etc\/keystone\/ssl\/certs\/signing_cert.pem/' /etc/keystone/keystone.conf
sed -i '1630s/#keyfile = \/etc\/keystone\/ssl\/private\/signing_key.pem/keyfile = \/etc\/keystone\/ssl\/private\/signing_key.pem/' /etc/keystone/keystone.conf
sed -i '1633s/#ca_certs = \/etc\/keystone\/ssl\/certs\/ca.pem/ca_certs = \/etc\/keystone\/ssl\/certs\/ca.pem/' /etc/keystone/keystone.conf
sed -i '1636s/#ca_key = \/etc\/keystone\/ssl\/private\/cakey.pem/ca_key = \/etc\/keystone\/ssl\/private\/cakey.pem/' /etc/keystone/keystone.conf
sed -i '1640s/#key_size = 2048/key_size = 2048/' /etc/keystone/keystone.conf
sed -i '1644s/#valid_days = 3650/valid_days = 3650/' /etc/keystone/keystone.conf
sed -i '1648s/#cert_subject = \/C=US\/ST=Unset\/L=Unset\/O=Unset\/CN=www.example.com/cert_subject = \/C=CN\/ST=Unset\/L=Unset\/O=Unset\/CN=control.sange.com/' /etc/keystone/keystone.conf

keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
keystone-manage db_sync
chown -Rv keystone. /var/log/keystone
systemctl start openstack-keystone
systemctl enable openstack-keystone
systemctl status openstack-keystone
}
#########config_keystone
config_keystone () {
	export OS_TOKEN=admintoken 
	export OS_URL=http://192.168.1.138:35357/v2.0/

	#Add Projects. 	
	openstack project create  --description "Admin Project" admin 
	openstack project create  --description "Service Project" service 
	openstack project list 
	#Add Roles. 
	openstack role create admin
	openstack role create Member 
	openstack role list 
	#Add User Accounts. 
	openstack user create  --project admin --password adminpassword admin 
	openstack role add --project admin --user admin admin 
	openstack user list 
	#Add entries for services. 
	openstack service create --name keystone --description "OpenStack Identity" identity 
	openstack service list 
	#Add Endpoints. 
	export controller="192.168.1.138"
	openstack endpoint create \
	--publicurl http://$controller:5000/v2.0 \
	--internalurl http://$controller:5000/v2.0 \
	--adminurl http://$controller:35357/v2.0 \
	--region RegionOne identity

	openstack endpoint list 
}
install_glance () {
export OS_TOKEN=admintoken 
export OS_URL=http://192.168.1.138:35357/v2.0
#[1] Add users and others for Glance in Keystone.  
openstack user create  --project service --password servicepassword glance 
openstack role add --project service --user glance admin 
openstack service create --name glance --description "OpenStack Image service" image
export controller=192.168.1.138
openstack endpoint create \
--publicurl http://$controller:9292 \
--internalurl http://$controller:9292 \
--adminurl http://$controller:9292 \
--region RegionOne image
openstack endpoint list
#[2] Install Glance.  
yum --enablerepo=openstack-kilo,epel install openstack-glance -y
#[3] Add a User and Database on MariaDB for Glance.  
cat << EOF > create.sql
create database glance;
grant all privileges on glance.* to glance@'localhost' identified by 'password';
grant all privileges on glance.* to glance@'%' identified by 'password';
flush privileges;
exit
EOF
mysql -u root -p123  < create.sql
rm -f create.sql
#[4] Configure Glance.  
#[4-1] Configure Glance API  
cp /etc/glance/glance-api.conf /etc/glance/glance-api.conf.bak
sed -i '344s/#connection=mysql:\/\/glance:glance@localhost\/glance/connection=mysql:\/\/glance:password@192.168.1.138\/glance/' /etc/glance/glance-api.conf

sed -i '/#revocation_cache_time=10/ a\
auth_uri=http:\/\/192.168.1.138:5000 \
auth_url=http:\/\/192.168.1.138:35357 \
auth_plugin=password \
project_domain_id=default \
user_domain_id=default \
project_name=service \
username=glance \
password=servicepassword ' /etc/glance/glance-api.conf

sed -i 's/#flavor=/flavor=keystone/' /etc/glance/glance-api.conf

#[4-2]Configure Glance Registry
cp /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.bak
sed -i '170s/#connection=mysql:\/\/glance:glance@localhost\/glance/connection=mysql:\/\/glance:password@192.168.1.138\/glance/' /etc/glance/glance-registry.conf

sed -i '/#admin_password=%SERVICE_PASSWORD%/ a\
auth_uri=http:\/\/192.168.1.138:5000 \
auth_url=http:\/\/192.168.1.138:35357 \
auth_plugin=password \
project_domain_id=default \
user_domain_id=default \
project_name=service \
username=glance \
password=servicepassword ' /etc/glance/glance-registry.conf

sed -i 's/#flavor=/flavor=keystone/' /etc/glance/glance-registry.conf

glance-manage db_sync
chown -Rv glance. /var/log/glance
systemctl start openstack-glance-api openstack-glance-registry 
systemctl enable openstack-glance-api openstack-glance-registry 
systemctl status openstack-glance-api openstack-glance-registry 
}
################install KVM  libvirt
install_kvm () {
yum install qemu-kvm libvirt virt-install bridge-utils -y
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
##########################################################################
install_nova () {
#[1] Add users and others for Nova in Keystone.  
export OS_TOKEN=admintoken 
export OS_URL=http://192.168.1.138:35357/v2.0
openstack user create --project service --password servicepassword nova 
openstack role add --project service --user nova admin 
openstack service create --name nova --description "OpenStack Compute service" compute
export controller=192.168.1.138
openstack endpoint create \
--publicurl http://$controller:8774/v2/%\(tenant_id\)s \
--internalurl http://$controller:8774/v2/%\(tenant_id\)s \
--adminurl http://$controller/v2/%\(tenant_id\)s \
--region RegionOne compute

#[2] Install Nova.  
yum --enablerepo=openstack-kilo,epel install openstack-nova -y

#[3] Add a User and Database on MariaDB for Nova.  
cat << EOF > create.sql
create database nova;
grant all privileges on nova.* to nova@'localhost' identified by 'password';
grant all privileges on nova.* to nova@'%' identified by 'password';
flush privileges;
exit
EOF
mysql -u root -p123  < create.sql
rm -f create.sql
#[4] Configure Nova.  
mv /etc/nova/nova.conf /etc/nova/nova.conf.bak 
cat << EOF > /etc/nova/nova.conf
[DEFAULT]
my_ip=192.168.1.138
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
rpc_backend=rabbit
# Configure Networking
[vnc]

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

nova-manage db sync
chown -R nova. /var/log/nova
for service in api objectstore conductor scheduler cert consoleauth compute ; do
 systemctl start openstack-nova-$service
 systemctl enable openstack-nova-$service
 systemctl status openstack-nova-$service
done 

unset OS_TOKEN OS_URL
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
#Horizon  dashboard
install_dashboard () {
#[1] Install Horizon.  
yum --enablerepo=openstack-kilo,epel install openstack-dashboard openstack-nova-novncproxy -y
#[2] Configure VNC
sed -i '/\[vnc\]/a\vnc_enabled=true \
novncproxy_host=0.0.0.0 \
novncproxy_port=6080 \
novncproxy_base_url=http:\/\/192.168.1.138:6080/vnc_auto.html \
vncserver_listen=0.0.0.0 \
vncserver_proxyclient_address=192.168.1.138' /etc/nova/nova.conf
#[3] Configure Dashboard.  
sed -i 's/horizon.example.com/192.168.1.138/g' /etc/openstack-dashboard/local_settings 
sed -i '/^OPENSTACK_HOST/s/127.0.0.1/192.168.1.138/g' /etc/openstack-dashboard/local_settings
chown -R apache. /usr/share/openstack-dashboard/static

systemctl start openstack-nova-novncproxy httpd
systemctl enable openstack-nova-novncproxy httpd
systemctl restart openstack-nova-compute
systemctl status openstack-nova-novncproxy openstack-nova-compute httpd
STAT=`systemctl status httpd | grep -i active | awk '{print $3}'`
if [ "$STAT" != "(running)" ]
then
	cd tar-horizon
		tar xvfz pathlib-1.0.1.tar.gz
		tar xvfz pyScss-1.3.5.tar.gz
		tar xvfz django-pyscss-2.0.2.tar.gz
		cd pathlib-1.0.1
			python setup.py install
		cd -
		cd pyScss-1.3.5
			python setup.py install
		cd -
		cd django-pyscss-2.0.2
		python setup.py install
		cd -
	cd -
fi
systemctl restart httpd
systemctl status httpd
}

#select table
echo "Select a operation:"
select opt in  disable_fire_sel yum config_ntp install_ftp install_mysql install_rab_mem install_keystone config_keystone install_glance install_kvm nested install_nova install_dashboard "Exit"
do 
	case $opt in  		
		install)
			if [ -f  var ins.lock ] 
			then 
				echo Has already been installed. ;
			else
				touch /var/ins.lock;
#				install
			fi
			;;
	  remove)
			if [ -f /var/ins.lock ] 
			then 
				rm -f /var/ins.lock;
#				remove
			else
				echo Has been unloaded.;
			fi
	      ;;
	disable_fire_sel)
		disable_sellinux_firewall;; 
	yum)
		yum_iso_epel_kilo;;
	config_ntp)
		config_chrony;;
	install_ftp)
		install_ftp;;
	install_rab_mem)
		install_rab_mem;;
	install_keystone)
	  install_keystone;;
	install_mysql)
	 	install_mysql;;
	config_keystone)
	  config_keystone;;
	install_glance)
		install_glance;;
	install_kvm)
		install_kvm;;
	nested)
		nested;;
	install_nova)
		install_nova;;
	install_dashboard)
		install_dashboard;;
	"Exit")
			exit 0;;
	*)
		echo "Please select a number from 1 to 14 !"
		continue;;
	esac
done