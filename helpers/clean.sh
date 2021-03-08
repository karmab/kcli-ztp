#!/usr/bin/env bash

[ -d /root/ocp ] && rm -rf /root/ocp
export LIBVIRT_DEFAULT_URI=qemu+ssh://{{ config_user | default('root') }}@{{ config_host }}/system
cluster={{ cluster }}
bootstrap=$(virsh list --all --name | grep "$cluster.*bootstrap")
if [ "$bootstrap" != "" ] ; then
for vm in $bootstrap ; do
virsh destroy $vm
virsh undefine $vm
# virsh vol-delete $vm default
# virsh vol-delete $vm.ign default
for vol in $(virsh vol-list default | grep "$cluster.*bootstrap"  | awk '{print $2}') ; do echo $vol ; done
virsh pool-info $vm >/dev/null 2>&1 && virsh pool-undefine $vm
done
fi
