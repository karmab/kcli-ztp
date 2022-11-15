#!/usr/bin/env bash

# set -euo pipefail

PRIMARY_NIC=$(ls -1 /sys/class/net | grep 'eth\|en' | head -1)
export KUBECONFIG=/root/ocp/auth/kubeconfig
export PRIMARY_IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
# Latest nfs-utils 2.3.3-51 is broken
rpm -qi nfs-utils >/dev/null 2>&1 || dnf -y install nfs-utils
test ! -f /usr/lib/systemd/system/firewalld.service || systemctl disable --now firewalld
systemctl enable --now nfs-server

mkdir /var/nfsshare
echo "/var/nfsshare *(rw,no_root_squash)"  >>  /etc/exports
exportfs -r

NAMESPACE="nfs-storage"
BASEDIR="/root/nfs-subdir"
oc create namespace $NAMESPACE
git clone https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner.git $BASEDIR
oc project $NAMESPACE
sed -i "s/namespace:.*/namespace: $NAMESPACE/g" $BASEDIR/deploy/rbac.yaml $BASEDIR/deploy/deployment.yaml
oc create -f $BASEDIR/deploy/rbac.yaml
oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:$NAMESPACE:nfs-client-provisioner
if [ "$(podman ps | grep -q registry)" == "0" ] ; then
 /root/bin/sync_image.sh k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
 REGISTRY_NAME=$(echo $PRIMARY_IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
 sed -i "s@k8s.gcr.io@$REGISTRY_NAME:5000@" $BASEDIR/deploy/deployment.yaml
fi
sed -i -e "s@k8s-sigs.io/nfs-subdir-external-provisioner@storage.io/nfs@" -e "s@10.3.243.101@$PRIMARY_IP@" -e "s@/ifs/kubernetes@/var/nfsshare@" $BASEDIR/deploy/deployment.yaml
echo 'apiVersion: storage.k8s.io/v1
kind: StorageClass
    metadata:
  name: nfs
provisioner: storage.io/nfs
parameters:
  pathPattern: "${.PVC.namespace}/${.PVC.name}"
  onDelete: delete' > $BASEDIR/deploy/class.yaml
oc create -f $BASEDIR/deploy/deployment.yaml -f $BASEDIR/deploy/class.yaml
oc patch storageclass nfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
