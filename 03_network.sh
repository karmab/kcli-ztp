#!/usr/bin/env bash

set -euo pipefail

{% if provisioning_enable %}
nmcli connection add ifname {{ provisioning_net }} type bridge con-name {{ provisioning_net }}
nmcli con add type bridge-slave ifname eth1 master {{ provisioning_net }}
nmcli connection modify {{ provisioning_net }} ipv4.addresses {{ provisioning_installer_ip }}/{{ provisioning_cidr.split('/')[1] }} ipv4.method manual
nmcli con down "System eth1"
nmcli con down {{ provisioning_net }}
nmcli con up {{ provisioning_net }}
{% endif %}

{% if installer_nested %}
export PRIMARY_NIC=$(ls -1 /sys/class/net | head -1)
nmcli connection add ifname {{ baremetal_net }} type bridge con-name {{ baremetal_net }}
nmcli con add type bridge-slave ifname "$PRIMARY_NIC" master {{ baremetal_net }}
nmcli con down "System $PRIMARY_NIC"; pkill dhclient; dhclient {{ baremetal_net }}
sleep 20
{% endif %}
