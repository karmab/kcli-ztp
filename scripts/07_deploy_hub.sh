#!/usr/bin/env bash

set -euo pipefail

cd /root
export HUB={{ cluster }}
export DOMAIN={{ domain }}
export PATH=/root/bin:$PATH
export HOME=/root
export PYTHONUNBUFFERED=true
export KUBECONFIG=/root/ocp/auth/kubeconfig

{% set virtual_ctlplanes_nodes = [] %}
{% set virtual_workers_nodes = [] %}
{% if virtual_hub %}
{% for num in range(0, ctlplanes) %}
{% do virtual_ctlplanes_nodes.append({}) %}
{% endfor %}
{% endif %}
{% if virtual_hub and workers > 0 %}
{% for num in range(0, workers) %}
{% do virtual_workers_nodes.append({}) %}
{% endfor %}
{% endif %}
{% set hosts = baremetal_ctlplanes + baremetal_workers + virtual_ctlplanes_nodes + virtual_workers_nodes %}

{% for host in hosts %}
{% set num = loop.index0|string %}
{% set role = 'ctlplane' if num|int < (baremetal_ctlplanes + virtual_ctlplanes_nodes)|length else 'worker' %}
{% set url = host["redfish_address"]|default("http://127.0.0.1:9000/redfish/v1/Systems/kcli/%s-%s-%s" % (cluster, role, num)) %}
{% set user = host['bmc_user']|default(bmc_user) %}
{% set password = host['bmc_password']|default(bmc_password) %}
{% set reset = host['bmc_reset']|default(bmc_reset) %}
kcli stop baremetal-host -P url={{ url }} -P user={{ user }} -P password={{ password }}
kcli update baremetal-host -P url={{ url }} -P user={{ user }} -P password={{ password }} -P iso=None
{% if reset %}
kcli reset baremetal-host -P url={{ url }} -P user={{ user }} -P password={{ password }}
{% endif %}
{% endfor %}

{% if localhost_fix %}
cp /root/machineconfigs/99-localhost-fix*.yaml /root/manifests
{% endif %}
{% if monitoring_retention != None %}
cp /root/machineconfigs/99-monitoring.yaml /root/manifests
{% endif %}
{% if prega and not disconnected %}
cp /root/machineconfigs/99-prega-catalog*.yaml /root/manifests
{% endif %}
find manifests -type f -empty -print -delete

{% if api_ip != None %}
echo {{ api_ip }} api.$HUB.$DOMAIN >> /etc/hosts
{% endif %}

{% if virtual_hub %}
kcli delete iso --yes $HUB.iso || true
{% endif %}

mkdir -p ocp/openshift
cp install-config.yaml ocp 
cp agent-config.yaml ocp

if find manifests/*y*ml -quit &> /dev/null ; then
cp manifests/*y*ml >/dev/null 2>&1 ocp/openshift
openshift-install agent create cluster-manifests --dir ocp
fi

openshift-install agent create image --dir ocp --log-level debug

mv -f ocp/agent.x86_64.iso /var/www/html/$HUB.iso
restorecon -Frv /var/www/html
chown apache.apache /var/www/html/$HUB.iso

AI_TOKEN=$(jq '.["*image.Ignition"].Config.storage.files[] | select(.path == "/usr/local/share/assisted-service/assisted-service.env") | .contents.source' ocp/.openshift_install_state.json | cut -d, -f2 | sed 's/"//' | base64 -d | grep AGENT_AUTH_TOKEN | cut -d= -f2)
[ "$AI_TOKEN" == "" ] || echo export AI_TOKEN=$AI_TOKEN >> /root/.bashrc

PRIMARY_NIC=$(ls -1 /sys/class/net | grep -v podman | head -1)
IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d "/" -f 1 | head -1)
echo $IP | grep -q ':' && IP=[$IP]
{% for host in hosts %}
{% set num = loop.index0|string %}
{% set role = 'ctlplane' if num|int < (baremetal_ctlplanes + virtual_ctlplanes_nodes)|length else 'worker' %}
{% set url = host["redfish_address"]|default("http://127.0.0.1:9000/redfish/v1/Systems/kcli/%s-%s-%s" % (cluster, role, num)) %}
{% set user = host['bmc_user']|default(bmc_user) %}
{% set password = host['bmc_password']|default(bmc_password) %}
kcli start baremetal-host -P url={{ url }} -P user={{ user }} -P password={{ password }} -P iso_url=http://$IP/$HUBn.iso
{% endfor %}

{% if hosts|length == 1 %}
SNO_IP={{ rendezvous_ip or static_ips[0] }}
sed -i "/api.$HUB.$DOMAIN/d" /etc/hosts
echo $SNO_IP api.$HUB.$DOMAIN >> /etc/hosts
{% endif %}

openshift-install --dir ocp --log-level debug wait-for install-complete || openshift-install --dir ocp --log-level debug wait-for install-complete

{% if virtual_hub %}
for node in $(oc get nodes --selector='node-role.kubernetes.io/master' -o name) ; do
  oc label $node node-role.kubernetes.io/virtual=""
done
{% endif %}
