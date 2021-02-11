#!/usr/bin/env bash

# set -euo pipefail

{% if not 'rhel' in image %}
dnf clean all
sleep 30
{% endif %}
dnf -y install pkgconf-pkg-config libvirt-devel gcc python3-libvirt python3 ipmitool python3-devel
export CRYPTOGRAPHY_DONT_BUILD_RUST=1
pip3 install -U pip
pip3 install virtualbmc
/usr/local/bin/vbmcd
ssh-keyscan -H {{ config_host|default(baremetal_net|local_ip) }} >> /root/.ssh/known_hosts
echo -e "Host=*\nStrictHostKeyChecking=no\n" > /root/.ssh/config
python3 /root/bin/vbmc.py
api_vip=$(grep apiVIP /root/install-config.yaml | awk -F: '{print $2}' | xargs)
cluster=$(grep -m 1 name /root/install-config.yaml | awk -F: '{print $2}' | xargs)
domain=$(grep baseDomain /root/install-config.yaml | awk -F: '{print $2}' | xargs)
IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d "/" -f 1 | head -1)
sed -i "s/DONTCHANGEME/$IP/" /root/install-config.yaml
sed -i "s/DONTCHANGEME/$IP/" /root/extra_worker.yml
echo $api_vip api.$cluster.$domain >> /etc/hosts
