#!/usr/bin/env bash

[ -d /root/ocp ] && rm -rf /root/ocp
CLUSTER={{ cluster }}
HYPERVISOR={{ config_user | default('root') }}@{{ config_host if config_host != '127.0.0.1' else baremetal_net|local_ip(true) }}
export LIBVIRT_DEFAULT_URI=qemu+ssh://$HYPERVISOR/system
BOOTSTRAP=$(virsh list --all --name | grep "$CLUSTER.*bootstrap")
if [ "$BOOTSTRAP" != "" ] ; then
  for VM in $BOOTSTRAP ; do
   echo "Deleting old bootstrap vm $VM"
   virsh destroy $VM
   virsh undefine $VM
  done
fi

POOLS=$(virsh pool-list --all --name | grep "$CLUSTER.*bootstrap")
if [ "$POOLS" != "" ] ; then
  for POOL in $POOLS ; do
    echo "Handling old assets for pool $POOL"
    virsh vol-delete $POOL $POOL
    virsh vol-delete $POOL-base $POOL
    virsh vol-delete $POOL.ign $POOL
    virsh pool-destroy $POOL
    virsh pool-undefine $POOL
    ssh $HYPERVISOR "rmdir /var/lib/libvirt/openshift-images/$POOL"
  done
fi

ssh $HYPERVISOR "find /var/lib/libvirt/images/boot-* -type f -mtime +5 -exec virsh vol-delete {} +"
