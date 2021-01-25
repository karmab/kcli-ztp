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

you could also use redfish_address instead of ipmi for baremetals that support it
```
- redfish_address: redfish://10.0.0.1/redfish/v1/Systems/System.Embedded.1
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
- script *ipmi.py* can be used to check the power status of the baremetal node or to stop them (using `ipmi.py off`)

## Parameters

|Parameter                 |Default Value                                |
|--------------------------|---------------------------------------------|
|image                     |centos8                                      |
|openshift_image           |registry.ci.openshift.org/ocp/release:4.7    |
|cluster                   |openshift                                    |
|domain                    |karmalabs.com                                |
|network_type              |OVNKubernetes                                |
|keys                      |[]                                           |
|api_ip                    |None                                         |
|dns_ip                    |None                                         |
|ingress_ip                |None                                         |
|image_url                 |None                                         |
|network                   |default                                      |
|pool                      |default                                      |
|numcpus                   |16                                           |
|masters                   |[]                                           |
|workers                   |[]                                           |
|memory                    |32768                                        |
|disk_size                 |30                                           |
|extra_disks               |[]                                           |
|rhnregister               |True                                         |
|rhnwait                   |30                                           |
|provisioning_interface    |eno1                                         |
|provisioning_net          |provisioning                                 |
|provisioning_ip           |172.22.0.3                                   |
|provisioning_cidr         |172.22.0.0/24                                |
|provisioning_range        |172.22.0.10,172.22.0.100                     |
|provisioning_installer_ip |172.22.0.253                                 |
|provisioning_macs         |[]                                           |
|ipmi_user                 |root                                         |
|ipmi_password             |calvin                                       |
|baremetal_net             |baremetal                                    |
|baremetal_cidr            |None                                         |
|baremetal_macs            |[]                                           |
|baremetal_ips             |[]                                           |
|pullsecret                |openshift_pull.json                          |
|notifyscript              |notify.sh                                    |
|virtual_masters           |False                                        |
|virtual_masters_number    |3                                            |
|virtual_masters_numcpus   |8                                            |
|virtual_masters_memory    |32768                                        |
|virtual_masters_mac_prefix|aa:aa:aa:aa:aa                               |
|virtual_workers           |False                                        |
|virtual_workers_number    |1                                            |
|virtual_workers_numcpus   |8                                            |
|virtual_workers_memory    |16384                                        |
|virtual_workers_mac_prefix|aa:aa:aa:bb:bb                               |
|virtual_workers_deploy    |False                                        |
|cache                     |True                                         |
|notify                    |True                                         |
|deploy                    |True                                         |
|lab                       |False                                        |
|disconnected              |False                                        |
|registry_user             |dummy                                        |
|registry_password         |dummy                                        |
|nfs                       |True                                         |
|imageregistry             |False                                        |
|build                     |False                                        |
|go_version                |1.13.8                                       |
|prs                       |[]                                           |
|imagecontentsources       |[]                                           |
|fips                      |False                                        |
|cas                       |[]                                           |
