#!/usr/bin/env bash

set -euo pipefail

blue='\033[0;36m'
clear='\033[0m'
{% if http_proxy != None %}
echo -e "${blue}************ RUNNING .proxy.sh ************${clear}"
/root/scripts/proxy.sh
source /etc/profile.d/proxy.sh
{% endif %}

{% if virtual_ctlplanes or virtual_workers %}
echo -e "${blue}************ RUNNING 00_virtual.sh ************${clear}"
/root/scripts/00_virtual.sh || exit 1
{% endif %}

echo -e "${blue}************ RUNNING 01_patch_installconfig.sh ************${clear}"
/root/scripts/01_patch_installconfig.sh

echo -e "${blue}************ RUNNING 02_packages.sh ************${clear}"
/root/scripts/02_packages.sh

MINOR=$(/root/bin/openshift-baremetal-install version | head -1 | cut -d' ' -f2 | cut -d. -f2)
if [ "$MINOR" -lt "10" ] ; then
echo -e "${blue}************ RUNNING 03_cache.sh ************${clear}"
/root/scripts/03_cache.sh
fi

{% if disconnected %}
{% if disconnected_url == None %}
echo -e "${blue}************ RUNNING 04_disconnected_{{ 'quay.sh' if disconnected_quay else 'registry.sh' }}.sh ************${clear}"
/root/scripts/04_disconnected_{{ 'quay.sh' if disconnected_quay else 'registry.sh' }} || exit 1
{% endif %}
echo -e "${blue}************ RUNNING 04_disconnected_mirror.sh ************${clear}"
/root/scripts/04_disconnected_mirror.sh || exit 1
{% if (disconnected_operators or disconnected_certified_operators or disconnected_community_operators or disconnected_marketplace_operators or disconnected_extra_catalogs) and not disconnected_operators_deploy_after_openshift %}
echo -e "${blue}************ RUNNING 04_disconnected_olm.sh ************${clear}"
/root/scripts/04_disconnected_olm.sh
{% if disconnected_url == None and disconnected_quay %}
rm -rf /root/manifests-redhat-operator-index-*
/root/scripts/04_disconnected_olm.sh
{% endif %}
{% endif %}
{% endif %}

{% if nbde %}
echo -e "${blue}************ RUNNING 05_nbde.sh ************${clear}"
/root/scripts/05_nbde.sh
{% endif %}

{% if ntp %}
echo -e "${blue}************ RUNNING 06_ntp.sh ************${clear}"
/root/scripts/06_ntp.sh
{% endif %}

{% if deploy_openshift %}
echo -e "${blue}************ RUNNING 07_deploy_openshift.sh ************${clear}"
export KUBECONFIG=/root/ocp/auth/kubeconfig
/root/scripts/07_deploy_openshift.sh
sed -i "s/metal3-bootstrap/metal3/" /root/.bashrc
sed -i "s/172.22.0.2/172.22.0.3/" /root/.bashrc

{% if nfs %}
echo -e "${blue}************ RUNNING 08_nfs.sh ************${clear}"
/root/scripts/08_nfs.sh
{% endif %}

{% if imageregistry %}
echo -e "${blue}************ RUNNING imageregistry patch ************${clear}"
oc patch configs.imageregistry.operator.openshift.io cluster --type merge -p '{"spec":{"managementState":"Managed","storage":{"pvc":{}}}}'
{% endif %}

{% if disconnected and (disconnected_operators or disconnected_certified_operators or disconnected_community_operators or disconnected_marketplace_operators or disconnected_extra_catalogs) and disconnected_operators_deploy_after_openshift %}
echo -e "${blue}************ RUNNING 04_disconnected_olm.sh ************${clear}"
/root/scripts/04_disconnected_olm.sh
{% endif %}

echo -e "${blue}************ RUNNING 09_post_install.sh ************${clear}"
/root/scripts/09_post_install.sh

{% if apps %}
echo -e "${blue}************ RUNNING 10_apps.sh ************${clear}"
/root/scripts/10_apps.sh
{% endif %}

touch /root/cluster_ready.txt

{% if ztp_spokes is defined %}
echo -e "${blue}************ RUNNING ztp/acm/assisted-service.sh ************${clear}"
/root/ztp/acm/assisted-service.sh
{% if ztp_siteconfig %}
echo -e "${blue}************ RUNNING ztp/scripts/spokes_deploy_siteconfig.sh ************${clear}"
/root/ztp/scripts/spokes_deploy_siteconfig.sh
{% else %}
echo -e "${blue}************ RUNNING ztp/scripts/spokes_deploy.sh ************${clear}"
/root/ztp/scripts/spokes_deploy.sh
{% endif %}
{% endif %}

{% if argocd is defined and argocd %}
/root/ztp/scripts/argocd.sh
{% endif %}

{% endif %}
