#!/usr/bin/env bash

set -euo pipefail

dnf -y copr enable karmab/kcli
dnf -y copr enable karmab/aicli
dnf -y install libvirt-libs libvirt-client mkisofs tmux make git bash-completion vim-enhanced nmstate python3 podman skopeo httpd bind-utils kcli aicli net-tools

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
