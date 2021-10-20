{% if http_proxy != None %}
echo "Running .proxy.sh"
bash /root/.proxy.sh
source /etc/profile.d/proxy.sh
{% endif %}

{% if virtual_masters %}
echo "Running 00_virtual.sh"
bash /root/00_virtual.sh
{% endif %}

echo "Running 01_patch_installconfig.sh"
/root/01_patch_installconfig.sh
echo "Running 02_packages.sh"
bash /root/02_packages.sh
echo "Running 03_network.sh"
bash /root/03_network.sh
echo "Running 04_get_clients.sh"
/root/04_get_clients.sh || exit 1

{% if cache %}
echo "Running 05_cache.sh"
/root/05_cache.sh
{% endif %}

{% if disconnected %}
echo "Running 06_disconnected.sh"
/root/06_disconnected.sh || exit 1
{% if disconnected_operators and not disconnected_operators_deploy_after_openshift %}
echo "Running 065_olm.sh"
/root/065_olm.sh
{% endif %}
{% endif %}

{% if nbde %}
echo "Running 07_nbde.sh"
/root/07_nbde.sh
{% endif %}

{% if ntp %}
echo "Running 08_ntp.sh"
/root/08_ntp.sh
{% endif %}

{% if deploy_openshift %}
echo "Running 09_deploy_openshift.sh"
export KUBECONFIG=/root/ocp/auth/kubeconfig
bash /root/09_deploy_openshift.sh
sed -i "s/metal3-bootstrap/metal3/" /root/.bashrc
sed -i "s/172.22.0.2/172.22.0.3/" /root/.bashrc
{% if nfs %}
echo "Running 10_nfs.sh"
bash /root/10_nfs.sh
{% endif %}
{% if imageregistry %}
echo "Running imageregistry patch"
oc patch configs.imageregistry.operator.openshift.io cluster --type merge -p '{"spec":{"managementState":"Managed","storage":{"pvc":{}}}}'
{% endif %}
{% if disconnected and disconnected_operators and disconnected_operators_deploy_after_openshift %}
echo "Running 065_olm.sh"
/root/065_olm.sh
{% endif %}
touch /root/cluster_ready.txt
{% endif %}
