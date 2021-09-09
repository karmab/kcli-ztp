#!/bin/bash

function wait-for-bootstrap-cm {
[ -f $KUBECONFIG ] || return 1
oc get cm -n kube-system bootstrap || return 1
}

function contrail-hack {
export HOST_IP=$(ip -o addr show vhost0 | awk '{print $4}' | cut -d "/" -f 1 | head -1)
DOMAIN=$(oc get ingresscontroller -n openshift-ingress-operator default -o jsonpath='{.spec.domain}' | sed 's/apps.//')
export API_IP=$(dig +short api.$DOMAIN)
export INGRESS_IP=$(dig +short xxx.apps.$DOMAIN)
podman run -e HOST_IP=$HOST_IP -e IP=$API_IP quay.io/karmab/contrail-allow-vips:latest
podman run -e HOST_IP=$HOST_IP -e IP=$INGRESS_IP quay.io/karmab/contrail-allow-vips:latest
}

export KUBECONFIG=/etc/kubernetes/static-pod-resources/kube-apiserver-certs/secrets/node-kubeconfigs/localhost.kubeconfig
while ! wait-for-bootstrap-cm; do
    echo "Waiting 10s to retry checking bootstrap cm..."
    sleep 10
done
while ! contrail-hack; do
    echo "Waiting 10s to retry patching code..."
    sleep 10
done
touch /etc/contrail-patch.done
