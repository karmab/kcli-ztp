{% if disconnected_url != None %}
{% set registry_port = disconnected_url.split(':')[-1] %}
{% set registry_name = disconnected_url|replace(":" + registry_port, '') %}
REGISTRY_NAME={{ registry_name }}
REGISTRY_PORT={{ registry_port }}
{% elif dns %}
REGISTRY_NAME=registry.{{ cluster }}.{{ domain }}
REGISTRY_PORT={{ 8443 if disconnected_quay else 5000 }}
{% else %}
PRIMARY_NIC=$(ls -1 /sys/class/net | grep 'eth\|en' | head -1)
export IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
REGISTRY_NAME=$(echo $IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
REGISTRY_PORT={{ 8443 if disconnected_quay else 5000 }}
{% endif %}

PULL_SECRET="/root/openshift_pull.json"
image=$1
skopeo copy docker://$image docker://$REGISTRY_NAME:$REGISTRY_PORT/$(echo $image | cut -d'/' -f 2- ) --all --authfile $PULL_SECRET --insecure-policy
