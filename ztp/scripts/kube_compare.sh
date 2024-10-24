METADATA_FILE="${1:-/root/cnf-features-deploy/ztp/kube-compare-reference/metadata.yaml}"

if [ "$(which kubectl-cluster_compare)" == "" ] ; then
 podman create --name kca registry.redhat.io/openshift4/kube-compare-artifacts-rhel9:latest
 podman cp kca:/usr/share/openshift/linux_amd64/kube-compare.rhel9 /usr/local/bin/kubectl_cluster-compare
 podman rm -f kca
 chmod u+x /usr/local/bin/kubectl-cluster_compare
fi
if [ ! -d /root/reference ] ; then
 mkdir reference
 MINOR=$(openshift-install version | head -1 | cut -d' ' -f2 | cut -d. -f1,2)
{% if kubecompare_ran|default(true) %}
 podman run -it  registry.redhat.io/openshift4/openshift-telco-core-rds-rhel9:v$MINOR | base64 -d | tar xv -C /root/reference
{% else %}
 podman run --rm --log-driver=none registry.redhat.io/openshift4/ztp-site-generate-rhel8:v$MINOR extract /home/ztp --tar | tar xv -C /root/reference
{% endif %}
fi
kubectl cluster-compare -r /root/reference/metadata.yaml
