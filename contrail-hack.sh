#!/bin/bash
export KUBECONFIG=/root/ocp/auth/kubeconfig

while true ; do 
    echo "Waiting 1mn for cluster to be ready"
    sleep 60
    MASTERS=$(oc get node | grep master | wc -l)
    [ "$MASTERS" == "3" ] && break 
done

dnf -y install haproxy
NUM=0
for ip in `oc get node -o wide | awk '{print $6}' | grep -v INTERN` ; do
    sed -i "s/MASTER$NUM/$ip/" /root/haproxy.cfg
    NUM=$(( $NUM + 1 ))
done

cp /root/haproxy.cfg /etc/haproxy
setsebool -P haproxy_connect_any 1
systemctl enable --now haproxy

while true ; do 
    echo "Waiting 20s for bootstrap phase to be finished"
    sleep 5
    # openshift-install wait-for bootstrap-complete >/dev/null 2>&1
    grep 'level=debug msg="Bootstrap status: complete' /root/ocp/.openshift_install.log
    [ "$?" == "0" ] && break 
done

#NIC=$(ip r | grep default | head -1 | sed 's/.*dev \(.*\) \(proto\|metric\).*/\1/')
NIC=eth0
NETMASK=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -1 | cut -d'/' -f2)
ip addr add {{ api_ip }}/$NETMASK dev $NIC
ip addr add {{ ingress_ip }}/$NETMASK dev $NIC
