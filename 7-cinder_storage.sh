#!/bin/bash

install_cinder () {
yum --enablerepo=openstack-kilo,epel install openstack-cinder targetcli python-oslo-policy python-oslo-db  -y

mv /etc/cinder/cinder.conf /etc/cinder/cinder.conf.bak
cat << EOF > /etc/cinder/cinder.conf
[DEFAULT]
state_path = /var/lib/cinder
api_paste_config = api-paste.ini
enable_v1_api = True
enable_v2_api = True
osapi_volume_listen = 0.0.0.0
osapi_volume_listen_port = 8776
auth_strategy = keystone
rpc_backend = rabbit

glance_host = 192.168.1.138
glance_port = 9292

notification_driver = cinder.openstack.common.notifier.rpc_notifier
scheduler_driver = cinder.scheduler.filter_scheduler.FilterScheduler

[database]
connection = mysql://cinder:password@192.168.1.138/cinder

[keystone_authtoken]
auth_uri = http://192.168.1.138:5000
auth_url = http://192.168.1.138:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = cinder
password = servicepassword

[oslo_concurrency]
lock_path = \$state_path/tmp

[oslo_messaging_rabbit]
rabbit_host = 192.168.1.138
rabbit_port = 5672
rabbit_userid = guest
rabbit_password = password
EOF

chmod 640 /etc/cinder/cinder.conf
chgrp cinder /etc/cinder/cinder.conf

systemctl start openstack-cinder-volume
systemctl enable openstack-cinder-volume
sleep 2s
systemctl status openstack-cinder-volume
STATUS=`systemctl status openstack-cinder-volume | grep Active | awk '{print $3}'`
if [ $STATUS != "(running)" ]
then
	mkdir backup
	mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup
	mv /etc/yum.repos.d/bak/*.repo /etc/yum.repos.d/
	pip install oslo.log 
	systemctl restart openstack-cinder-volume
	systemctl status openstack-cinder-volume | grep Active
	mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak 
	mv /etc/yum.repos.d/backup/*.repo /etc/yum.repos.d/
fi	
cinder-manage service list
}
echo "Select a operation:"
	select opt in    install_cinder  "Exit"
	do 
		case $opt in
		install_cinder)
			install_cinder;;
		"Exit")
			exit 0;;
		*)
			echo "Please select a number from 1 to 2 !"
			continue;;
		esac
	done
