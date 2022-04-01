#!/usr/bin/env bash

{% if acm_downstream %}
echo "************ RUNNING acm_downstream.sh ************"
bash /root/ztp/acm/downstream.sh
{% endif %}

RHCOS_ISO=$(/root/bin/openshift-baremetal-install coreos print-stream-json | jq -r '.["architectures"]["x86_64"]["artifacts"]["metal"]["formats"]["iso"]["disk"]["location"]')
RHCOS_ROOTFS=$(/root/bin/openshift-baremetal-install coreos print-stream-json | jq -r '.["architectures"]["x86_64"]["artifacts"]["metal"]["formats"]["pxe"]["rootfs"]["location"]')
curl -Lk $RHCOS_ISO > /var/www/html/rhcos-live.x86_64.iso
curl -Lk $RHCOS_ROOTFS > /var/www/html/rhcos-live-rootfs.x86_64.img

{% if acm %}
tasty install advanced-cluster-management --wait
oc create -f /root/ztp/acm/cr.yml
until oc get crd/agentserviceconfigs.agent-install.openshift.io >/dev/null 2>&1 ; do sleep 1 ; done
{% else %}
oc create -f /root/ztp/acm/ai_install.yml
{% endif %}

OCP_RELEASE=$(/root/bin/openshift-baremetal-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)
BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)

{% if disconnected %}
export CA_CERT=$(cat /opt/registry/certs/domain.crt | sed "s/^/    /")
REGISTRY_NAME=$(echo $BAREMETAL_IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
LOCAL_PORT={{ 8443 if disconnected_quay else 5000 }}
export LOCAL_REGISTRY=${REGISTRY_NAME}:$LOCAL_PORT
export RELEASE=$LOCAL_REGISTRY/ocp4:$OCP_RELEASE
python3 /root/ztp/acm/gen_registries.py > /root/registries.txt
export REGISTRIES=$(cat /root/registries.txt)
{% elif version == 'ci' %}
export RELEASE={{ openshift_image }}
{% elif version == 'nightly' %}
export RELEASE=quay.io/openshift-release-dev/ocp-release-nightly:$OCP_RELEASE
{% elif version in ['latest', 'stable'] %}
export RELEASE=quay.io/openshift-release-dev/ocp-release:$OCP_RELEASE
{% endif %}

echo $BAREMETAL_IP | grep -q ':' && BAREMETAL_IP=[$BAREMETAL_IP]
export BAREMETAL_IP
export PULLSECRET=$(cat /root/openshift_pull.json | tr -d [:space:])
export SSH_PRIV_KEY=$(cat /root/.ssh/id_rsa |sed "s/^/    /")
export VERSION=$(/root/bin/openshift-baremetal-install coreos print-stream-json | jq -r '.["architectures"]["x86_64"]["artifacts"]["metal"]["release"]')

envsubst < /root/ztp/acm/assisted-service.sample.yml > /root/ztp/acm/assisted-service.yml
oc create -f /root/ztp/acm/assisted-service.yml
