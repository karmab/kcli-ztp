#!/bin/bash

function patchfunc {
MASTERS=$(oc get node --no-headers | wc -l)
[ "$MASTERS" == "3" ] || return 1
WEBUIS=$(oc get pod -n tf -l webui=webui1 --no-headers | wc -l)
[ "$WEBUIS" == "3" ] || return 1
HOST_IP=$(oc get node -o wide --no-headers | awk '{print $6}' | head -1)
podman run --rm -it -e HOST_IP=$HOST_IP -e API_IP={{ api_ip }} -e INGRESS_IP={{ ingress_ip }} quay.io/karmab/contrail-allow-vips:latest
return 0
}

export KUBECONFIG=/root/ocp/auth/kubeconfig
while ! patchfunc; do
    echo "Waiting 10s to retry..."
    sleep 10
done
