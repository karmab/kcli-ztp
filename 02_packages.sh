#!/usr/bin/env bash

dnf -y install libvirt-libs libvirt-client ipmitool mkisofs tmux make git bash-completion
dnf -y install python36
pip3 install python-ironicclient
