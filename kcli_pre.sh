#!/usr/bin/env bash

# NETWORK CHECK
{% if baremetal_cidr == None %}
echo baremetal_cidr not set. No network, no party!
exit 1
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

{% if config_host == '127.0.0.1' and not lab %}
ip a l {{ baremetal_net }} >/dev/null 2>&1 || { echo Issue with network {{ baremetal_net }} ; exit 1; }
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
{% elif version == 'ci' %}
grep -q registry.ci.openshift.org {{ pullsecret }} || { echo Missing token for registry.ci.openshift.org ; exit 1; }
{% endif %}
{% endif %}

# QUAY CHECK

{% if disconnected_quay %}
{% if ':' in baremetal_cidr %}
echo disconnected_quay only works with IPV4
exit 1
{% endif %}
echo disconnected_user will be forced to 'init'
{% if disconnected_password|length < 8  %}
echo disconnected_password will be forced to super{{ disconnected_password }}
{% endif %}
{% endif %}

# ZTP CHECKS
{% if ztp_nodes is defined %}
{% if ztp_spoke_masters_number > 1 %}
{% if ztp_spoke_api_ip == None %}
echo ztp_spoke_api_ip needs to be set if deploying an HA spoke && exit 1
{% endif %}
{% if ztp_spoke_ingress_ip == None %}
echo ztp_spoke_ingress_ip needs to be set if deploying an HA spoke && exit 1
{% endif %}
{% endif %}
{% endif %}
