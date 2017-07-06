#!/bin/bash
NTPSERVER="192.168.2.16"
# attention here the NTPSERVER ip should be right!!! 

#######disable_sellinux_firewall
disable_sellinux_firewall () {
systemctl stop firewalld
systemctl disable firewalld
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
echo "bash ~/scripts-newton/init_vm.sh" >> ~/.bash_profile
# attention here tht path "scripts-newton" should be right!!!
reboot
}
######config NTP(chrony)
config_chrony_server () {
sed -i 's/bash ~\/scripts-newton\/init_vm.sh//g' ~/.bash_profile
# attention here tht path "scripts-newton" should be right!!!
sed -i '/^server 0.centos.pool.ntp.org iburst/,/^server 3.centos.pool.ntp.org iburst/s/^/#/g' /etc/chrony.conf 
sed -i "/^#server 3.centos.pool.ntp.org iburst/a\server $NTPSERVER iburst" /etc/chrony.conf 
sed -i 's/#allow 192.168\/16/allow 192.168.2.0\/24/g'  /etc/chrony.conf
# attention here the [network segement] should be right!!! 
sed -i 's/#local stratum 10/local stratum 10/g'  /etc/chrony.conf 
#attention here $NTPSERVER use ""
systemctl restart chronyd 
systemctl enable chronyd
chronyc sources -v
}
config_chrony_client () {
sed -i 's/bash ~\/scripts-newton\/init_vm.sh//g' ~/.bash_profile
# attention here tht path "scripts-newton" should be right!!!
sed -i '/^server 0.centos.pool.ntp.org iburst/,/^server 3.centos.pool.ntp.org iburst/s/^/#/g' /etc/chrony.conf 
sed -i "/^#server 3.centos.pool.ntp.org iburst/a\server $NTPSERVER iburst" /etc/chrony.conf 
#attention here $NTPSERVER use ""
systemctl restart chronyd 
systemctl enable chronyd
chronyc sources -v
}

echo "Select a operation:"
	select opt in disable_sellinux_firewall config_chrony_server config_chrony_client  "Exit"
	do 
	case $opt in
	disable_sellinux_firewall)
		disable_sellinux_firewall;;
	config_chrony_server)
		config_chrony_server ;; 
	config_chrony_client)
		config_chrony_client ;;  
	"Exit")
		exit 0;;
	*)
		echo "Please select a number from 1 to 4 !"
		continue;;
	esac
	done
