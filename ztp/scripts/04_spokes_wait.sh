export HOME=/root
export PYTHONUNBUFFERED=true
{% for spoke in spokes %}
{% set ibi = spoke.get('ibi', False) %}
{% set ctlplanes_number = spoke.get('ctlplanes', 1) %}
{% set workers_number = spoke.get('workers', 0) %}
{% set seed = ctlplanes_number == 1 and workers_number == 0 and spoke.get('seed', False) %}
{% if not ibi and spoke.get('wait', spoke_wait) %}
{% set wait_time = spoke.get('wait_time', spoke_wait_time) %}
SPOKE={{ spoke.name }}
timeout=0
installed=false
while [ "$timeout" -lt "{{ wait_time }}" ] ; do
  [ "$(oc get clusterinstance -n $SPOKE $SPOKE -o jsonpath='{.status.conditions[?(@.type=="Provisioned")].status}')" == "True" ]  && installed=true && break;
  echo Waiting for spoke cluster $SPOKE to be deployed
  sleep 60
  timeout=$(($timeout + 60))
done
if [ "$installed" == "true" ] ; then
  echo Spoke cluster $SPOKE deployed
  oc get secret -n $SPOKE $SPOKE-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > /root/kubeconfig.$SPOKE
{% if ctlplanes_number == 1 %}
{% if ':' in baremetal_cidr %}
  IP=$(oc get -n $SPOKE $(oc get agent -n $SPOKE -o name) -o jsonpath={'.status.inventory.interfaces[0].ipV6Addresses[0]'} | cut -d/ -f1)
{% else %}
  IP=$(oc get -n $SPOKE $(oc get agent -n $SPOKE -o name) -o jsonpath={'.status.inventory.interfaces[0].ipV4Addresses[0]'} | cut -d/ -f1)
{% endif %}
  echo ${IP} api.$SPOKE.{{ domain }} >> /etc/hosts
{% endif %}
else
  echo Timeout waiting for spoke cluster $SPOKE to be deployed
fi
{% endif %}
{% endfor %}
