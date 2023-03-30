#!/usr/bin/env bash

SPOKE={{ spoke }}
VERSION={{ ztp_contrail_version }}
CTL_CIDR={{ ztp_contrail_ctl_cidr }}
CTL_GATEWAY={{ ztp_contrail_ctl_gateway }}
PULLSECRET_ENCODED=$(cat /root/openshift_pull.json | tr -d [:space:] | base64 -w0)
cd /root
git clone https://github.com/Juniper/contrail-networking
cd contrail-networking/releases/$VERSION/ocp
sed -i "s@10.40.1.0/24@$CTL_CIDR@" vrrp/99-network-configmap.yaml
sed -i "s@10.40.1.1@$CTL_GATEWAY@" vrrp/99-network-configmap.yaml

FIRST_NIC={{ ztp_contrail_data_nic }}
SECOND_NIC={{ ztp_contrail_ctl_nic }}
sed -i "s@ens3@$FIRST_NIC@" 99-disable-offload-master.yaml 99-disable-offload-worker.yaml
sed -i "s@ens4@$SECOND_NIC@" vrrp/99-disable-offload-master-ens4.yaml vrrp/99-disable-offload-worker-ens4.yaml

sed -i "s@<base64-encoded-credential>@$PULLSECRET_ENCODED@" auth-registry/*pullsecret.yaml

[ -d /root/spoke_$SPOKE/manifests ] || mkdir /root/spoke_$SPOKE/manifests
find . -name "*yaml" -exec cp {} /root/spoke_$SPOKE/manifests \;

for entry in $(ls /root/spoke_$SPOKE/manifests | sort -r) ; do
  manifest=$(echo $(basename $entry) | sed "s/\./-/g" | sed "s/_/-/g")
  sed -i "/  manifestsConfigMapRefs.*/a\ \ - name: $manifest" /root/spoke_$SPOKE/spoke.sample.yml
done
