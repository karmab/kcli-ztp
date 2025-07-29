export HOME=/root
export PYTHONUNBUFFERED=true
HUB={{ cluster }}
OCP_RELEASE=$(openshift-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)
export PULLSECRET=$(cat /root/openshift_pull.json | tr -d [:space:])
export DOMAIN={{ domain }}
export SSH_PUB_KEY=$(cat /root/.ssh/id_rsa.pub)
BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
echo $BAREMETAL_IP | grep -q ':' && BAREMETAL_IP=[$BAREMETAL_IP]
export BAREMETAL_IP

{% for spoke in spokes %}
{% if spoke.get('virtual_nodes', 0) > 0 %}
kcli delete iso -y {{ spoke.name }}.iso || true
{% endif %}
{% endfor %}


envsubst < /root/ztp/scripts/requirements.sample.yml > /root/ztp/scripts/requirements.yml
envsubst < /root/ztp/scripts/clusterinstances.sample.yml > /root/ztp/scripts/clusterinstances.yml

if [ -f /root/ztp/scripts/snoplus.txt ] ; then
  for SPOKE in $(cat /root/ztp/scripts/snoplus.txt) ; do
    sed -i "/$SPOKE-node-1/,$ s/^/##/" /root/ztp/scripts/clusterinstances.yml
  done
fi

bash /root/ztp/scripts/generate_gitops.sh
oc apply -k /root/ztp/scripts/gitops
