oc project openshift-machine-api
export IRONIC_USER=$(oc get secret/metal3-ironic-password -o template --template '{{.data.username}}' | base64 -d)
export IRONIC_PASSWORD=$(oc get secret/metal3-ironic-password -o template --template '{{.data.password}}' | base64 -d)
export INSPECTOR_USER=$(oc get secret/metal3-ironic-inspector-password -o template --template '{{.data.username}}' | base64 -d)
export INSPECTOR_PASSWORD=$(oc get secret/metal3-ironic-inspector-password -o template --template '{{.data.password}}' | base64 -d)
mv /root/clouds.yaml /root/clouds.yaml/ori
envsubst < /root/clouds.yaml/ori > /root/clouds.yaml
