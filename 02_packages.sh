#!/usr/bin/env bash

set -euo pipefail

dnf -y install libvirt-libs libvirt-client ipmitool mkisofs tmux make git bash-completion
dnf -y install python36
export CRYPTOGRAPHY_DONT_BUILD_RUST=1
pip3 install -U pip
pip3 install python-ironicclient --ignore-installed PyYAML
