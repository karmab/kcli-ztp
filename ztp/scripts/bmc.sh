{% set spoke = ztp_spokes[index] %}
{% set virtual_nodes_number = spoke["virtual_nodes_number"]|default(0) %}

SPOKE={{ spoke.name }}
BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
echo $BAREMETAL_IP | grep -q ':' && BAREMETAL_IP=[$BAREMETAL_IP]
sed -i "s@IP@$BAREMETAL_IP@" /root/spoke_$SPOKE/bmc.yml
export LIBVIRT_DEFAULT_URI=qemu+ssh://{{ 'root' if config_user == 'apache' else config_user }}@{{ config_host if config_host not in ['127.0.0.1', 'localhost'] else baremetal_net|local_ip(true) }}/system

{% if virtual_nodes_number > 0 %}
{% for num in range(0, virtual_nodes_number) %}
UUID=$(virsh domuuid {{ cluster }}-$SPOKE-node-{{ num }})
sed -i "s@UUID-$SPOKE-{{ num }}@$UUID@" /root/spoke_$SPOKE/bmc.yml
{% endfor %}
{% endif %}
oc create -f /root/spoke_$SPOKE/bmc.yml
