#!/usr/bin/env bash

export PATH=/root/bin:$PATH
dnf -y install httpd
systemctl enable --now httpd

{% if acm %}
APP=advanced-cluster-management
SOURCE_ARGS="-P acm_mce_catalog=$(kcli info app openshift multicluster-engine | grep ^source: | cut -d: -f2 | xargs)"
{% else %}
APP=multicluster-engine
SOURCE_ARGS=""
{% endif %}

{% if disconnected %}
BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
REGISTRY_NAME=$(echo $BAREMETAL_IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
LOCAL_PORT={{ 8443 if disconnected_quay else 5000 }}
DISCONNECTED_ARGS="-P disconnected_url=${REGISTRY_NAME}:$LOCAL_PORT"
{% else %}
DISCONNECTED_ARGS=""
{% endif %}

kcli create app openshift $APP $DISCONNECTED_ARGS $SOURCE_ARGS -P timeout=600
