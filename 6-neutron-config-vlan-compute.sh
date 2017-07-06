#!/bin/bash
#add 1 network card nmtui-modify name to [ens7], not select [Automatically connect],nmtui-active

cd /etc/sysconfig/network-scripts/
sed -i 's/BOOTPROTO=dhcp/BOOTPROTO=none/g' ifcfg-ens7 
cd -
systemctl restart network
ip a
#add floating ip port
ovs-vsctl add-br br-eth1
ovs-vsctl add-port br-eth1 ens7
ovs-vsctl show
#modify ml2_conf.ini to surport VLAN
sed -i '67s/# network_vlan_ranges =/network_vlan_ranges = physnet1:1000:2999/g' /etc/neutron/plugins/ml2/ml2_conf.ini
cat << EOF >> /etc/neutron/plugins/ml2/ml2_conf.ini
[ovs]
tenant_network_type = vlan
bridge_mappings = physnet1:br-eth1
EOF
systemctl restart neutron-openvswitch-agent
systemctl status neutron-openvswitch-agent