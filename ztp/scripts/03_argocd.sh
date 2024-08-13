cd /root/ztp/scripts/argocd
oc patch argocd openshift-gitops -n openshift-gitops --type=merge --patch-file argocd-openshift-gitops-patch.json

# Patch the argocd route to use reencrypt because of a known issue
# https://github.com/redhat-developer/gitops-operator/issues/261
# https://issues.redhat.com/browse/GITOPS-1548 
oc patch argocd -n openshift-gitops openshift-gitops --type='merge' -p '{"spec":{"server":{"route":{"tls":{"termination":"reencrypt"}}}}}'
  
oc apply -k .
