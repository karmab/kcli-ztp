#!/usr/bin/env bash

{% if acm_downstream %}
echo "************ RUNNING acm_downstream.sh ************"
bash /root/acm_downstream.sh
{% endif %}

#RHCOS_ISO=$(/root/bin/openshift-baremetal-install coreos print-stream-json | jq -r '.["architectures"]["x86_64"]["artifacts"]["metal"]["formats"]["iso"]["disk"]["location"]')
#RHCOS_ROOTFS=$(/root/bin/openshift-baremetal-install coreos print-stream-json | jq -r '.["architectures"]["x86_64"]["artifacts"]["metal"]["formats"]["pxe"]["rootfs"]["location"]')
RHCOS_ISO="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/latest/rhcos-live.x86_64.iso"
RHCOS_ROOTFS="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/latest/rhcos-live-rootfs.x86_64.img"
curl -Lk $RHCOS_ISO > /var/www/html/$(basename $RHCOS_ISO)
curl -Lk $RHCOS_ROOTFS > /var/www/html/$(basename $RHCOS_ROOTFS)

{% if acm %}
tasty install advanced-cluster-management --wait
oc create -f /root/acm_cr.yml
sleep 240
oc patch hiveconfig hive --type merge -p '{"spec":{"targetNamespace":"hive","logLevel":"debug","featureGates":{"custom":{"enabled":["AlphaAgentInstallStrategy"]},"featureSet":"Custom"}}}'
sleep 120
{% else %}
oc create -f /root/ai_install.yml
{% endif %}

OCP_RELEASE=$(/root/bin/openshift-baremetal-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)
BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)

{% if disconnected %}
REVERSE_NAME=$(dig -x $BAREMETAL_IP +short | sed 's/\.[^\.]*$//')
echo $BAREMETAL_IP | grep -q ':' && SERVER6=$(grep : /etc/resolv.conf | grep -v fe80 | cut -d" " -f2) && REVERSE_NAME=$(dig -6x $BAREMETAL_IP +short @$SERVER6 | sed 's/\.[^\.]*$//')
export LOCAL_REGISTRY=${REVERSE_NAME:-$(hostname -f)}:5000
export RELEASE=$LOCAL_REGISTRY/ocp4:$OCP_RELEASE
python3 /root/bin/gen_registries.py > /root/registries.txt
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
export CA_CERT=$(cat /opt/registry/certs/domain.crt | sed "s/^/    /")
export VERSION=$(/root/bin/openshift-baremetal-install coreos print-stream-json | jq -r '.["architectures"]["x86_64"]["artifacts"]["metal"]["release"]')

envsubst < /root/ztp_assisted-service.sample.yml > /root/ztp_assisted-service.yml
oc create -f /root/ztp_assisted-service.yml
