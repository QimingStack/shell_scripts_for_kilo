#!/bin/bash
cd /etc/sysconfig/network-scripts/
sed -i 's/BOOTPROTO=dhcp/BOOTPROTO=none/g' ifcfg-ens7 
cd -
systemctl restart network
ip a
#[2] 	Change settings on both Network Node and Compute Node. 
# add bridge
ovs-vsctl add-br br-eth1 
# add eth1 to the port of the bridge above
ovs-vsctl add-port br-eth1 ens7
ovs-vsctl show
sed -i '67s/^# network_vlan_ranges =/network_vlan_ranges = physnet1:1000:2999/g' /etc/neutron/plugins/ml2/ml2_conf.ini
cat << EOF >> /etc/neutron/plugins/ml2/ml2_conf.ini
[ovs]
tenant_network_type = vlan
bridge_mappings = physnet1:br-eth1
EOF
systemctl restart neutron-openvswitch-agent 
systemctl status neutron-openvswitch-agent

ovs-vsctl add-br br-ext
ovs-vsctl add-port br-ext ens8
#config l3
sed -i '66s/external_network_bridge = ovs/external_network_bridge = br-ext/g' /etc/neutron/l3_agent.ini
systemctl restart neutron-l3-agent
systemctl status neutron-l3-agent
