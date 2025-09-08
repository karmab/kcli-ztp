#!/usr/bin/env bash

set -euo pipefail

blue='\033[0;36m'
clear='\033[0m'

export KUBECONFIG=/root/ocp/auth/kubeconfig

echo -e "${blue}************ RUNNING ztp/scripts/01_assisted-service.sh ************${clear}"
/root/ztp/scripts/01_assisted-service.sh

echo -e "${blue}************ RUNNING ztp/scripts/02_git.sh ************${clear}"
/root/ztp/scripts/02_git.sh

{% if spokes|length > 0 %}
echo -e "${blue}************ RUNNING ztp/scripts/03_spokes_deploy.sh ************${clear}"
/root/ztp/scripts/03_spokes_deploy.sh

echo -e "${blue}************ RUNNING ztp/scripts/04_spokes_wait.sh ************${clear}"
/root/ztp/scripts/04_spokes_wait.sh

if [ -d /root/ztp/scripts/site-policies ] ; then
  echo -e "${blue}************ RUNNING ztp/scripts/07_compliance.sh ************${clear}"
  /root/ztp/scripts/05_compliance.sh
fi

if [ -f /root/ztp/scripts/seed.txt ] ; then
  echo -e "${blue}************ RUNNING ztp/scripts/06_seed.sh ************${clear}"
  /root/ztp/scripts/06_seed.sh
fi

if [ -f /root/ztp/scripts/ibis.txt ] ; then
  echo -e "${blue}************ RUNNING ztp/scripts/07_ibis_deploy.sh ************${clear}"
  /root/ztp/scripts/07_ibis_deploy.sh
  echo -e "${blue}************ RUNNING ztp/scripts/07_ibis_wait.sh ************${clear}"
  /root/ztp/scripts/08_ibis_wait.sh
fi
{% endif %}
