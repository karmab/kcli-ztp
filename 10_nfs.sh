#!/usr/bin/env bash

set -euo pipefail

PRIMARY_NIC=$(ls -1 /sys/class/net | head -1)
export KUBECONFIG=/root/ocp/auth/kubeconfig
export PRIMARY_IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
dnf -y install nfs-utils
test ! -f /usr/lib/systemd/system/firewalld.service || systemctl disable --now firewalld
systemctl enable --now nfs-server
export MODE="ReadWriteOnce"
for i in `seq 1 20` ; do
    export PV=pv`printf "%03d" ${i}`
    mkdir /$PV
    echo "/$PV *(rw,no_root_squash)"  >>  /etc/exports
    chcon -t svirt_sandbox_file_t /$PV
    chmod 777 /$PV
    [ "$i" -gt "10" ] && export MODE="ReadWriteMany"
    envsubst < /root/10_nfs.yml | oc create -f -
done
exportfs -r
