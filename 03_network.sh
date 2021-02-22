#!/usr/bin/env bash

nmcli connection add ifname {{ baremetal_net }} type bridge con-name {{ baremetal_net }} stp yes priority 45056
nmcli con add type bridge-slave ifname eth0 master {{ baremetal_net }}
nmcli con down "System eth0"; sudo pkill dhclient; sudo dhclient {{ baremetal_net }}

{% if provisioning_enable %}
nmcli connection add ifname {{ provisioning_net }} type bridge con-name {{ provisioning_net }}
nmcli con add type bridge-slave ifname eth1 master {{ provisioning_net }}
nmcli connection modify {{ provisioning_net }} ipv4.addresses {{ provisioning_installer_ip }}/{{ provisioning_cidr.split('/')[1] }} ipv4.method manual
nmcli con down {{ provisioning_net }}
nmcli con up {{ provisioning_net }}
{% endif %}
