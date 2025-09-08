export HOME=/root
export PYTHONUNBUFFERED=true
for SPOKE in $(cat /root/ztp/scripts/ibis.txt) ; do
timeout=0
installed=false
while [ "$timeout" -lt "1800" ] ; do
  [ "$(oc get clusterinstance -n $SPOKE $SPOKE -o jsonpath='{.status.conditions[?(@.type=="Provisioned")].status}')" == "True" ]  && installed=true && break;
  echo Waiting for spoke cluster $SPOKE to be deployed
  sleep 60
  timeout=$(($timeout + 60))
done
if [ "$installed" == "true" ] ; then
  echo Cluster $SPOKE deployed
  oc get secret -n $SPOKE $SPOKE-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > /root/kubeconfig.$SPOKE
{% if ':' in baremetal_cidr %}
  IP=$(oc get clusterinstance -n $SPOKE $SPOKE -o jsonpath='{.spec.nodes[0].nodeNetwork.config.interfaces[0].ipv6.address[0].ip}')
{% else %}
  IP=$(oc get clusterinstance -n $SPOKE $SPOKE -o jsonpath='{.spec.nodes[0].nodeNetwork.config.interfaces[0].ipv4.address[0].ip}')
{% endif %}
  echo $IP api.$SPOKE.{{ domain }} >> /etc/hosts
else
  echo Timeout waiting for spoke cluster $SPOKE to be deployed
fi
done
