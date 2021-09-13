#!/usr/bin/env bash

set -euo pipefail

export KUBECONFIG=/root/ocp/auth/kubeconfig
echo "Report from vm: $(hostname) ip: $(hostname -I | cut -d' ' -f1)"
echo "Cluster info:"
oc get clusterversion
echo "Nodes info:"
oc get nodes
echo "Update time:"
uptime | awk '{ print $3 }' | sed 's/,//'
{% if ztp_spoke_name is defined %}
export SPOKE={{ ztp_spoke_name }}
oc describe -n $SPOKE AgentClusterInstall
oc get agent -A
{% endif %}
touch /root/cluster_ready.txt
