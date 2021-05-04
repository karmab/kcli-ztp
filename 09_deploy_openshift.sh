#!/usr/bin/env bash

set -euo pipefail

cd /root
export PATH=/root/bin:$PATH
export HOME=/root
export KUBECONFIG=/root/ocp/auth/kubeconfig
export OS_CLOUD=metal3-bootstrap
export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=$(cat /root/version.txt)
bash /root/bin/clean.sh
mkdir -p ocp/openshift
python3 /root/bin/ipmi.py off
python3 /root/bin/redfish.py off
cp install-config.yaml ocp
openshift-baremetal-install --dir ocp --log-level debug create manifests
cp manifests/*y*ml >/dev/null 2>&1 ocp/openshift || true
TOTAL_WORKERS=$(grep 'role: worker' /root/install-config.yaml | wc -l) || true
# [ "$TOTAL_WORKERS" -gt "0" ] || cp 99-openshift-ingress-controller-master.yaml ocp/openshift
echo {{ api_ip }} api.{{ cluster }}.{{ domain }} >> /etc/hosts
openshift-baremetal-install --dir ocp --log-level debug create cluster || true
openshift-baremetal-install --dir ocp --log-level debug wait-for install-complete || openshift-baremetal-install --dir ocp --log-level debug wait-for install-complete
{% if virtual_masters %}
for node in $(oc get nodes --selector='node-role.kubernetes.io/master' -o name) ; do
  oc label $node node-role.kubernetes.io/virtual=""
done
{% endif %}
export OS_CLOUD=metal3
if [ "$TOTAL_WORKERS" -gt "0" ] ; then
 until [ "$CURRENT_WORKERS" == "$TOTAL_WORKERS" ] ; do
  CURRENT_WORKERS=$(oc get nodes --selector='node-role.kubernetes.io/worker' -o name | wc -l)
  logger "Waiting for all workers to show up..."
  sleep 5
done
fi
