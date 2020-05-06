bash /root/00_prep.sh
bash /root/01_get_clients.sh

{% if cache %}
bash /root/02_cache.sh
{% endif %}

{% if disconnected %}
bash /root/03_disconnected.sh
{% endif %}

bash /root/04_patch_installconfig.sh
{% if virtual %}
bash /root/05_virtual.sh
{% endif %}

{% if deploy %}
export KUBECONFIG=/root/ocp/auth/kubeconfig
bash /root/06_deploy_openshift.sh
sed -i "s/metal3-bootstrap/metal3/" /root/.bashrc
sed -i "s/172.22.0.2/172.22.0.3/" /root/.bashrc
bash /root/nfs.sh
{% if imageregistry %}
oc patch configs.imageregistry.operator.openshift.io cluster --type merge -p '{"spec":{"managementState":"Managed","storage":{"pvc":{}}}}'
{% endif %}
{% endif %}
