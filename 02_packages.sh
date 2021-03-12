#!/usr/bin/env bash
#fix the pyyaml version error
pip3 install pip==8.1.1
pip3 uninstall pyyaml
pip3 install -U pip

dnf -y install libvirt-libs libvirt-client ipmitool mkisofs tmux make git bash-completion
dnf -y install python36
export CRYPTOGRAPHY_DONT_BUILD_RUST=1
pip3 install python-ironicclient
