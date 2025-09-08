#!/usr/bin/env bash

SPOKE=$(cat /root/ztp/scripts/seed.txt)
oc delete managedcluster $SPOKE

export KUBECONFIG=/root/kubeconfig.$SPOKE
kcli create app lifecycle-agent
sleep 240

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

{% set spoke = spokes[1] %}
{% set host = spoke.baremetal_hosts[0] if spoke.baremetal_hosts is defined else {} %}
{% set url = host["redfish_address"]|default("https://127.0.0.1:9000/redfish/v1/Systems/kcli/%s-%s-node-0" % (cluster, spoke.name)) %}
{% set user = host['bmc_user']|default(bmc_user) %}
{% set password = host['bmc_password']|default(bmc_password) %}
kcli stop baremetal -u {{ user }} -p {{ password }} {{ url }}
