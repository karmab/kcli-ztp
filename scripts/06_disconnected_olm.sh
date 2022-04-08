#!/usr/bin/env bash

# Variables to set, suit to your installation
export RH_OP_PACKAGES=${RH_OP_PACKAGES:-{{ disconnected_operators|join(",") }}}
export CERT_OP_PACKAGES=${CERT_OP_PACKAGES:-{{ disconnected_certified_operators|join(",") }}}
export COMMUNITY_OP_PACKAGES=${COMMUNITY_OP_PACKAGES:-{{ disconnected_community_operators|join(",") }}}
export MARKETPLACE_OP_PACKAGES=${MARKETPLACE_OP_PACKAGES:-{{ disconnected_marketplace_operators|join(",") }}}
if [ -z $RH_OP_PACKAGES ] && [ -z $CERT_OP_PACKAGES ] [ -z $COMMUNITY_OP_PACKAGES ] && [ -z $MARKETPLACE_OP_PACKAGES ]; then
 echo You need one of the following env variables at least: RH_OP_PACKAGES CERT_OP_PACKAGES COMMUNITY_OP_PACKAGES MARKETPLACE_OP_PACKAGES
 exit 1
fi
cd /root
export PATH=/root/bin:$PATH
export OCP_RELEASE="$(/root/bin/openshift-baremetal-install version | head -1 | cut -d' ' -f2 | cut -d'.' -f 1,2)"
export OCP_PULLSECRET_AUTHFILE='/root/openshift_pull.json'
{% if disconnected_url != None %}
{% set registry_port = disconnected_url.split(':')[-1] %}
{% set registry_name = disconnected_url|replace(":" + registry_port, '') %}
REGISTRY_NAME={{ registry_name }}
REGISTRY_PORT={{ registry_port }}
{% else %}
PRIMARY_NIC=$(ls -1 /sys/class/net | grep 'eth\|en' | head -1)
IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
REGISTRY_NAME=$(echo $IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
REGISTRY_PORT={{ 8443 if disconnected_quay else 5000 }}
{% endif %}
export LOCAL_REGISTRY=$REGISTRY_NAME:$REGISTRY_PORT
export IMAGE_TAG=olm

# Add extra registry keys
curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv https://www.redhat.com/security/data/55A34A82.txt
jq ".transports.docker += {\"registry.redhat.io/redhat/certified-operator-index\": [{\"type\": \"signedBy\",\"keyType\": \"GPGKeys\",\"keyPath\": \"/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv\"}], \"registry.redhat.io/redhat/community-operator-index\": [{\"type\": \"signedBy\",\"keyType\": \"GPGKeys\",\"keyPath\": \"/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv\"}], \"registry.redhat.io/redhat/redhat-marketplace-operator-index\": [{\"type\": \"signedBy\",\"keyType\": \"GPGKeys\",\"keyPath\": \"/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv\"}]}" < /etc/containers/policy.json > /etc/containers/policy.json.new
mv /etc/containers/policy.json.new /etc/containers/policy.json

# Login registries
REGISTRY_USER={{ "init" if disconnected_quay else disconnected_user }}
REGISTRY_PASSWORD={{ "super" + disconnected_password if disconnected_quay and disconnected_password|length < 8 else disconnected_password }}
podman login -u $REGISTRY_USER -p $REGISTRY_PASSWORD $LOCAL_REGISTRY
#podman login registry.redhat.io --authfile /root/openshift_pull.json
REDHAT_CREDS=$(cat /root/openshift_pull.json | jq .auths.\"registry.redhat.io\".auth -r | base64 -d)
RHN_USER=$(echo $REDHAT_CREDS | cut -d: -f1)
RHN_PASSWORD=$(echo $REDHAT_CREDS | cut -d: -f2)
podman login -u "$RHN_USER" -p "$RHN_PASSWORD" registry.redhat.io

which opm >/dev/null 2>&1
if [ "$?" != "0" ] ; then
curl -k -s https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/opm-linux.tar.gz | tar xvz -C /usr/bin/
chmod u+x /usr/bin/opm
fi

export RH_OP_INDEX="registry.redhat.io/redhat/redhat-operator-index:v${OCP_RELEASE}"
export CERT_OP_INDEX="registry.redhat.io/redhat/certified-operator-index:v${OCP_RELEASE}"
export COMM_OP_INDEX="registry.redhat.io/redhat/community-operator-index:v${OCP_RELEASE}"
export MARKETPLACE_OP_INDEX="registry.redhat.io/redhat-marketplace-index:v${OCP_RELEASE}"

if [ ! -z $RH_OP_PACKAGES ] ; then
 export RH_INDEX_TAG=olm-index/redhat-operator-index:v$OCP_RELEASE
 time opm index prune --from-index $RH_OP_INDEX --packages $RH_OP_PACKAGES --tag $LOCAL_REGISTRY/$RH_INDEX_TAG
 podman push $LOCAL_REGISTRY/$RH_INDEX_TAG --authfile $OCP_PULLSECRET_AUTHFILE
 time oc adm catalog mirror $LOCAL_REGISTRY/$RH_INDEX_TAG $LOCAL_REGISTRY/$IMAGE_TAG --registry-config=$OCP_PULLSECRET_AUTHFILE --max-per-registry=100
 oc apply -f /root/manifests-redhat-operator-index-*/imageContentSourcePolicy.yaml 2>/dev/null || cp /root/manifests-redhat-operator-index-*/imageContentSourcePolicy.yaml /root/manifests/redhat-imageContentSourcePolicy.yaml
 oc apply -f /root/manifests-redhat-operator-index-*/catalogSource.yaml 2>/dev/null || cp /root/manifests-redhat-operator-index-*/catalogSource.yaml /root/manifests/redhat-catalogSource.yaml
fi

if [ ! -z $CERT_OP_PACKAGES ] ; then
 export CERT_INDEX_TAG=olm-index/certified-operator-index:v$OCP_RELEASE
 time opm index prune --from-index $CERT_OP_INDEX --packages $CERT_OP_PACKAGES --tag $LOCAL_REGISTRY/$CERT_INDEX_TAG
 podman push $LOCAL_REGISTRY/$CERT_INDEX_TAG --authfile $OCP_PULLSECRET_AUTHFILE
 time oc adm catalog mirror $LOCAL_REGISTRY/$CERT_INDEX_TAG $LOCAL_REGISTRY/$IMAGE_TAG --registry-config=$OCP_PULLSECRET_AUTHFILE --max-per-registry=100
 oc apply -f /root/manifests-certified-operator-index-*/imageContentSourcePolicy.yaml 2>/dev/null || cp /root/manifests-certified-operator-index-*/imageContentSourcePolicy.yaml /root/manifests/certified-imageContentSourcePolicy.yaml
 oc apply -f /root/manifests-certified-operator-index-*/catalogSource.yaml 2>/dev/null || cp /root/manifests-certified-operator-index-*/catalogSource.yaml /root/manifests/certified-catalogSource.yaml
fi

if [ ! -z $COMM_OP_PACKAGES ] ; then
 export COMM_INDEX_TAG=olm-index/community-operator-index:v$OCP_RELEASE
 time opm index prune --from-index $COMM_OP_INDEX --packages $COMM_OP_PACKAGES --tag $LOCAL_REGISTRY/$COMM_INDEX_TAG
 podman push $LOCAL_REGISTRY/$COMM_INDEX_TAG --authfile $OCP_PULLSECRET_AUTHFILE
 time oc adm catalog mirror $LOCAL_REGISTRY/$COMM_INDEX_TAG $LOCAL_REGISTRY/$IMAGE_TAG --registry-config=$OCP_PULLSECRET_AUTHFILE --max-per-registry=100
 oc apply -f /root/manifests-community-operator-index-*/imageContentSourcePolicy.yaml 2>/dev/null || cp /root/manifests-community-operator-index-*/imageContentSourcePolicy.yaml /root/manifests/community-imageContentSourcePolicy.yaml
 oc apply -f /root/manifests-community-operator-index-*/catalogSource.yaml 2>/dev/null || cp /root/manifests-community-operator-index-*/catalogSource.yaml /root/manifests/community-catalogSource.yaml
fi

if [ ! -z $MARKETPLACE_OP_PACKAGES ] ; then
 export MARKETPLACE_INDEX_TAG=olm-index/redhat-marketplace-operator-index:v$OCP_RELEASE
 time opm index prune --from-index $MARKETPLACE_OP_INDEX --packages $MARKETPLACE_OP_PACKAGES --tag $LOCAL_REGISTRY/$MARKETPLACE_INDEX_TAG
 podman push $LOCAL_REGISTRY/$MARKETPLACE_INDEX_TAG --authfile $OCP_PULLSECRET_AUTHFILE
 time oc adm catalog mirror $LOCAL_REGISTRY/$MARKETPLACE_INDEX_TAG $LOCAL_REGISTRY/$IMAGE_TAG --registry-config=$OCP_PULLSECRET_AUTHFILE --max-per-registry=100
 oc apply -f /root/manifests-redhat-marketplace-operator-index-*/imageContentSourcePolicy.yaml 2>/dev/null || cp /root/manifests-redhat-marketplace-operator-index-*/imageContentSourcePolicy.yaml /root/manifests/redhat-marketplace-imageContentSourcePolicy.yaml
 oc apply -f /root/manifests-redhat-marketplace-operator-index-*/catalogSource.yaml 2>/dev/null || cp /root/manifests-redhat-marketplace-operator-index-*/catalogSource.yaml /root/manifests/redhat-marketplace-catalogSource.yaml
fi
