export HOME=/root
export PYTHONUNBUFFERED=true
{% for spoke in ztp_spokes %}
{% set spoke_deploy = spoke.get('deploy', ztp_spoke_deploy) %}
{% set spoke_ctlplanes_number = spoke.get('ctlplanes_number', 1) %}
{% set spoke_workers_number = spoke.get('workers_number', 0) %}
{% if spoke_deploy and spoke.get('wait', ztp_spoke_wait) %}
{% set spoke_wait_time = spoke.get('wait_time', ztp_spoke_wait_time) %}
SPOKE={{ spoke.name }}

# SNOPLUS HANDLING
if [ -f /root/ztp/scripts/extra_bmc_$SPOKE.yml ] ; then
  BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
  echo $BAREMETAL_IP | grep -q ':' && BAREMETAL_IP=[$BAREMETAL_IP]
  sed -i s/CHANGEME/$BAREMETAL_IP/ /root/ztp/scripts/extra_bmc_$SPOKE.yml
  oc create -f /root/ztp/scripts/extra_bmc_$SPOKE.yml
  timeout=0
  installed=false
  while [ "$timeout" -lt "{{ spoke_wait_time }}" ] ; do
    AGENTS=$(oc get agent -n $SPOKE -o jsonpath="{range .items[?(@.status.progress.currentStage==\"Done\")]}{.metadata.name}{'\n'}{end}" | wc -l)
    [ "$AGENTS" == "2" ] && installed=true && break;
    echo "Waiting for extra worker to be deployed in spoke $SPOKE"
    sleep 60
    timeout=$(($timeout + 5))
  done
  if [ "$installed" == "true" ] ; then
    echo "Extra worker deployed in spoke $SPOKE"
  else
    echo Timeout waiting for extra worker in $SPOKE to be deployed
  fi
fi

{% endif %}
{% endfor %}
