#!/usr/bin/env bash

set -euo pipefail

export KUBECONFIG=/root/ocp/auth/kubeconfig
echo "Report from vm: $(hostname) ip: $(hostname -I | cut -d' ' -f1)"
echo "Update time: $(uptime | awk '{ print $3 }' | sed 's/,//')"
echo "Cluster info:"
oc get clusterversion
echo "Nodes info:"
oc get nodes

echo -e "\nSpokes:"
oc get clusterinstance -A

echo -e "\nPolicies:"
oc get policies -A
