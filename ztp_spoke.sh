#!/usr/bin/env bash

echo export SPOKE={{ ztp_spoke_name }} >> /root/.bashrc
{% if ztp_spoke_masters_number > 1 and ztp_spoke_api_ip != None and ztp_spoke_ingress_ip != None %}
echo {{ ztp_spoke_api_ip}} api.{{ ztp_spoke_name }}.{{ domain }} >> /etc/hosts
{% endif %}
OCP_RELEASE=$(/root/bin/openshift-baremetal-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)
export PULLSECRET=$(cat /root/openshift_pull.json | tr -d [:space:])
export SPOKE={{ ztp_spoke_name }}
export DOMAIN={{ domain }}
export MASTERS_NUMBER={{ ztp_spoke_masters_number }}
export WORKERS_NUMBER={{ ztp_spoke_workers_number }}
export SSH_PUB_KEY=$(cat /root/.ssh/id_rsa.pub)
mkdir /root/$SPOKE
{% if 'ztp_spoke_manifests'|find_manifests %}
bash /root/ztp_spoke_manifests.sh
envsubst < /root/ztp_spoke_manifests.yml > /root/$SPOKE/ztp_spoke.yml
{% endif %}
envsubst < /root/ztp_spoke.sample.yml >> /root/$SPOKE/ztp_spoke.yml
oc apply -f /root/$SPOKE/ztp_spoke.yml

bash /root/ztp_bmc.sh
{% if ztp_spoke_wait %}
timeout=0
installed=false
failed=false
while [ "$timeout" -lt "{{ ztp_spoke_wait_time }}" ] ; do
  MSG=$(oc get agentclusterinstall -n $SPOKE $SPOKE -o jsonpath={'.status.conditions[-1].message'})
  INFO=$(oc get  agentclusterinstall  -n mgmt-spoke1 mgmt-spoke1  -o jsonpath={'.status.debugInfo.stateInfo'})
  echo $INFO | grep installed && installed=true && break;
  echo $MSG | grep failed && failed=true && break;
  echo "Waiting for spoke cluster to be deployed"
  sleep 60
  timeout=$(($timeout + 5))
done
if [ "$installed" == "true" ] ; then
 echo "Cluster deployed"
 oc get secret -n $SPOKE $SPOKE-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > /root/kubeconfig.$SPOKE
elif [ "$failed" == "true" ] ; then
 echo Hit issue during deployment
 echo message: $MSG
 exit 1
else
 echo Timeout waiting for spoke cluster to be deployed
 exit 1
fi
{% endif %}
