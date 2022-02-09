#!/usr/bin/env bash

set -euo pipefail

PRIMARY_NIC=$(ls -1 /sys/class/net | head -1)
export PATH=/root/bin:$PATH
export PULL_SECRET="/root/openshift_pull.json"
export IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
REGISTRY_NAME=$(echo $IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
REGISTRY_PORT={{ 8443 if disconnected_quay else 5000 }}

{% if version == 'ci' %}
export OPENSHIFT_RELEASE_IMAGE={{ openshift_image }}
{% elif version in ['nightly', 'stable'] %}
{% set tag = tag|string %}
{% if tag.split('.')|length > 2 %}
TAG={{ tag }}
{% elif version == 'nightly' %}
TAG={{"latest-" + tag }}
{% else %}
TAG={{"stable-" + tag }}
{% endif %}
OCP_REPO={{ 'ocp-dev-preview' if version == 'nightly' else 'ocp' }}
export OPENSHIFT_RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/$OCP_REPO/$TAG/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
{% else %}
export OPENSHIFT_RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/{{ version }}-{{ tag }}/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
{% endif %}
export LOCAL_REG="$REGISTRY_NAME:$REGISTRY_PORT"
export OCP_RELEASE=$(/root/bin/openshift-baremetal-install version | head -1 | cut -d' ' -f2)-x86_64
time oc adm release mirror -a $PULL_SECRET --from=$OPENSHIFT_RELEASE_IMAGE --to-release-image=${LOCAL_REG}/ocp4:${OCP_RELEASE} --to=${LOCAL_REG}/ocp4

if [ "$(grep imageContentSources /root/install-config.yaml)" == "" ] ; then
cat << EOF >> /root/install-config.yaml
imageContentSources:
- mirrors:
  - $REGISTRY_NAME:$REGISTRY_PORT/ocp4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
- mirrors:
  - $REGISTRY_NAME:$REGISTRY_PORT/ocp4
{% if version == 'ci' %}
  source: registry.ci.openshift.org/ocp/release
{% elif version == 'nightly' %}
  source: quay.io/openshift-release-dev/ocp-release-nightly
{% else %}
  source: quay.io/openshift-release-dev/ocp-release
{% endif %}
EOF
else
  IMAGECONTENTSOURCES="- mirrors:\n  - $REGISTRY_NAME:$REGISTRY_PORT/ocp4\n  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev\n- mirrors:\n  - $REGISTRY_NAME:$REGISTRY_PORT/ocp4\n  source: registry.ci.openshift.org/ocp/release"
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
echo $REGISTRY_NAME:$REGISTRY_PORT/ocp4:$OCP_RELEASE > /root/version.txt

if [ "$(grep pullSecret /root/install-config.yaml)" == "" ] ; then
PULLSECRET=$(cat /root/openshift_pull.json | tr -d [:space:])
echo -e "pullSecret: |\n  $PULLSECRET" >> /root/install-config.yaml
fi

cp /root/machineconfigs/99-operatorhub.yaml /root/manifests
