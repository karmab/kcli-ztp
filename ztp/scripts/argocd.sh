cd /root/ztp/argocd
oc patch argocd openshift-gitops -n openshift-gitops --type=merge --patch-file argocd-openshift-gitops-patch.json
oc apply -k .
