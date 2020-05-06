#!/usr/bin/env bash

# set -euo pipefail

yum -y install pkgconf-pkg-config libvirt-devel gcc python3-libvirt python3
pip3 install virtualbmc
/usr/local/bin/vbmcd
python3 /root/bin/vbmc.py
api_vip=$(grep apiVIP /root/install-config.yaml | awk -F: '{print $2}' | xargs)
cluster=$(grep -m 1 name /root/install-config.yaml | awk -F: '{print $2}' | xargs)
domain=$(grep baseDomain /root/install-config.yaml | awk -F: '{print $2}' | xargs)
IP=$(ip -o addr show {{ baremetal_net }} | head -1 | awk '{print $4}' | cut -d "/" -f 1 | head -1)
sed -i "s/DONTCHANGEME/$IP/" /root/install-config.yaml
echo $api_vip api.$cluster.$domain >> /etc/hosts
