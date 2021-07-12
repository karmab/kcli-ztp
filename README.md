## Purpose

This repository provides a plan which deploys a vm where:
- openshift-baremetal-install is downloaded or compiled from source (with an additional list of PR numbers to apply)
- stop the nodes to deploy through ipmi
- launch the install against a set of baremetal nodes. Virtual masters can also be deployed.

## Why

To deploy baremetal using `bare minimum` on the provisioning node

## Requirements

### for kcli

- kcli installed (for rhel8/cento8/fedora, look [here](https://kcli.readthedocs.io/en/latest/#package-install-method))
- an openshift pull secret (stored by default in openshift_pull.json)

### on the provisioning node

- libvirt daemon (with fw_cfg support)
- two physical bridges:
    - baremetal with a nic from the external network
    - provisioning with a nic from the provisioning network. Ideally assign it an ip of 172.22.0.1/24

Here's a script you can run on the provisioning node for that (adjust the nics variable as per your environment)

```
export MAIN_CONN=eno2
sudo nmcli connection add ifname baremetal type bridge con-name baremetal
sudo nmcli con add type bridge-slave ifname "$MAIN_CONN" master baremetal
sudo nmcli con down "System $MAIN_CONN"; sudo pkill dhclient; sudo dhclient baremetal
export PROV_CONN=eno1
sudo nmcli connection add ifname provisioning type bridge con-name provisioning
sudo nmcli con add type bridge-slave ifname "$PROV_CONN" master provisioning
sudo nmcli connection modify provisioning ipv4.addresses 172.22.0.1/24 ipv4.method manual
sudo nmcli con down provisioning
sudo nmcli con up provisioning
```

If using vlans on the provisioning interface, the following can be used:

```
VLANID=1200
BRIDGE=prov$VLAN
IP="172.22.0.100/24"
nmcli connection add ifname $BRIDGE type bridge con-name $BRIDGE
nmcli connection add type vlan con-name vlan$VLAN ifname eno1.$VLAN dev eno1 id $VLAN master $BRIDGE slave-type bridge
nmcli connection modify $BRIDGE ipv4.addresses $IP ipv4.method manual
nmcli con down $BRIDGE
nmcli con up $BRIDGE
```

## Launch

Prepare a valid parameter file with the information needed. At least, you need to specify the following elements:

- api_ip
- ingress_ip
- dns_ip (optional)
- ipmi_user
- ipmi_password
- an array of your masters (if thet are not virtual). Each entry in this array needs at least the provisioning_mac and ipmi_address. Optionally you can indicate for each entry a specific ipmi_user, ipmi_password and disk (to be used as rootdevice hint) either as /dev/XXX or simply XXX
- an array of your workers (can be left empty if you only want to deploy masters). The format of those entries follow the one indicated for masters.

Here's a snippet what the workers variable might look like:

```
workers:
- ipmi_address: 192.168.1.5
  provisioning_mac: 98:03:9b:62:ab:19
- ipmi_address: 192.168.1.6
  provisioning_mac: 98:03:9b:62:ab:17
  disk: /dev/sde
```

You can have a look at:

- [parameters.yml.sample](parameters.yml.sample) for a parameter file targetting baremetal nodes only
- [parameters_virtual.yml.sample](parameters_virtual.yml.sample) for one combining virtual masters and physical workers.

Call the resulting file `kcli_parameters.yml` to avoid having to specify it in the creation command.

Then you can launch deployment with:

```
kcli create plan
```

## Interacting in the vm

The deployed vm comes with a set of helpers for you:
- scripts deploy.sh and clean.sh allow you to manually launch an install or clean a failed one
- you can run *baremetal node list* during deployment to check the status of the provisioning of the nodes (Give some time after launching an install before ironic is accessible).
- script *ipmi.py* can be used to check the power status of the baremetal node or to stop them (using `ipmi.py off`). When not using provisioning network, a script named *redfish.py* provides a similar functionality

## Parameters

|Parameter                            |Default Value                            |
|-------------------------------------|-----------------------------------------|
|api_ip                               |None                                     |
|baremetal_bootstrap_mac              |None                                     |
|baremetal_cidr                       |None                                     |
|baremetal_ips                        |[]                                       |
|baremetal_macs                       |[]                                       |
|baremetal_net                        |baremetal                                |
|baremetal_noprovisioning_bootstrap_ip|None                                     |
|baremetal_noprovisioning_ip          |None                                     |
|build                                |False                                    |
|cache                                |True                                     |
|cas                                  |[]                                       |
|cluster                              |openshift                                |
|deploy_openshift                     |True                                     |
|disconnected                         |False                                    |
|disk_size                            |30                                       |
|dns_ip                               |None                                     |
|domain                               |karmalabs.com                            |
|dualstack                            |False                                    |
|dualstack_cidr                       |None                                     |
|extra_disks                          |[]                                       |
|fips                                 |False                                    |
|go_version                           |1.13.8                                   |
|http_proxy                           |None                                     |
|image                                |centos8                                  |
|image_url                            |None                                     |
|imagecontentsources                  |[]                                       |
|imageregistry                        |False                                    |
|ingress_ip                           |None                                     |
|installer_mac                        |None                                     |
|installer_wait                       |False                                    |
|ipmi_password                        |calvin                                   |
|ipmi_user                            |root                                     |
|keys                                 |[]                                       |
|lab                                  |False                                    |
|launch_steps                         |True                                     |
|masters                              |[]                                       |
|memory                               |32768                                    |
|model                                |dell                                     |
|nbde                                 |False                                    |
|network                              |default                                  |
|network_type                         |OVNKubernetes                            |
|nfs                                  |True                                     |
|no_proxy                             |None                                     |
|notify                               |True                                     |
|notifyscript                         |notify.sh                                |
|ntp                                  |False                                    |
|ntp_server                           |0.rhel.pool.ntp.org                      |
|numcpus                              |16                                       |
|openshift_image                      |registry.ci.openshift.org/ocp/release:4.8|
|playbook                             |False                                    |
|pool                                 |default                                  |
|provisioning_bootstrap_mac           |None                                     |
|provisioning_cidr                    |172.22.0.0/24                            |
|provisioning_enable                  |True                                     |
|provisioning_installer_ip            |172.22.0.253                             |
|provisioning_interface               |eno1                                     |
|provisioning_ip                      |172.22.0.3                               |
|provisioning_macs                    |[]                                       |
|provisioning_net                     |provisioning                             |
|provisioning_range                   |172.22.0.10,172.22.0.100                 |
|prs                                  |[]                                       |
|pullsecret                           |openshift_pull.json                      |
|registry_image                       |quay.io/saledort/registry:2              |
|registry_password                    |dummy                                    |
|registry_user                        |dummy                                    |
|rhnregister                          |True                                     |
|rhnwait                              |30                                       |
|tag                                  |4.8                                      |
|uefi_legacy                          |False                                    |
|version                              |ci                                       |
|virtual_masters                      |False                                    |
|virtual_masters_baremetal_mac_prefix |aa:aa:aa:cc:cc                           |
|virtual_masters_mac_prefix           |aa:aa:aa:aa:aa                           |
|virtual_masters_memory               |32768                                    |
|virtual_masters_number               |3                                        |
|virtual_masters_numcpus              |8                                        |
|virtual_protocol                     |ipmi                                     |
|virtual_workers                      |False                                    |
|virtual_workers_baremetal_mac_prefix |aa:aa:aa:dd:dd                           |
|virtual_workers_deploy               |True                                     |
|virtual_workers_mac_prefix           |aa:aa:aa:bb:bb                           |
|virtual_workers_memory               |16384                                    |
|virtual_workers_number               |1                                        |
|virtual_workers_numcpus              |8                                        |
|workers                              |[]                                       |

## Node parameters

when specifying *masters* or *workers* as an array, the specification can be created with something like this

```
- ipmi_address: 192.168.123.45
  provisioning_mac: 98:03:9b:62:81:49
```

The following parameters can be used in this case:

- ipmi_address. Redfish ip
- redfish_address. Redfish url
- provisioning_mac. It needs to be set to the mac to use along with provisioning network or any of the macs of the node when provisioning is disabled
- boot_mode (optional). Should either be set to Legacy, UEFI or UEFISecureBoot
-
## Lab runthrough

A lab available [here](https://ocp-baremetal-ipi-lab.readthedocs.io/en/latest) is provided to get people familiarized with Baremetal Ipi workflow.

