#!/usr/bin/env bash

# NETWORK CHECK
{% if baremetal_cidr == None %}
echo baremetal_cidr not set. No network, no party!
exit 1
{% else %}
{% set baremetal_prefix = baremetal_cidr.split('/')[1] %}
{% endif %}

{% if api_ip == None %}
echo api_ip not set. No network, no party!
exit 1
{% elif ingress_ip == None %}
echo ingress_ip not set. No network, no party!
exit 1
{% elif  api_ip == ingress_ip %}
echo api_ip and ingress_ip cant be set to the same value
exit 1
{% else %}
if [ ! -d /Users ] && [ -n "$(which ipcalc)" ] ; then
  api_cidr=$(ipcalc {{ api_ip }}/{{ baremetal_prefix }} | grep ^Network: | sed 's/Network://' | xargs)
  if [ "$api_cidr" != "{{ baremetal_cidr }}" ] ; then
   echo {{ api_ip }} doesnt belong to to {{ baremetal_cidr }}
   exit 1
  fi
  ingress_cidr=$(ipcalc {{ ingress_ip }}/{{ baremetal_prefix }} | grep ^Network: | sed 's/Network://' | xargs)
  if [ "$ingress_cidr" != "{{ baremetal_cidr }}" ] ; then
    echo {{ ingress_ip }} doesnt belong to to {{ baremetal_cidr }}
    exit 1
  fi
fi
{% endif %}

{% if dualstack %}
{% if ':' in baremetal_cidr %}
echo baremetal_cidr needs to be ipv4 for dual stack
exit 1
{% endif %}
{% if dualstack_cidr == None %}
echo dualstack_cidr needs to be set for dual stack
exit 1
{% elif ':' not in dualstack_cidr %}
echo dualstack_cidr needs to be ipv6 for dual stack
{% endif %}
{% endif %}

{% if config_host in ['127.0.0.1', 'localhost'] and not lab %}
{% set baremetal_bridge = baremetal_net if baremetal_net != 'default' else 'virbr0' %}
ip a l {{ baremetal_bridge }} >/dev/null 2>&1 || { echo Issue with network {{ baremetal_net }} ; exit 1; }
{% endif %}

# VERSION CHECK
{% if version is defined %}
{% if version in ['nightly', 'stable'] %}
{% set tag = tag|string %}
{% if tag.split('.')|length > 2 %}
TAG={{ tag }}
{% elif version == 'nightly' %}
TAG={{"latest-" + tag }}
{% else %}
TAG={{"stable-" + tag }}
{% endif %}
OCP_REPO={{ 'ocp-dev-preview' if version == 'nightly' else 'ocp' }}
curl -Ns https://mirror.openshift.com/pub/openshift-v4/clients/$OCP_REPO/$TAG/release.txt | grep -q 'Pull From: quay.io'
if  [ "$?" != "0" ] ; then
  echo couldnt gather release associated to {{ version }} and {{ tag }}
  exit 1
fi
{% elif version == 'latest' %}
curl -Ns https://mirror.openshift.com/pub/openshift-v4/clients/ocp/{{ version }}-{{ tag }}/release.txt | grep -q 'Pull From: quay.io'
if  [ "$?" != "0" ] ; then
  echo couldnt gather release associated to {{ version }} and {{ tag }}
  exit 1
fi
#{% elif version == 'ci' and 'registry.ci.openshift.org' in openshift_image %}
#grep -q registry.ci.openshift.org {{ pullsecret }} || { echo Missing token for registry.ci.openshift.org ; exit 1; }
{% endif %}
{% endif %}

# DISCONNECTED_URL CHECK

{% if disconnected and disconnected_url != None %}
{% if disconnected_url.split(':')|length != 2 %}
echo disconnected_url needs to be fqdn:port && exit 1
{% endif %}
{% set registry_port = disconnected_url.split(':')[-1] %}
{% set registry_name = disconnected_url|replace(":" + registry_port, '') %}
{% set registry_name_split = registry_name.split('.') %}
{% if registry_name_split|length == 4 and registry_name_split[0]|int != 0 and registry_name_split[1]|int != 0 and registry_name_split[2]|int != 0 and registry_name_split[3]|int != 0%}
echo disconnected_url cant use an ip. Considering using sslip.io && exit 1
{% endif %}
{% endif %}

# QUAY CHECK

{% if disconnected_quay %}
echo disconnected_user will be forced to 'init'
{% if disconnected_password|length < 8  %}
echo disconnected_password will be forced to super{{ disconnected_password }}
{% endif %}
{% endif %}

# ZTP CHECKS
{% if ztp_spokes is defined %}
{% for spoke in ztp_spokes %}
{% set spoke_name = spoke.get('name') %}
{% set spoke_api_ip = spoke.get('api_ip') %}
{% set spoke_ingress_ip= spoke.get('ingress_ip') %}
{% set spoke_masters_number = spoke.get('masters_number', 1) %}
{% set virtual_nodes_number = spoke["virtual_nodes_number"]|default(0) %}
{% if spoke_name == None %}
echo spoke_name needs to be on each entry of ztp_spokes && exit 1
{% endif %}
{% if spoke_masters_number > 1 %}
{% if spoke_api_ip == None %}
echo spoke_api_ip needs to be set if deploying an HA spoke && exit 1
{% endif %}
{% if spoke_ingress_ip == None %}
echo spoke_ingress_ip needs to be set if deploying an HA spoke && exit 1
{% endif %}
{% endif %}
{% endfor %}
{% endif %}

{% if argocd is defined and argocd %}
{% if argocd_repo_url == None %}
echo argocd_repo_url needs to be set for argocd && exit 1
{% endif %}
{% if argocd_clusters_app_path == None %}
echo argocd_clusters_app_path needs to be set for argocd && exit 1
{% endif %}
{% if argocd_policies_app_path == None %}
echo argocd_policies_app_path needs to be set for argocd && exit 1
{% endif %}
{% endif %}

## Cleaning
CLIENT={{ client|default("$(kcli list client | grep ' X ' | cut -d'|' -f2 | xargs)") }}
CLUSTER={{ cluster }}
POOL={{ pool }}
POOLPATH=$(kcli -C $CLIENT list pool | grep $POOL | cut -d"|" -f 3 | xargs)
export LC_ALL="en_US.UTF-8"
export LIBVIRT_DEFAULT_URI=$(kcli -C $CLIENT info host | grep Connection | sed 's/Connection: //')
find $POOLPATH/boot-* -type f -mtime +2 -exec sh -c 'virsh vol-delete {} || sudo rm {}' \;
find /var/lib/libvirt/openshift-images/${CLUSTER}-*-bootstrap -exec sh -c 'virsh pool-delete {} || sudo rm -rf {}' \;
VMS=$(kcli -C $CLIENT list vm | grep ${CLUSTER}-.*-bootstrap | cut -d"|" -f 2 | xargs)
[ -z "$VMS" ] || kcli -C $CLIENT delete vm --yes $VMS
POOLS=$(kcli -C $CLIENT list pool --short | grep $CLUSTER | cut -d"|" -f2 | xargs)
if [ ! -z "$POOLS" ] ; then
  for POOL in $POOLS ; do
    kcli -C $CLIENT delete pool --yes $POOL
  done
fi
