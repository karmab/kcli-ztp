METADATA_FILE="${1:-/root/cnf-features-deploy/ztp/kube-compare-reference/metadata.yaml}"

if [ "$(which kubectl-cluster_compare)" == "" ] ; then
 curl -L https://github.com/openshift/kube-compare/releases/download/v0.0.1/kube-compare_linux_amd64.tar.gz > kube-compare_linux_amd64.tar.gz
 tar zxvf kube-compare_linux_amd64.tar.gz
 mv kubectl-cluster_compare /usr/local/bin
 chmod u+x /usr/local/bin/kubectl-cluster_compare
fi
if [ ! -d /root/reference ] ; then
 cd /root
 # MINOR=$(openshift-install version | head -1 | cut -d' ' -f2 | cut -d. -f1,2)
 # git clone --depth 1 --branch release-$MINOR https://github.com/openshift-kni/cnf-features-deploy
 git clone https://github.com/openshift-kni/cnf-features-deploy
 mkdir reference
 cp -r cnf-features-deploy/ztp/source-crs/* reference
 cp $METADATA_FILE reference/metadata.yaml
fi
kubectl cluster-compare -r /root/reference/metadata.yaml
