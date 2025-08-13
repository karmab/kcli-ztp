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
SPOKE={{ spoke.name }}
{% if spoke.get('virtual_nodes', 0) > 0 %}
kcli delete iso -y $SPOKE.iso || true
{% endif %}
{% endfor %}

[ -d /root/spokes ]] || mkdir /root/spokes
envsubst < /root/ztp/scripts/requirements_$SPOKE.sample.yaml > /spokes/requirements_$SPOKE.yaml
envsubst < /root/ztp/scripts/clusterinstance_$SPOKE.sample.yaml > /spokes/clusterinstance_$SPOKE.yaml

if [ -f /root/ztp/scripts/snoplus.txt ] && [ "grep $SPOKE /root/ztp/scripts/snoplus.txt" != "" ] ; then
  sed -i "/$SPOKE-node-1/,$ s/^/##/" /spoke/clusterinstances.yaml
fi

bash /root/ztp/scripts/generate_gitops.sh
oc apply -k /root/ztp/scripts/gitops
