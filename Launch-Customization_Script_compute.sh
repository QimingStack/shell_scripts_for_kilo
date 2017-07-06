#!/bin/bash
passwd root << EOF
123456
123456
EOF
systemctl stop firewalld
systemctl disable firewalld
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
timedatectl set-timezone Asia/Shanghai
hostnamectl set-hostname compute