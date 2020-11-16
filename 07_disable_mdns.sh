export ROLE=worker
envsubst < /root/99-openshift-disable-mdns.sample.yaml > /root/manifests/99-openshift-worker-disable-mdns.yaml
export ROLE=master
envsubst < /root/99-openshift-disable-mdns.sample.yaml > /root/manifests/99-openshift-master-disable-mdns.yaml
