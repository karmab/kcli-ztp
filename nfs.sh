export KUBECONFIG=/root/ocp/auth/kubeconfig
export PRIMARY_IP=$(ip -o addr show baremetal | head -1 | awk '{print $4}' | cut -d'/' -f1)
yum -y install nfs-utils
systemctl enable --now nfs-server
export MODE="ReadWriteOnce"
for i in `seq 1 20` ; do
    export PV=`printf "%03d" ${i}`
    mkdir /$PV
    echo "/$PV *(rw,no_root_squash)"  >>  /etc/exports
    chcon -t svirt_sandbox_file_t /$PV
    chmod 777 /$PV
    [ "$i" -gt "10" ] && export MODE="ReadWriteMany"
    envsubst < /root/nfs.yml | oc create -f -
done
exportfs -r
