#!/usr/bin/env bash

export HOME=/root
cd $HOME
export PATH=/root/bin:$PATH

REGISTRY_PORT=5000
REGISTRY_USER={{ disconnected_user }}
REGISTRY_PASSWORD={{ disconnected_password }}

{% if disconnected_url != None %}
{% set registry_port = disconnected_url.split(':')[-1] %}
{% set registry = disconnected_url.split(':')[0] %}
REGISTRY={{ registry }}
REGISTRY_PORT={{ registry_port }}
mkdir -p /opt/registry/certs
openssl s_client -showcerts -connect $REGISTRY:$REGISTRY_PORT </dev/null 2>/dev/null|openssl x509 -outform PEM > /opt/registry/certs/domain.crt
cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors
update-ca-trust extract
{% elif dns %}
REGISTRY=registry.{{ cluster }}.{{ domain }}
{% else %}
IP=$(ip -o addr show eth0 | grep -v '169.254\|fe80::' | tail -1 | awk '{print $4}' | cut -d'/' -f1)
REGISTRY=$(echo $IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
{% endif %}

KEY=$(echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | base64)
mv /root/openshift_pull.json /root/openshift_pull.json.old
jq ".auths += {\"$REGISTRY:$REGISTRY_PORT\": {\"auth\": \"$KEY\",\"email\": \"jhendrix@karmalabs.corp\"}}" < /root/openshift_pull.json.old > /root/openshift_pull.json

# Add extra registry keys
curl -Lo /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv https://www.redhat.com/security/data/55A34A82.txt
jq ".transports.docker += {\"registry.redhat.io/redhat/certified-operator-index\": [{\"type\": \"signedBy\",\"keyType\": \"GPGKeys\",\"keyPath\": \"/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv\"}], \"registry.redhat.io/redhat/community-operator-index\": [{\"type\": \"signedBy\",\"keyType\": \"GPGKeys\",\"keyPath\": \"/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv\"}], \"registry.redhat.io/redhat/redhat-marketplace-operator-index\": [{\"type\": \"signedBy\",\"keyType\": \"GPGKeys\",\"keyPath\": \"/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv\"}]}" < /etc/containers/policy.json > /etc/containers/policy.json.new
mv /etc/containers/policy.json.new /etc/containers/policy.json

{% if version == 'ci' %}
export OCP_RELEASE={{ tag }}

{% elif version in ['nightly', 'stable'] %}

{% set tag = tag|string %}
{% if tag.split('.')|length > 2 %}
TAG={{ tag }}
{% else %}
{% set prefix = 'latest' if version == 'nightly' else 'stable' %}
TAG={{ prefix + '-' + tag }}
{% endif %}
curl -Ls https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$TAG/release.txt > /tmp/release.txt
OCP_RELEASE=$(grep 'Name:' /tmp/release.txt | awk -F ' ' '{print $2}')-x86_64

{% elif version == 'candidate' %}
curl -Ls https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/{{ tag }}/release.txt > /tmp/release.txt
OCP_RELEASE=$(grep 'Name:' /tmp/release.txt | awk -F ' ' '{print $2}')-x86_64
{% endif %}

{% if version == 'ci' %}
{% set namespace = 'ocp/release' %}
{% else %}
{% set namespace = 'openshift/release-images' %}
{% endif %}
NAMESPACE={{ namespace }}
echo $REGISTRY:$REGISTRY_PORT/$NAMESPACE:$OCP_RELEASE > /root/version.txt

REGISTRY_USER={{ disconnected_user }}
REGISTRY_PASSWORD={{ disconnected_password }}
podman login -u $REGISTRY_USER -p $REGISTRY_PASSWORD $REGISTRY:$REGISTRY_PORT
REDHAT_CREDS=$(cat /root/openshift_pull.json | jq .auths.\"registry.redhat.io\".auth -r | base64 -d)
RHN_USER=$(echo $REDHAT_CREDS | cut -d: -f1)
RHN_PASSWORD=$(echo $REDHAT_CREDS | cut -d: -f2)
podman login -u "$RHN_USER" -p "$RHN_PASSWORD" registry.redhat.io

which oc-mirror >/dev/null 2>&1
if [ "$?" != "0" ] ; then
  OPENSHIFT_TAG=4.19
  curl -Ls https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-$OPENSHIFT_TAG/oc-mirror.tar.gz | tar xvz -C /usr/bin
  chmod +x /usr/bin/oc-mirror
fi

mkdir -p /root/.docker
cp -f /root/openshift_pull.json /root/.docker/config.json

oc-mirror --v2 --workspace file:// --config=mirror-config.yaml docker://$REGISTRY:$REGISTRY_PORT

sed -i 's@quay.io/prega/test@registry.redhat.io@' /root/working-dir/cluster-resources/idms-oc-mirror.yaml

cp /root/working-dir/cluster-resources/{cs*,*oc-mirror*} /root
python -c "from kvirt.cluster.openshift import patch_oc_mirror ; patch_oc_mirror('/root')"
mv /root/{cs*,*oc-mirror*} /root/manifests

sed -i "s/REGISTRY:PORT/$REGISTRY:$REGISTRY_PORT/" /root/install-config.yaml

if [ "$(grep additionalTrustBundle /root/install-config.yaml)" == "" ] ; then
  echo "additionalTrustBundle: |" >> /root/install-config.yaml
  sed -e 's/^/  /' /opt/registry/certs/domain.crt >>  /root/install-config.yaml
else
  LOCAL_CERT="-----BEGIN CERTIFICATE-----\n $(grep -v CERTIFICATE /opt/registry/certs/domain.crt | tr -d '[:space:]')\n -----END CERTIFICATE-----"
  sed -i "/additionalTrustBundle/a${LOCAL_CERT}" /root/install-config.yaml
  sed -i 's/^-----BEGIN/ -----BEGIN/' /root/install-config.yaml
fi

if [ "$(grep pullSecret /root/install-config.yaml)" == "" ] ; then
  echo "{\"auths\": {\"$REGISTRY:5000\": {\"auth\": \"$KEY\", \"email\": \"jhendrix@karmalabs.corp\"}}}" > /root/disconnected_pull.json
  DISCONNECTED_PULLSECRET=$(cat /root/disconnected_pull.json | tr -d [:space:])
  echo -e "pullSecret: |\n  $DISCONNECTED_PULLSECRET" >> /root/install-config.yaml
fi

cp /root/machineconfigs/99-operatorhub.yaml /root/manifests

oc adm release extract --registry-config /root/openshift_pull.json --command=openshift-install --to /root/bin $(cat /root/version.txt)
