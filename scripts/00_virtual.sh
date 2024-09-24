#!/usr/bin/env bash

set -euo pipefail

{% if not 'rhel' in image %}
dnf clean all
sleep 30
{% endif %}
echo "fastestmirror=1" >> /etc/dnf/dnf.conf
dnf -y install pkgconf-pkg-config gcc python3-libvirt python3 git python3-netifaces

dnf -y copr enable karmab/kcli
dnf -y install kcli
{% if config_type != 'kvm' %}
dnf -y install epel-release
kcli install provider {{ config_type }}
{% endif %}

SUSHYFLAGS={{ "--ipv6" if ':' in baremetal_cidr else "" }}
kcli create sushy-service $SUSHYFLAGS
