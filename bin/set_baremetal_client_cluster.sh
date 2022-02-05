export CRYPTOGRAPHY_DONT_BUILD_RUST=1
pip3 install -U pip
pip3 install python-ironicclient --ignore-installed PyYAML
oc project openshift-machine-api
{% raw %}
export IRONIC_USER=$(oc get secret/metal3-ironic-password -o template --template '{{.data.username}}' | base64 -d)
export IRONIC_PASSWORD=$(oc get secret/metal3-ironic-password -o template --template '{{.data.password}}' | base64 -d)
export INSPECTOR_USER=$(oc get secret/metal3-ironic-inspector-password -o template --template '{{.data.username}}' | base64 -d)
export INSPECTOR_PASSWORD=$(oc get secret/metal3-ironic-inspector-password -o template --template '{{.data.password}}' | base64 -d)
{% endraw %}
mv /root/bin/clouds.yaml /root/bin/clouds.yaml.ori
envsubst < /root/bin/clouds.yaml.ori > /root/clouds.yaml
sed -i 's/metal3-bootstrap/metal3/' /root/.bashrc
