#!/usr/bin/env bash

set -euo pipefail

blue='\033[0;36m'
clear='\033[0m'

export KUBECONFIG=/root/ocp/auth/kubeconfig

echo -e "${blue}************ RUNNING ztp/scripts/01_assisted-service.sh ************${clear}"
/root/ztp/scripts/01_assisted-service.sh

{% if ztp_gitops and ztp_gitops_repo_url == None %}
echo -e "${blue}************ RUNNING ztp/scripts/02_git.sh ************${clear}"
/root/ztp/scripts/02_git.sh
{% endif %}

{% if ztp_spokes|length > 0  or ztp_gitops_repo_url != None %}
echo -e "${blue}************ RUNNING ztp/scripts/03_spokes_deploy.sh ************${clear}"
/root/ztp/scripts/03_spokes_deploy.sh

echo -e "${blue}************ RUNNING ztp/scripts/04_spokes_wait.sh ************${clear}"
/root/ztp/scripts/04_spokes_wait.sh

if [ -f /root/ztp/scripts/extra_bmc_* ] ; then
  echo -e "${blue}************ RUNNING ztp/scripts/05_snoplus.sh ************${clear}"
  /root/ztp/scripts/05_snoplus.sh
fi
{% endif %}
