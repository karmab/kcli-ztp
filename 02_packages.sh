#!/usr/bin/env bash

dnf -y install libvirt-libs libvirt-client ipmitool mkisofs tmux make git
{% if 'rhel' in image %} 
subscription-manager repos --enable=openstack-15-tools-for-rhel-8-x86_64-rpms
dnf -y install python3-openstackclient python3-ironicclient
{% else %}
dnf clean all
sleep 30
dnf -y install python36
pip3 install python-openstackclient python-ironicclient
{% endif %}
