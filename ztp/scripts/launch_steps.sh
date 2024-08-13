#!/usr/bin/env bash

set -euo pipefail

blue='\033[0;36m'
clear='\033[0m'

export KUBECONFIG=/root/ocp/auth/kubeconfig

echo -e "${blue}************ RUNNING ztp/scripts/01_assisted-service.sh ************${clear}"
/root/ztp/scripts/01_assisted-service.sh

{% if ztp_git %}
echo -e "${blue}************ RUNNING ztp/scripts/02_git.sh ************${clear}"
/root/ztp/scripts/02_git.sh
{% endif %}

{% if argocd %}
echo -e "${blue}************ RUNNING ztp/scripts/03_argocd.sh ************${clear}"
/root/ztp/scripts/03_argocd.sh
{% else %}
echo -e "${blue}************ RUNNING ztp/scripts/03_spokes_deploy.sh ************${clear}"
/root/ztp/scripts/03_spokes_deploy.sh
{% endif %}
