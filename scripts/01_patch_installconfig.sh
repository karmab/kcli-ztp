#!/usr/bin/env bash

set -euo pipefail

{% if not disconnected %}
PULLSECRET=$(cat /root/openshift_pull.json | tr -d [:space:])
echo -e "pullSecret: |\n  $PULLSECRET" >> /root/install-config.yaml
{% endif %}
SSHKEY=$(cat /root/.ssh/id_rsa.pub)
echo -e "sshKey: |\n  $SSHKEY" >> /root/install-config.yaml
