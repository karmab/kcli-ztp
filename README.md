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
- if you're running against your local hypervisor, since the installer vm will try to interact with libvirt over ssh, you need to:
  - copy your public key to root user authorized keys.
  - add the *config_host* variable in your parameter file pointing to a routable ip of the hypervisor.

### on the provisioning node

- libvirt daemon (with fw_cfg support)
- two physical bridges:
    - baremetal with a nic from the external network
    - provisioning with a nic from the provisioning network. Ideally assign it an ip of 172.22.0.1/24

Here's a script you can run on the provisioning node for that (adjust the nics variable as per your environment)

```
export PROV_CONN=eno1
export MAIN_CONN=eno2
sudo nmcli connection add ifname provisioning type bridge con-name provisioning
sudo nmcli con add type bridge-slave ifname "$PROV_CONN" master provisioning
sudo nmcli connection add ifname baremetal type bridge con-name baremetal
sudo nmcli con add type bridge-slave ifname "$MAIN_CONN" master baremetal
sudo nmcli con down "System $MAIN_CONN"; sudo pkill dhclient; sudo dhclient baremetal
sudo nmcli connection modify provisioning ipv4.addresses 172.22.0.1/24 ipv4.method manual
sudo nmcli con down provisioning
sudo nmcli con up provisioning
```

## Launch

Prepare a valid parameter file with the information needed. At least, you need to specify the following elements:

- api_ip
- ingress_ip
- dns_ip
- an array of your masters (if they are not virtual)
- an array of your workers (can be left empty if you only want to deploy masters)
- ipmi_user
- ipmi_password

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
- you can run *openstack baremetal node list* during deployment to check the status of the provisioning of the nodes (Give some time after launching an install before ironic is accessible).
- script *ipmi.py* can be used to check the power status of the baremetal node or to stop them (using `ipmi.py off`)

## Parameters

|Parameter                |Default Value                                |
|-------------------------|---------------------------------------------|
|image                    |centos8                                      |
|openshift_image          |registry.svc.ci.openshift.org/ocp/release:4.4|
|cluster                  |openshift                                    |
|domain                   |karmalabs.com                                |
|network_type             |OpenShiftSDN                                 |
|keys                     |[]                                           |
|api_ip                   |None                                         |
|dns_ip                   |None                                         |
|ingress_ip               |None                                         |
|image_url                |None                                         |
|network                  |default                                      |
|pool                     |default                                      |
|numcpus                  |16                                           |
|masters                  |[]                                           |
|workers                  |[]                                           |
|memory                   |32768                                        |
|disk_size                |30                                           |
|extra_disks              |[]                                           |
|rhnregister              |True                                         |
|rhnwait                  |30                                           |
|provisioning_interface   |eno1                                         |
|provisioning_net         |provisioning                                 |
|provisioning_ip          |172.22.0.3                                   |
|provisioning_cidr        |172.22.0.0/24                                |
|provisioning_range       |172.22.0.10,172.22.0.100                     |
|provisioning_installer_ip|172.22.0.253                                 |
|provisioning_macs        |[]                                           |
|provisioning_mac_prefix  |aa:aa:aa:aa:aa                               |
|ipmi_user                |root                                         |
|ipmi_password            |calvin                                       |
|baremetal_net            |baremetal                                    |
|baremetal_cidr           |None                                         |
|baremetal_macs           |[]                                           |
|baremetal_ips            |[]                                           |
|pullsecret               |openshift_pull.json                          |
|notifyscript             |notify.sh                                    |
|virtual                  |False                                        |
|virtual_numcpus          |8                                            |
|virtual_memory           |32768                                        |
|cache                    |True                                         |
|notify                   |True                                         |
|deploy                   |True                                         |
|wait_workers             |True                                         |
|disconnected             |False                                        |
|registry_user            |dummy                                        |
|registry_password        |dummy                                        |
|nfs                      |True                                         |
|imageregistry            |False                                        |
|build                    |False                                        |
|go_version               |1.13.8                                       |
|prs                      |[]                                           |
|imagecontentsources      |[]                                           |
