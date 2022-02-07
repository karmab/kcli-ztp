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
