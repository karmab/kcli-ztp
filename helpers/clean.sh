#!/usr/bin/env bash

[ -d /root/ocp ] && rm -rf /root/ocp
export LIBVIRT_DEFAULT_URI=qemu+ssh://{{ config_user | default('root') }}@{{ config_host if config_host != '127.0.0.1' else baremetal_net|local_ip(true) }}/system
cluster={{ cluster }}
bootstrap=$(virsh list --all --name | grep "$cluster.*bootstrap")
if [ "$bootstrap" != "" ] ; then
  for vm in $bootstrap ; do
   virsh destroy $vm
   virsh undefine $vm
  done
fi

pools=$(virsh pool-list --all --name | grep "$cluster.*bootstrap")
if [ "$pool" != "" ] ; then
  for pool in $bootstrap ; do
    virsh vol-delete $pool $pool
    virsh vol-delete $pool-base $pool
    virsh vol-delete $pool.ign $pool
    virsh pool-destroy $pool
    virsh pool-undefine $pool
    ssh {{ config_user | default('root') }}@{{ config_host if config_host != '127.0.0.1' else baremetal_net|local_ip }} "sudo rmdir /var/lib/libvirt/openshift-images/$pool"
  done
fi
