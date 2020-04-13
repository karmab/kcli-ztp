export KUBECONFIG=/root/ocp/auth/kubeconfig
export PRIMARY_IP=$(ip -o addr show baremetal | head -1 | awk '{print $4}' | cut -d'/' -f1)
yum -y install nfs-utils
for i in `seq -f "%03g" 1 20` ; do
mkdir /pv${i}
echo "/pv$i *(rw,no_root_squash)"  >>  /etc/exports
chcon -t svirt_sandbox_file_t /pv${i}
chmod 777 /pv${i}
done
exportfs -r
systemctl start nfs ; systemctl enable nfs-server
for i in `seq 1 20` ; do j=`printf "%03d" ${i}` ; sed "s/001/$j/" /root/nfs.yml | kubectl create -f - ; done

yum -y install nfs-utils
mkdir /pv001
echo "/pv001 *(rw,no_root_squash)"  >>  /etc/exports
chcon -t svirt_sandbox_file_t /pv001
chmod 777 /pv001
exportfs -r
systemctl enable --now nfs-server
export MODE="ReadWriteOnce"
for i in `seq 1 20` ; do
    export PVC=`printf "%03d" ${i}`
    [ "$i" -gt "10" ] && export MODE="ReadWriteMany"
    envsubst < /root/nfs.yml | oc create -f -
done
