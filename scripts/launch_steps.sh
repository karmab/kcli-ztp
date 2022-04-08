blue='\033[0;36m'
clear='\033[0m'
{% if http_proxy != None %}
echo -e "${blue}************ RUNNING .proxy.sh ************${clear}"
bash /root/scripts/proxy.sh
source /etc/profile.d/proxy.sh
{% endif %}

{% if virtual_masters or virtual_workers %}
echo -e "${blue}************ RUNNING 00_virtual.sh ************${clear}"
bash /root/scripts/00_virtual.sh
{% endif %}

echo -e "${blue}************ RUNNING 01_patch_installconfig.sh ************${clear}"
/root/scripts/01_patch_installconfig.sh
echo -e "${blue}************ RUNNING 02_packages.sh ************${clear}"
bash /root/scripts/02_packages.sh
echo -e "${blue}************ RUNNING 03_provisioning_network.sh ************${clear}"
bash /root/scripts/03_provisioning_network.sh
echo -e "${blue}************ RUNNING 04_get_clients.sh ************${clear}"
/root/scripts/04_get_clients.sh || exit 1

{% if cache %}
echo -e "${blue}************ RUNNING 05_cache.sh ************${clear}"
/root/scripts/05_cache.sh
{% endif %}

{% if disconnected %}
{% if disconnected_url == None %}
echo -e "${blue}************ RUNNING 06_disconnected_{{ 'quay.sh' if disconnected_quay else 'registry.sh' }}.sh ************${clear}"
/root/scripts/06_disconnected_{{ 'quay.sh' if disconnected_quay else 'registry.sh' }} || exit 1
{% endif %}
echo -e "${blue}************ RUNNING 06_disconnected_mirror.sh ************${clear}"
/root/scripts/06_disconnected_mirror.sh || exit 1
{% if (disconnected_operators or disconnected_certified_operators or disconnected_community_operators or disconnected_marketplace_operators) and not disconnected_operators_deploy_after_openshift %}
echo -e "${blue}************ RUNNING 06_disconnected_olm.sh ************${clear}"
/root/scripts/06_disconnected_olm.sh
{% if disconnected_url == None and disconnected_quay %}
rm -rf /root/manifests-redhat-operator-index-*
/root/scripts/06_disconnected_olm.sh
{% endif %}
{% endif %}
{% endif %}

{% if nbde %}
echo -e "${blue}************ RUNNING 07_nbde.sh ************${clear}"
/root/scripts/07_nbde.sh
{% endif %}

{% if ntp %}
echo -e "${blue}************ RUNNING 08_ntp.sh ************${clear}"
/root/scripts/08_ntp.sh
{% endif %}

{% if deploy_openshift %}
echo -e "${blue}************ RUNNING 09_deploy_openshift.sh ************${clear}"
export KUBECONFIG=/root/ocp/auth/kubeconfig
bash /root/scripts/09_deploy_openshift.sh
sed -i "s/metal3-bootstrap/metal3/" /root/.bashrc
sed -i "s/172.22.0.2/172.22.0.3/" /root/.bashrc
{% if nfs %}
echo -e "${blue}************ RUNNING 10_nfs.sh ************${clear}"
bash /root/scripts/10_nfs.sh
{% endif %}
{% if imageregistry %}
echo -e "${blue}************ RUNNING imageregistry patch ************${clear}"
oc patch configs.imageregistry.operator.openshift.io cluster --type merge -p '{"spec":{"managementState":"Managed","storage":{"pvc":{}}}}'
{% endif %}
{% if disconnected and (disconnected_operators or disconnected_certified_operators or disconnected_community_operators or disconnected_marketplace_operators) and disconnected_operators_deploy_after_openshift %}
echo -e "${blue}************ RUNNING 06_disconnected_olm.sh ************${clear}"
/root/scripts/06_disconnected_olm.sh
{% endif %}
{% if apps %}
echo -e "${blue}************ RUNNING 11_apps.sh ************${clear}"
bash /root/scripts/11_apps.sh
{% endif %}
touch /root/cluster_ready.txt
{% if ztp_spokes is defined %}
echo -e "${blue}************ RUNNING ztp/acm/assisted-service.sh ************${clear}"
bash /root/ztp/acm/assisted-service.sh
{% if ztp_siteconfig %}
echo -e "${blue}************ RUNNING ztp/scripts/spokes_deploy_siteconfig.sh ************${clear}"
bash /root/ztp/scripts/spokes_deploy_siteconfig.sh
{% else %}
echo -e "${blue}************ RUNNING ztp/scripts/spokes_deploy.sh ************${clear}"
bash /root/ztp/scripts/spokes_deploy.sh
{% endif %}
{% endif %}
{% if argocd is defined and argocd %}
bash /root/ztp/scripts/argocd.sh
{% endif %}
{% endif %}
