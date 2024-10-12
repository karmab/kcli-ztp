## Purpose

This repository provides automation for deploying the following components:

- a hub cluster using Agent Based Install
- spokes using ZTP

## Architecture 

Kcli is leveraged to deploy a plan which creates an "installer vm" to drive deployment via the following steps:

- Virtual nodes for both the hub and spokes are created (or combined with baremetal nodes). Note this is optional
- Client packages such as openshift-install are downloaded with any specified version and tag.
- Stop the nodes to deploy through redfish.
- Launch hub install against them
- Install ZTP requirements such as assisted service, openshift-gitops, a git server, ... 
- Launch spoke deployments

Parameters allow to customize the installation

The installer vm (and additional virtual nodes) can run on any platform supported by kcli with support for iso deployment.
So far it was tested on:

- kvm
- vsphere and esx

### Requirements

#### for kcli

- kcli installed (for rhel8/cento8/fedora, look [here](https://kcli.readthedocs.io/en/latest/#package-install-method))
- An openshift pull secret (stored by default in openshift_pull.json)

#### on the provisioning node (KVM Only)

- a physical bridge typically named baremetal with a nic from the external network

Here's a script you can run on the provisioning node for that (adjust the NIC variable as per your environment)

```
export NIC=eno2
sudo nmcli connection add ifname baremetal type bridge con-name baremetal
sudo nmcli con add type bridge-slave ifname $NIC master baremetal
sudo nmcli con down $NIC; sudo pkill dhclient; sudo dhclient baremetal
```

## Launch

Prepare a valid parameter file with the information needed. At least, you need to specify the following elements:

- api_ip
- ingress_ip
- bmc_user/bmc_password (for real baremetal)
- an array of your ctlplanes (if thet are not virtual). Each entry in this array needs at least the mac and redfish_address. Optionally you can indicate for each entry a specific bmc_user, bmc_password and disk (to be used as rootdevice hint) either as /dev/XXX or simply XXX
- an array of your workers (can be left empty if you only want to deploy ctlplanes). The format of those entries follow the one indicated for ctlplanes.

Here's a snippet what the workers variable might look like:

```
workers:
- redfish_address: 192.168.1.5
- redfish_address: 192.168.1.6
```

You can have a look at:

- [parameters.yml](samples/parameters.yml) for a parameter file targetting baremetal nodes only
- [parameters_virtual.yml](samples/parameters_virtual.yml) for one combining virtual ctlplanes and physical workers.

Call the resulting file `kcli_parameters.yml` to avoid having to specify it in the creation command.

Then you can launch deployment with:

```
kcli create plan
```

## Interacting in the vm

```
kcli ssh
```

## Parameters

Note that you can use the baseplan `kcli_plan_infra.yml` to deploy the infrastructure only

|Parameter                                    |Default Value                |
|---------------------------------------------|-----------------------------|
|KUBECONFIG                                   |None                         |
|acm                                          |True                         |
|apps                                         |[]                           |
|apps_install_cr                              |False                        |
|baremetal_cidr                               |None                         |
|baseplan                                     |kcli_plan_infra.yml          |
|bmc_password                                 |calvin                       |
|bmc_reset                                    |False                        |
|bmc_user                                     |root                         |
|cas                                          |[]                           |
|cluster_network_ipv4                         |10.132.0.0/14                |
|cluster_network_ipv6                         |fd01::/48                    |
|converged_flow                               |False                        |
|cpu_partitioning                             |False                        |
|deploy_hub                                   |True                         |
|disable_validations                          |True                         |
|disconnected                                 |False                        |
|disconnected_certified_operators             |[]                           |
|disconnected_certified_operators_version     |None                         |
|disconnected_clean_pull_secret               |False                        |
|disconnected_community_operators             |[]                           |
|disconnected_community_operators_version     |None                         |
|disconnected_extra_catalogs                  |[]                           |
|disconnected_extra_images                    |[]                           |
|disconnected_extra_releases                  |[]                           |
|disconnected_marketplace_operators           |[]                           |
|disconnected_marketplace_operators_version   |None                         |
|disconnected_operators                       |[]                           |
|disconnected_operators_deploy_after_openshift|False                        |
|disconnected_operators_version               |None                         |
|disconnected_password                        |dummy                        |
|disconnected_quay                            |False                        |
|disconnected_url                             |None                         |
|disconnected_user                            |dummy                        |
|dns                                          |False                        |
|dualstack                                    |False                        |
|dualstack_cidr                               |None                         |
|dualstack_isolated                           |False                        |
|fips                                         |False                        |
|gitops_clusters_app_path                     |site-configs                 |
|gitops_password                              |dummy                        |
|gitops_policies_app_path                     |site-policies                |
|gitops_repo_branch                           |main                         |
|gitops_repo_url                              |None                         |
|gitops_user                                  |dummy                        |
|go_version                                   |1.13.8                       |
|http_proxy                                   |None                         |
|image                                        |centos9stream                |
|imagecontentsources                          |[]                           |
|imageregistry                                |False                        |
|installer_disk_size                          |None                         |
|installer_ip                                 |None                         |
|installer_mac                                |None                         |
|installer_memory                             |None                         |
|installer_numcpus                            |None                         |
|installer_wait                               |False                        |
|keys                                         |[]                           |
|launch_steps                                 |True                         |
|localhost_fix                                |False                        |
|manifests_dir                                |manifests                    |
|monitoring_retention                         |None                         |
|motd                                         |None                         |
|nbde                                         |False                        |
|network_type                                 |OVNKubernetes                |
|nfs                                          |False                        |
|no_proxy                                     |None                         |
|notify                                       |False                        |
|notifyscript                                 |scripts/notify.sh            |
|ntp                                          |False                        |
|ntp_server                                   |0.rhel.pool.ntp.org          |
|numcpus                                      |16                           |
|openshift_image                              |None                         |
|prs                                          |[]                           |
|pull_secret                                  |openshift_pull.json          |
|registry_image                               |quay.io/karmab/registry:amd64|
|rhnregister                                  |True                         |
|rhnwait                                      |30                           |
|schedulable_ctlplanes                        |False                        |
|service_network_ipv4                         |172.30.0.0/16                |
|service_network_ipv6                         |fd02::/112                   |
|spoke_deploy                                 |True                         |
|spoke_domain                                 |None                         |
|spoke_network_type                           |OVNKubernetes                |
|spoke_policies_dir                           |spoke_policies_dir           |
|spoke_static_network                         |False                        |
|spoke_wait                                   |True                         |
|spoke_wait_time                              |3600                         |
|static_baremetal_dns                         |None                         |
|static_baremetal_gateway                     |None                         |
|static_ips                                   |[]                           |
|static_network                               |False                        |
|tag                                          |4.17                         |
|users_admin                                  |admin                        |
|users_adminpassword                          |admin                        |
|users_dev                                    |dev                          |
|users_devpassword                            |dev                          |
|version                                      |stable                       |
|wait_for_workers                             |True                         |
|wait_for_workers_number                      |None                         |
|wait_for_workers_timeout                     |3600                         |
|workflow_installer                           |False                        |

### Node parameters

when specifying *baremetal_ctlplanes* or *baremetal_workers* as an array, the specification can be created with something like this

```
- redfish_address: 192.168.123.45
  mac: 98:03:9b:62:81:49
```

The following parameters can be used in this case:

- redfish_address. Redfish url
- boot_mode (optional). Should either be set to Legacy, UEFI or UEFISecureBoot
- bmc_user. If not specified, global bmc_password variable is used
- bmc_password.  If not specified, global bmc_password variable is used
- disk. Optional rootDeviceHint disk device
- ip, nic, gateway. Those attributes can be provided to set static networking using nmstate. Nic can be omitted. If gateway isn't provided, the static_gateway is used or gateway is guessed from baremetal_cidr

## Sample parameter files

The following sample parameter files are available for you to deploy:

- [lab.yml](lab.yml) This deploys 3 ctlplanes in a dedicated ipv4 network
- [lab_ipv6.yml](lab_ipv6.yml) This deploys 3 ctlplanes in a dedicated ipv6 network (hence in a disconnected manner) and a SNO spoke on top
