OCP_RELEASE=$(/root/bin/openshift-baremetal-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)
export PULLSECRET=$(cat /root/openshift_pull.json | tr -d [:space:])
export DOMAIN={{ domain }}
export SSH_PUB_KEY=$(cat /root/.ssh/id_rsa.pub)
BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
echo $BAREMETAL_IP | grep -q ':' && BAREMETAL_IP=[$BAREMETAL_IP]
export BAREMETAL_IP
envsubst < /root/ztp/scripts/siteconfig_requirements.sample.yml > /root/spokes.yml
envsubst < /root/ztp/scripts/siteconfig.sample.yml > /root/ztp/scripts/siteconfig.yml

mkdir -p /root/.config/kustomize/plugin
export HOME=/root
podman cp $(podman create --name policgentool --rm registry.redhat.io/openshift4/ztp-site-generate-rhel8:v$MINOR):/kustomize/plugin/ran.openshift.io /root/.config/kustomize/plugin/

oc kustomize /root/ztp/scripts --enable-alpha-plugins >> /root/spokes.yml
