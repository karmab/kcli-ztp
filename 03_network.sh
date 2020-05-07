#!/usr/bin/env bash

nmcli connection add ifname {{ provisioning_net }} type bridge con-name {{ provisioning_net }}
nmcli con add type bridge-slave ifname eth1 master {{ provisioning_net }}
nmcli connection add ifname baremetal type bridge con-name baremetal
nmcli con add type bridge-slave ifname eth0 master baremetal
nmcli con down "System eth0"; sudo pkill dhclient; sudo dhclient baremetal
nmcli connection modify {{ provisioning_net }} ipv4.addresses {{ provisioning_installer_ip }}/{{ provisioning_cidr.split('/')[1] }} ipv4.method manual
nmcli con down {{ provisioning_net }}
nmcli con up {{ provisioning_net }}
