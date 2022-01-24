#!/usr/bin/env bash

set -euo pipefail

time dnf -y install libvirt-libs libvirt-client ipmitool mkisofs tmux make git bash-completion vim-enhanced
dnf -y install python3
