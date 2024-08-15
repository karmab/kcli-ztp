OCP_RELEASE=$(openshift-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)

mkdir -p /root/.config/kustomize/plugin
export HOME=/root
REDHAT_CREDS=$(cat /root/openshift_pull.json | jq .auths.\"registry.redhat.io\".auth -r | base64 -d)
RHN_USER=$(echo $REDHAT_CREDS | cut -d: -f1)
RHN_PASSWORD=$(echo $REDHAT_CREDS | cut -d: -f2)
podman login -u "$RHN_USER" -p "$RHN_PASSWORD" registry.redhat.io
podman cp $(podman create --name policgentool --rm registry.redhat.io/openshift4/ztp-site-generate-rhel8:v$MINOR):/kustomize/plugin/ran.openshift.io /root/.config/kustomize/plugin/

oc kustomize /root/ztp/scripts --enable-alpha-plugins > /root/spokes.yml
