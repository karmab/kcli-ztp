#!/usr/bin/env bash

export KUBECONFIG=/root/ocp/auth/kubeconfig
echo "Report from vm: $(hostname) ip: $(hostname -I | cut -d' ' -f1)"
echo "Cluster info:"
oc get clusterversion
echo "Nodes info:"
oc get nodes
