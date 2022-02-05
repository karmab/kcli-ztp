{% if http_proxy != None %}
echo "************ RUNNING .proxy.sh ************"
bash /root/scripts/.proxy.sh
source /etc/profile.d/proxy.sh
{% endif %}

{% if virtual_masters or virtual_workers %}
echo "************ RUNNING 00_virtual.sh ************"
bash /root/scripts/00_virtual.sh
{% endif %}

echo "************ RUNNING 01_patch_installconfig.sh ************"
/root/scripts/01_patch_installconfig.sh
echo "************ RUNNING 02_packages.sh ************"
bash /root/scripts/02_packages.sh
echo "************ RUNNING 03_provisioning_network.sh ************"
bash /root/scripts/03_provisioning_network.sh
echo "************ RUNNING 04_get_clients.sh ************"
/root/scripts/04_get_clients.sh || exit 1

{% if cache %}
echo "************ RUNNING 05_cache.sh ************"
/root/scripts/05_cache.sh
{% endif %}

{% if disconnected %}
echo "************ RUNNING 06_disconnected_{{ 'quay.sh' if disconnected_quay else 'registry.sh' }}.sh ************"
/root/scripts/06_disconnected_{{ 'quay.sh' if disconnected_quay else 'registry.sh' }} || exit 1
echo "************ RUNNING 06_disconnected_mirror.sh ************"
/root/scripts/06_disconnected_mirror.sh || exit 1
{% if disconnected_operators and not disconnected_operators_deploy_after_openshift %}
echo "************ RUNNING 06_disconnected_olm.sh ************"
/root/scripts/06_disconnected_olm.sh
{% if disconnected_quay %}
rm -rf /root/manifests-redhat-operator-index-*
/root/scripts/06_disconnected_olm.sh
{% endif %}
{% endif %}
{% endif %}

{% if nbde %}
echo "************ RUNNING 07_nbde.sh ************"
/root/scripts/07_nbde.sh
{% endif %}

{% if ntp %}
echo "************ RUNNING 08_ntp.sh ************"
/root/scripts/08_ntp.sh
{% endif %}

{% if deploy_openshift %}
echo "************ RUNNING 09_deploy_openshift.sh ************"
export KUBECONFIG=/root/ocp/auth/kubeconfig
bash /root/scripts/09_deploy_openshift.sh
sed -i "s/metal3-bootstrap/metal3/" /root/.bashrc
sed -i "s/172.22.0.2/172.22.0.3/" /root/.bashrc
{% if nfs %}
echo "************ RUNNING 10_nfs.sh ************"
bash /root/scripts/10_nfs.sh
{% endif %}
{% if imageregistry %}
echo "************ RUNNING imageregistry patch ************"
oc patch configs.imageregistry.operator.openshift.io cluster --type merge -p '{"spec":{"managementState":"Managed","storage":{"pvc":{}}}}'
{% endif %}
{% if disconnected and disconnected_operators and disconnected_operators_deploy_after_openshift %}
echo "************ RUNNING 06_disconnected_olm.sh ************"
/root/scripts/06_disconnected_olm.sh
{% endif %}
{% if apps %}
bash /root/scripts/11_apps.sh
{% endif %}
touch /root/cluster_ready.txt
{% endif %}
