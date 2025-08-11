
REGISTRY_USER={{ disconnected_user }}
REGISTRY_PASSWORD={{ disconnected_password }}

BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
{% if disconnected_url != None %}
REGISTRY={{ disconnected_url }}
{% elif dns %}
REGISTRY=registry.{{ cluster }}.{{ domain }}:5000
{% else %}
REGISTRY=$(echo $BAREMETAL_IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io:5000
{% endif %}
export REGISTRY

export VERSION=v$(oc get clusterversion version -o jsonpath='{.status.desired.version}')
export KEY=$(echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | base64)
export SSH_PUB_KEY=$(cat /root/.ssh/id_rsa.pub)
[ -d /root/ibi ] || mkdir /root/ibi
envsubst < /root/ztp/scripts/image-based-installation-config.sample.yaml > /root/ibi/image-based-installation-config.yaml

echo "additionalTrustBundle: |" >> /root/ibi/image-based-installation-config.yaml
sed -e 's/^/  /' /opt/registry/certs/domain.crt >> /root/ibi/image-based-installation-config.yaml
openshift-install image-based create image --dir /root/ibi
mv /root/ibi/rhcos-ibi.iso /var/www/html


{% for spoke in spokes %}
{% if spoke.get('ctlplanes', 1) == 1 and spoke.get('workers', 0)== 0 and spoke.get('ibi', False) %}
{% set spoke = spokes[1] %}
{% set host = spoke.baremetal_hosts[0] if spoke.baremetal_hosts is defined else {} %}
{% set url = host["redfish_address"]|default("https://127.0.0.1:9000/redfish/v1/Systems/kcli/%s-%s-node-0" % (cluster, spoke.name)) %}
{% set user = host['bmc_user']|default(bmc_user) %}
{% set password = host['bmc_password']|default(bmc_password) %}
kcli start baremetal -u {{ user }} -p {{ password }} -P iso_url=http://$BAREMETAL_IP/rhcos-ibi.iso {{ url }}
{% endif %}
{% endfor %}
