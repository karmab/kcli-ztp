#!/usr/bin/env bash

set -euo pipefail

dnf -y copr enable karmab/kcli
dnf -y install libvirt-libs libvirt-client ipmitool mkisofs tmux make git bash-completion vim-enhanced kcli
dnf -y install python3

update-ca-trust extract

curl -Ls https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 > /usr/bin/jq	
chmod u+x /usr/bin/jq

cd /root/bin
curl -k -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz > oc.tar.gz
tar zxf oc.tar.gz
rm -rf oc.tar.gz
mv oc /usr/bin
chmod +x /usr/bin/oc

curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl > /usr/bin/kubectl
chmod u+x /usr/bin/kubectl

export PULL_SECRET="/root/openshift_pull.json"
{% if version in ['dev-preview', 'stable'] %}
{% set tag = tag|string %}
{% if tag.split('.')|length > 2 %}
TAG={{ tag }}
{% else %}
TAG={{"latest-" + tag }}
{% endif %}
OCP_REPO={{ 'ocp-dev-preview' if version == 'dev-preview' else 'ocp' }}
export OPENSHIFT_RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/$OCP_REPO/$TAG/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
{% elif version == 'latest' %}
export OPENSHIFT_RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/{{ version }}-{{ tag }}/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
{% elif version == 'ci' %}
{% if openshift_image == None %}
{% set openshift_image = tag if '/' in tag|string else "registry.ci.openshift.org/ocp/release:" + tag|string %}
{% endif %}
export OPENSHIFT_RELEASE_IMAGE={{ openshift_image }}
{% elif version == 'nightly' %}
export OPENSHIFT_RELEASE_IMAGE=$(curl -s https://amd64.ocp.releases.ci.openshift.org/api/v1/releasestream/{{ tag|string }}.0-0.nightly/latest | jq -r .pullSpec)
{% endif %}
oc adm release extract --registry-config $PULL_SECRET --command=oc --to /tmp $OPENSHIFT_RELEASE_IMAGE
mv /tmp/oc /root/bin
oc adm release extract --registry-config $PULL_SECRET --command=openshift-baremetal-install --to /root/bin $OPENSHIFT_RELEASE_IMAGE
ln -s /root/bin/openshift-baremetal-install /root/bin/openshift-install
echo $OPENSHIFT_RELEASE_IMAGE > /root/version.txt

curl -s -L https://github.com/itaysk/kubectl-neat/releases/download/v2.0.3/kubectl-neat_linux_amd64.tar.gz | tar xvz -C /usr/bin/

dnf copr enable zaneb/autopage -y
dnf install podman skopeo python3-bmo-log-parse -y

oc completion bash >>/etc/bash_completion.d/oc_completion
