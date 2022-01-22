#!/usr/bin/env bash

BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
echo $BAREMETAL_IP | grep -q ':' && BAREMETAL_IP=[$BAREMETAL_IP]
oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"watchAllNamespaces": true}}'
sed -i "s@IP@$BAREMETAL_IP@" /root/ztp_bmc.yml
export LIBVIRT_DEFAULT_URI=qemu+ssh://{{ 'root' if config_user == 'apache' else config_user }}@{{ config_host if config_host != '127.0.0.1' else baremetal_net|local_ip(true) }}/system
{% for num in range(0, ztp_virtual_nodes_number) %}
UUID=$(virsh domuuid {{ cluster }}-ztp-node-{{ num }})
sed -i "s@UUID-{{ num }}@$UUID@" /root/ztp_bmc.yml
{% endfor %}
oc create -f /root/ztp_bmc.yml
