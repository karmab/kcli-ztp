{% set spoke = ztp_spokes[index] %}

SPOKE={{ spoke.name }}
BAREMETAL_IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
echo $BAREMETAL_IP | grep -q ':' && BAREMETAL_IP=[$BAREMETAL_IP]
sed -i "s@CHANGEME@$BAREMETAL_IP@" /root/spoke_$SPOKE/bmc.yml

oc create -f /root/spoke_$SPOKE/bmc.yml
