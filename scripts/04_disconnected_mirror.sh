#!/usr/bin/env bash

set -euo pipefail

PRIMARY_NIC=$(ls -1 /sys/class/net | grep 'eth\|en' | head -1)
export IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
export PATH=/root/bin:$PATH
export PULL_SECRET="/root/openshift_pull.json"
{% if disconnected_url != None %}
{% set registry_port = disconnected_url.split(':')[-1] %}
{% set registry_name = disconnected_url|replace(":" + registry_port, '') %}
REGISTRY_NAME={{ registry_name }}
REGISTRY_PORT={{ registry_port }}
REGISTRY_USER={{ disconnected_user }}
REGISTRY_PASSWORD={{ disconnected_password }}
KEY=$(echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | base64)
echo "{\"auths\": {\"$REGISTRY_NAME:$REGISTRY_PORT\": {\"auth\": \"$KEY\", \"email\": \"jhendrix@karmalabs.corp\"}}}" > /root/disconnected_pull.json
mv /root/openshift_pull.json /root/openshift_pull.json.old
jq ".auths += {\"$REGISTRY_NAME:$REGISTRY_PORT\": {\"auth\": \"$KEY\",\"email\": \"jhendrix@karmalabs.corp\"}}" < /root/openshift_pull.json.old > $PULL_SECRET
mkdir -p /opt/registry/certs
openssl s_client -showcerts -connect $REGISTRY_NAME:$REGISTRY_PORT </dev/null 2>/dev/null|openssl x509 -outform PEM > /opt/registry/certs/domain.crt
cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors
update-ca-trust extract
{% else %}
REGISTRY_NAME={{ "registry.%s.%s" % (cluster, domain) if dns else "$(echo $IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io" }}
REGISTRY_PORT=5000
{% endif %}

export OPENSHIFT_RELEASE_IMAGE=$(openshift-install version | grep 'release image' | awk -F ' ' '{print $3}')
export LOCAL_REG="$REGISTRY_NAME:$REGISTRY_PORT"
export OCP_RELEASE=$(openshift-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)
oc adm release mirror -a $PULL_SECRET --from=$OPENSHIFT_RELEASE_IMAGE --to-release-image=${LOCAL_REG}/openshift/release-images:${OCP_RELEASE} --to=${LOCAL_REG}/openshift/release

{% for release in disconnected_extra_releases %}
EXTRA_OCP_RELEASE={{ release.split(':')[1] }}
oc adm release mirror -a $PULL_SECRET --from={{ release }} --to-release-image=${LOCAL_REG}/openshift/release-images:${EXTRA_OCP_RELEASE} --to=${LOCAL_REG}/openshift/release
{% endfor %}

if [ "$(grep imageContentSources /root/install-config.yaml)" == "" ] ; then
cat << EOF >> /root/install-config.yaml
imageContentSources:
- mirrors:
  - $REGISTRY_NAME:$REGISTRY_PORT/openshift/release
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
- mirrors:
  - $REGISTRY_NAME:$REGISTRY_PORT/openshift/release-images
{% if version == 'ci' %}
  source: registry.ci.openshift.org/ocp/release
{% elif version == 'nightly' %}
  source: quay.io/openshift-release-dev/ocp-release-nightly
{% else %}
  source: quay.io/openshift-release-dev/ocp-release
{% endif %}
EOF
else
  IMAGECONTENTSOURCES="- mirrors:\n  - $REGISTRY_NAME:$REGISTRY_PORT/openshift/release\n  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev\n- mirrors:\n  - $REGISTRY_NAME:$REGISTRY_PORT/openshift/release-images\n  source: registry.ci.openshift.org/ocp/release"
  sed -i "/imageContentSources/a${IMAGECONTENTSOURCES}" /root/install-config.yaml
fi

if [ "$(grep additionalTrustBundle /root/install-config.yaml)" == "" ] ; then
  echo "additionalTrustBundle: |" >> /root/install-config.yaml
  sed -e 's/^/  /' /opt/registry/certs/domain.crt >>  /root/install-config.yaml
else
  LOCALCERT="-----BEGIN CERTIFICATE-----\n $(grep -v CERTIFICATE /opt/registry/certs/domain.crt | tr -d '[:space:]')\n -----END CERTIFICATE-----"
  sed -i "/additionalTrustBundle/a${LOCALCERT}" /root/install-config.yaml
  sed -i 's/^-----BEGIN/ -----BEGIN/' /root/install-config.yaml
fi
echo $REGISTRY_NAME:$REGISTRY_PORT/openshift/release-images:$OCP_RELEASE > /root/version.txt

if [ "$(grep pullSecret /root/install-config.yaml)" == "" ] ; then
DISCONNECTED_PULLSECRET=$(cat /root/disconnected_pull.json | tr -d [:space:])
echo -e "pullSecret: |\n  $DISCONNECTED_PULLSECRET" >> /root/install-config.yaml
fi

cp /root/machineconfigs/99-operatorhub.yaml /root/manifests

SITE_GENERATE_TAG={{ '4.17' if version in ['candidate', 'ci'] else '$MINOR' }}
{% for image in disconnected_extra_images + ['quay.io/edge-infrastructure/assisted-installer-agent:latest', 'quay.io/edge-infrastructure/assisted-installer:latest', 'quay.io/edge-infrastructure/assisted-installer-controller:latest', 'registry.redhat.io/rhel9/support-tools', 'quay.io/mavazque/gitea:1.17.3', 'registry.redhat.io/openshift4/ztp-site-generate-rhel8:v$SITE_GENERATE_TAG' ] %}
echo "Syncing image {{ image }}"
/root/bin/sync_image.sh {{ image }}
{% endfor %}

oc adm release extract --registry-config /root/openshift_pull.json --command=openshift-install --to . $REGISTRY_NAME:$REGISTRY_PORT/openshift/release-images:$OCP_RELEASE --insecure
mv -f openshift-install /bin

## TEMP HACK
export RHCOS_ISO=$(openshift-install coreos print-stream-json | jq -r '.["architectures"]["x86_64"]["artifacts"]["metal"]["formats"]["iso"]["disk"]["location"]')
export RHCOS_ROOTFS=$(openshift-install coreos print-stream-json | jq -r '.["architectures"]["x86_64"]["artifacts"]["metal"]["formats"]["pxe"]["rootfs"]["location"]')
curl -Lk $RHCOS_ISO > /var/www/html/rhcos-live.x86_64.iso
curl -Lk $RHCOS_ROOTFS > /var/www/html/rhcos-live-rootfs.x86_64.img
