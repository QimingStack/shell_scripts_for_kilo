#!/bin/bash
IMGNAME=name
IMGSIZE=0
create_img () {
if [ ! -d /var/kvm/images/ ]
then 
	mkdir -p /var/kvm/images
fi
echo "Please type in a name for img: [name].img"
read imgname
while true
do
	if [ -f /var/kvm/images/$imgname.img ]
	then 
		echo "Existed! Please change another name!"
		ls /var/kvm/images
		echo "Please type in a name for img: <name>.img"
		read imgname
	else
		break
	fi
done

df -h | head -n 2 
echo "Please type in a size for img: (like 20G)"
read imgsize
qemu-img create -f qcow2 /var/kvm/images/$imgname.img $imgsize
IMGNAME=$imgname
IMGSIZE=$imgsize
qemu-img info /var/kvm/images/$imgname.img
}

install_vm () {
virsh list --all
echo "Please type in a name for vm:"
read vmname
#checkname=`virsh list | grep \$vmname`
#while true
#do
#	if [ "$checkname" != ""]
#	then
#		echo "Name is existed!
#Please type in anther name for vm!"
#		read vmname
#	else
#		break
#	fi
#done
free -m
echo "Please type in a size for RAM of vm:(like <800>MB)"
read ram

SIZE=${IMGSIZE%G*}
echo "Please type in a number for vcpus:(1-24)"
read vcpu
#echo "Please type in the path of ISO:(like /path/)"
#read path
ISO=CentOS-7-x86_64-Everything-1503-01.iso 

virt-install --name $vmname --ram $ram --disk path=/var/kvm/images/$IMGNAME.img,size=$SIZE  \
--vcpu $vcpu --os-type linux \
--os-variant rhel7 --network bridge=br0 --graphics none \
--console pty,target_type=serial \
#--location $path$ISO \
--location /tmp/$ISO \
--extra-args 'console=ttyS0,115200n8 serial'
}
#select table
echo "Select a operation:"
select opt in create_img install_vm  Exit
do 
	case $opt in
		create_img)
			create_img;;
		install_vm)
			install_vm ;;   
		Exit)
			exit 0;;
		*)
			echo "Please select a number from 1 to 3 !"
			continue;;
	esac
done