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
[ -d /root/spokes ] || mkdir /root/spokes
envsubst < /root/ztp/scripts/requirements_$SPOKE.sample.yaml > /root/spokes/requirements_$SPOKE.yaml
envsubst < /root/ztp/scripts/clusterinstance_$SPOKE.sample.yaml > /root/spokes/clusterinstance_$SPOKE.yaml
{% endfor %}

kcli create app openshift-gitops-operator
kcli create app topology-aware-lifecycle-manager
sleep 120
cd /root/ztp/scripts/gitops
OCP_RELEASE=$(openshift-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)
ACM_CSV=$(oc get subscriptions.operators.coreos.com -n open-cluster-management advanced-cluster-management -o jsonpath='{.status.currentCSV}')
export ACM_SHA=$(oc get csv -n open-cluster-management $ACM_CSV -o json | jq -r '.spec.relatedImages[] | select(.name == "multicluster_operators_subscription") | .image' |cut -d'@' -f2)

{% if dns and disconnected %}
GIT_SERVER=registry.{{ cluster }}.{{ domain }}
{% else %}
PRIMARY_NIC=$(ls -1 /sys/class/net | grep -v podman | head -1)
IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
GIT_SERVER=$(echo $IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
{% endif %}

GIT_USER={{ gitops_user }}
export REPO_URL=http://$GIT_SERVER:3000/karmalabs/ztp
export REPO_BRANCH=main
export CLUSTERS_APP_PATH=site-configs
export POLICIES_APP_PATH=site-policies
export HUB={{ cluster }}

{% if disconnected %}
export REGISTRY=$GIT_SERVER:5000
{% else %}
export REGISTRY=registry.redhat.io
{% endif %}

envsubst < openshift-gitops-patch.json.template > openshift-gitops-patch.json
rm openshift-gitops-patch.json.template
oc patch argocd openshift-gitops -n openshift-gitops --type=merge --patch-file openshift-gitops-patch.json
envsubst < clusters-app.yaml.template > clusters-app.yaml
rm clusters-app.yaml.template
if [ -d /root/ztp/scripts/site-policies ] ; then
  envsubst < policies-app.yaml.template > policies-app.yaml
  rm policies-app.yaml.template
else
  sed -i /policies-app-project.yaml/d kustomization.yaml
  sed -i /policies-app.yaml/d kustomization.yaml
fi

cd /root/git
mkdir -p site-configs/$HUB
touch site-configs/$HUB/.gitkeep
cp /root/ztp/scripts/kustomization.yaml site-configs
mv /root/spokes/requirements_*.yaml site-configs/$HUB
mv /root/spokes/clusterinstance_*.yaml site-configs/$HUB
if [ -d /root/ztp/scripts/site-policies ] ; then
  if [ "$REGISTRY" != "registry.redhat.io" ] ; then
    sed -i "s/image: registry.redhat.io/image: $REGISTRY/" /root/ztp/scripts/site-policies/*
  fi
  cp -r /root/ztp/scripts/site-policies .
fi
git config --global user.name "Jimi Hendrix"
git add --all
git commit -m 'Initial spokes'
git push origin main

oc apply -k /root/ztp/scripts/gitops
