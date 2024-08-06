#!/usr/bin/env bash

set -euo pipefail

blue='\033[0;36m'
clear='\033[0m'

export KUBECONFIG=/root/ocp/auth/kubeconfig

{% if ztp_spokes is defined %}
echo -e "${blue}************ RUNNING ztp/assisted/assisted-service.sh ************${clear}"
/root/ztp/assisted/assisted-service.sh
echo -e "${blue}************ RUNNING ztp/scripts/spokes_deploy.sh ************${clear}"
/root/ztp/scripts/spokes_deploy.sh
{% endif %}

{% if argocd is defined and argocd %}
/root/ztp/scripts/argocd.sh
{% endif %}
