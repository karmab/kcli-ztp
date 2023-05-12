#!/usr/bin/env bash

SPOKE={{ spoke }}
oc get secret -n $SPOKE $SPOKE-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > /root/kubeconfig.$SPOKE
echo Use the following to connect to this SPOKE
echo export KUBECONFIG=/root/kubeconfig.$SPOKE
