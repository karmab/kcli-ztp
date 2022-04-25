#!/usr/bin/env bash

set -euo pipefail

cd /root
export PATH=/root/bin:$PATH
export HOME=/root
export KUBECONFIG=/root/ocp/auth/kubeconfig
export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=$(cat /root/version.txt)
bash /root/bin/clean.sh || true
mkdir -p ocp/openshift
python3 /root/bin/ipmi.py off
python3 /root/bin/redfish.py off
cp install-config.yaml ocp
openshift-baremetal-install --dir ocp --log-level debug create manifests
{% if localhost_fix %}
cp /root/machineconfigs/99-localhost-fix*.yaml /root/manifests
{% endif %}
{% if monitoring_retention != None %}
cp /root/machineconfigs/99-monitoring.yaml /root/manifests
{% endif %}
find manifests -type f -empty -print -delete
cp manifests/*y*ml >/dev/null 2>&1 ocp/openshift || true
echo {{ api_ip }} api.{{ cluster }}.{{ domain }} >> /etc/hosts
{% if baremetal_bootstrap_ip != None %}
openshift-baremetal-install --dir ocp --log-level debug create ignition-configs
NIC=ens3
NICDATA="$(cat /root/static_network/ifcfg-bootstrap | base64 -w0)"
cp /root/ocp/bootstrap.ign /root/ocp/bootstrap.ign.ori
cat /root/ocp/bootstrap.ign.ori | jq ".storage.files |= . + [{\"filesystem\": \"root\", \"mode\": 420, \"path\": \"/etc/sysconfig/network-scripts/ifcfg-$NIC\", \"contents\": {\"source\": \"data:text/plain;charset=utf-8;base64,$NICDATA\", \"verification\": {}}}]" > /root/ocp/bootstrap.ign
{% endif %}
openshift-baremetal-install --dir ocp --log-level debug create cluster || true
openshift-baremetal-install --dir ocp --log-level debug wait-for install-complete || openshift-baremetal-install --dir ocp --log-level debug wait-for install-complete
{% if virtual_masters %}
for node in $(oc get nodes --selector='node-role.kubernetes.io/master' -o name) ; do
  oc label $node node-role.kubernetes.io/virtual=""
done
{% endif %}
{% if wait_for_workers_number != None %}
TOTAL_WORKERS={{ wait_for_workers_number }}
{% else %}
TOTAL_WORKERS=$(grep 'role: worker' /root/install-config.yaml | wc -l) || true
{% endif %}
if [ "$TOTAL_WORKERS" -gt "0" ] ; then
CURRENT_WORKERS=$(oc get nodes --selector='node-role.kubernetes.io/worker' -o name | wc -l)
{% if wait_for_workers %}
 TIMEOUT=0
 WAIT_TIMEOUT={{ wait_for_workers_timeout }}
 until [ "$CURRENT_WORKERS" == "$TOTAL_WORKERS" ] ; do
  if [ "$TIMEOUT" -gt "$WAIT_TIMEOUT" ] ; then
    logger "Timeout waiting for Current workers number $CURRENT_WORKERS to match expected worker number $TOTAL_WORKERS"
    break
  fi
  CURRENT_WORKERS=$(oc get nodes --selector='node-role.kubernetes.io/worker' -o name | wc -l)
  logger "Waiting for all workers to show up..."
  sleep 5
  TIMEOUT=$(($TIMEOUT + 5))
 done
{% else %}
 if [ "$CURRENT_WORKERS" != "$TOTAL_WORKERS" ] ; then
  logger "Beware, Current workers number $CURRENT_WORKERS doesnt match expected worker number $TOTAL_WORKERS"
  sleep 5
 fi
{% endif %}
fi
