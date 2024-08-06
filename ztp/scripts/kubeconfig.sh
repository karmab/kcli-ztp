#!/usr/bin/env bash

if [ "$#" != "1" ] ; then
  echo "Usage: $0 SPOKE_NAME"
  exit 1
fi

SPOKE=$1
oc get secret -n $SPOKE $SPOKE-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > /root/kubeconfig.$SPOKE
echo Use the following to connect to this SPOKE
echo export KUBECONFIG=/root/kubeconfig.$SPOKE
