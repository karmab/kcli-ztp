#!/usr/bin/env bash

echo export SPOKE={{ ztp_spoke_name }} >> /root/.bashrc
OCP_RELEASE=$(/root/bin/openshift-baremetal-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)
export PULLSECRET=$(cat /root/openshift_pull.json | tr -d [:space:])
export SPOKE={{ ztp_spoke_name }}
export DOMAIN={{ domain }}
export MASTERS_NUMBER={{ ztp_spoke_masters_number }}
export WORKERS_NUMBER={{ ztp_spoke_workers_number }}
export SSH_PUB_KEY=$(cat /root/.ssh/id_rsa.pub)
envsubst < /root/ztp_spoke.sample.yml > /root/ztp_spoke.yml
oc create -f /root/ztp_spoke.yml

bash /root/ztp_bmc.sh
{% if ztp_spoke_wait %}
timeout=0
completed=false
failed=false
while [ "$timeout" -lt "{{ ztp_spoke_wait_time }}" ] ; do
  MSG=$(oc get agentclusterinstall -n $SPOKE $SPOKE -o jsonpath={'.status.conditions[-1].message'})
  echo $MSG | grep completed && completed=true && break;
  echo $MSG | grep failed && failed=true && break;
  echo "Waiting for spoke cluster to be deployed"
  sleep 60
  timeout=$(($timeout + 5))
done
if [ "$completed" == "true" ] ; then
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
