#!/usr/bin/env bash

set -euo pipefail

dnf -y copr enable karmab/kcli
dnf -y install libvirt-libs libvirt-client mkisofs tmux make git bash-completion vim-enhanced nmstate python3 podman skopeo httpd bind-utils kcli  net-tools

systemctl enable --now httpd

update-ca-trust extract

curl -Ls https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 > /usr/bin/jq	
chmod u+x /usr/bin/jq

curl -Ls https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.5.0/kustomize_v5.5.0_linux_amd64.tar.gz | tar zxf - > /usr/bin/kustomize
chmod u+x /usr/bin/kustomize

kcli download oc
mv oc /usr/bin
chmod +x /usr/bin/oc

kcli download kubectl
mv kubectl /usr/bin
chmod u+x /usr/bin/kubectl

kcli download openshift-install -P version={{ version }} -P tag={{ tag }} -P pull_secret=/root/openshift_pull.json
mv openshift-install /usr/bin
chmod u+x /usr/bin/openshift-install
openshift-install version | grep 'release image' | cut -d' ' -f3 > /root/version.txt

oc completion bash >>/etc/bash_completion.d/oc_completion

export OCP_RELEASE=$(openshift-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)
SITE_GENERATE_REGISTRY={{ 'registry.stage.redhat.io' if 'rc' in tag else 'registry.redhat.io' }}
SITE_GENERATE_TAG=v{{ '4.20' if version in ['candidate', 'ci'] else '$MINOR' }}
REDHAT_CREDS=$(cat /root/openshift_pull.json | jq .auths.\"$SITE_GENERATE_REGISTRY\".auth -r | base64 -d)
RHN_USER=$(echo $REDHAT_CREDS | cut -d: -f1)
RHN_PASSWORD=$(echo $REDHAT_CREDS | cut -d: -f2)
podman login -u "$RHN_USER" -p "$RHN_PASSWORD" $SITE_GENERATE_REGISTRY

mkdir -p /root/.config/kustomize/plugin
podman cp $(podman create --name policygentool --rm $SITE_GENERATE_REGISTRY/openshift4/ztp-site-generate-rhel8:$SITE_GENERATE_TAG):/kustomize/plugin/ran.openshift.io ~/.config/kustomize/plugin/
podman rm -f policygentool
