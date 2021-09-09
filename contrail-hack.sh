#!/bin/bash

function patchforport {
sed -i "s@hub.juniper.net/contrail/tf-operator:R2011.L1.297@docker.io/tungstenfabric/tf-operator:R2011-2021-09-13@" /root/ocp/manifests/02-tf-operator.yaml
sed -i "s@hub.juniper.net/contrail/contrail-vrouter-agent:R2011.L1.297@docker.io/tungstenfabric/contrail-vrouter-agent:R2011-2021-09-13@" /root/ocp/manifests/03-tf.yaml
sed  -i "/vroutercni/a\ \ \ \ \ \ \ \ \ \ envVariablesConfig:\n \ \ \ \ \ \ \ \ \ \ \ VROUTER_AGENT_INTROSPECT_PORT: \"18085\"" /root/ocp/manifests/03-tf.yaml
}

function allowvips {
MASTERS=$(oc get node --no-headers | wc -l)
[ "$MASTERS" == "3" ] || return 1
WEBUIS=$(oc get pod -n tf -l webui=webui1 --no-headers | wc -l)
[ "$WEBUIS" == "3" ] || return 1
# HOST_IP=$(oc get node -o wide --no-headers | awk '{print $6}' | head -1)
# API_IP=$(oc get cm -n kube-system cluster-config-v1 -o yaml | grep apiVIP | cut -d: -f2 | xargs)
# INGRESS_IP=$(oc get cm -n kube-system cluster-config-v1 -o yaml | grep ingressVIP | cut -d: -f2 | xargs)
# podman run -e HOST_IP=$HOST_IP -e IP=$API_IP quay.io/karmab/contrail-allow-vips:latest
# podman run -e HOST_IP=$HOST_IP -e IP=$INGRESS_IP quay.io/karmab/contrail-allow-vips:latest
return 0
}

export KUBECONFIG=/root/ocp/auth/kubeconfig
patchforport

#dnf -y install podman
while ! allowvips; do
  echo "Waiting 10s to retry..."
  sleep 10
done

# temp stability hack
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
