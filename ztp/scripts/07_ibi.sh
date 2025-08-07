#!/usr/bin/env bash

SPOKE=$1
export KUBECONFIG=/root/kubeconfig.$SPOKE
kcli create app lifecycle-agent

REGISTRY_USER={{ disconnected_user }}
REGISTRY_PASSWORD={{ disconnected_password }}

{% if disconnected_url != None %}
REGISTRY={{ disconnected_url }}
{% elif dns %}
REGISTRY=registry.{{ cluster }}.{{ domain }}:5000
{% else %}
BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
REGISTRY=$(echo $BAREMETAL_IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io:5000
{% endif %}
export REGISTRY

export VERSION=v$(oc get clusterversion version -o jsonpath='{.status.desired.version}')
export KEY=$(echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | base64)
envsubst < /root/ztp/scripts/ibi_seed.sample.yaml | oc create -f -

while [ "$(oc get seedgen | grep SeedGenCompleted)" == "" ] ; do
  echo "Waiting for seed Image to be created from spoke $SPOKE"
  sleep 60
done
