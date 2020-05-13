# Introduction and Prerequisites

This hands on lab guides the user in deploying Openshift using baremetal IPI. The goal is to make you understand Baremetal IPI internals and workflow so that you can easily make use of it with real Baremetal and troubleshoot issues.

We emulate baremetal by using 3 empty virtual machines used as master nodes.

An additional vm is used to drive the installation, using a dedicated bash script for each part of the workflow.

## General Prerequisites

The following items are needed in order to be able to complete the lab from beginning to end:

* A powerful enough libvirt hypervisor with ssh access.
* a valid Pull secret from try.openshift.com to keep in a file named 'openshift_pull.json'
* git tool (for cloning the repo only)

# Preparing the lab

**NOTE:** This section can be skipped if lab has been prepared for you.

## Prepare the hypervisor

We install and launch libvirt, as needed for the bootstrap vm

```
sudo yum -y install libvirt libvirt-daemon-driver-qemu qemu-kvm
systemctl enable --now libvirtd
```

## Get kcli

We will leverage kcli to easily create the assets needed for the lab.

Install it following instructions [here](https://github.com/karmab/kcli#quick-start).

## Copy your public key for root access

**NOTE:** This step is only needed when kcli is running against a local hypervisor.

Since the openshift installer will access our hypervisor over ssh from a dedicated vm during the lab, we need to copy our public key to root using the following:

```
sudo sh -c 'cat ~/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys'
```

## Configure required lab bridges

**NOTE:** The following steps need to be run directly on the hypervisor

```
sudo sh -c 'echo -e "DEVICE=lab-baremetal\nTYPE=Bridge\nONBOOT=yes\nNM_CONTROLLED=no" > /etc/sysconfig/network-scripts/ifcfg-lab-baremetal'
sudo nmcli connection add ifname lab-prov type bridge con-name lab-prov
```

**NOTE:** We would add physical nics to both bridges to provide access to a real external network and enable provisioning on a dedicated physical network

## Deploy The lab plan

- Launch the following command:

```
git clone https://github.com/karmab/kcli-openshift4-baremetal
cd kcli-openshift4-baremetal
kcli create plan --paramfile lab.yml lab
```

Expected Output

```
Deploying Networks...
Network  lab-baremetal deployed
Network  lab-prov deployed
Deploying Images...
Image centos8 skipped!
Deploying Vms...
lab-master-0 deployed on local
lab-master-1 deployed on local
lab-master-2 deployed on local
lab-installer deployed on local
```

This will deploy 3 empty masters to emulate baremetal along with a centos8/rhel8 installer vm where the lab will be run.

- Check the created vms

```
kcli list vm
```

Expected Output

```
+---------------+--------+-----------------+--------------------------------------------------------+------------------+---------------+
|      Name     | Status |       Ips       |                         Source                         |       Plan       |   Profile     |
+---------------+--------+-----------------+--------------------------------------------------------+------------------+---------------+
| lab-installer |   up   |  192.168.123.46 | CentOS-8-GenericCloud-8.1.1911-20200113.3.x86_64.qcow2 |       lab        | local_centos8 |
|  lab-master-0 |  down  |                 |                                                        |       lab        |    kvirt      |
|  lab-master-1 |  down  |                 |                                                        |       lab        |    kvirt      |
|  lab-master-2 |  down  |                 |                                                        |       lab        |    kvirt      |
+---------------+--------+-----------------+--------------------------------------------------------+------------------+---------------+
```

- Check the created networks

```
kcli list networks
```

Expected Output

```
+------------------+---------+------------------+-------+------------------+------+
| Network          |   Type  |       Cidr       |  Dhcp |      Domain      | Mode |
+------------------+---------+------------------+-------+------------------+------+
| default          |  routed | 192.168.122.0/24 |  True |     default      | nat  |
| lab-baremetal    |  routed | 192.168.129.0/24 |  True |  lab-baremetal   | nat  |
| lab-prov         |  routed |  172.22.0.0/24   | False | lab-prov         | nat  |
+------------------+---------+------------------+-------+------------------+------+
```

- Get the ip for the installer vm and connect to it

```
kcli info vm lab-installer --fields ip --value
```

- Ssh into the installer vm

```
kcli ssh root@lab-installer
```

**NOTE:** In the remainder of the lab, we assume the user is connected (through ssh) to the installer vm in /root directory

**NOTE:** In each of the sections, user is encouraged to read the corresponding script to get a better understanding of what's done.

# Explore the environment

In the installer vm, Let's look at the following elements:

- There are several numbered scripts in `/root` that we will execute in the next sections.
- The pull secret was copied in /root/openshift_pull.json* . Make sure it's not quoted.
- Check */root/install-config.yaml* to be used when deploying Openshift:
  - It contains initial information but we will make it evolve with each section until deploying.
  - Check the section containing credential information for your masters and the replicas attribute. We would define information from workers using the same pattern( and specifying worker as *role*)
  - Revisit this file at the end of each section to see the modifications done.

# Virtual Masters preparation

In this section, we install and configure vbmc, which is an utility aimed at emulating ipmi when interacting with virtual machines.

Launch the following command:

```
/root/00_virtual.sh
```

Expected Output

```
0 files removed
CentOS-8 - AppStream                                                                                                            8.8 MB/s | 7.0 MB     00:00
CentOS-8 - Base                                                                                                                 3.0 MB/s | 2.2 MB     00:00
CentOS-8 - Extras                                                                                                                21 kB/s | 5.9 kB     00:00
Dependencies resolved.
================================================================================================================================================================
 Package                                Architecture              Version                                                    Repository                    Size
================================================================================================================================================================
Installing:
 gcc                                    x86_64                    8.3.1-4.5.el8                                              AppStream                     23 M
 ipmitool                               x86_64                    1.8.18-12.el8_1                                            AppStream                    394 k
 libvirt-devel                          x86_64                    4.5.0-35.3.module_el8.1.0+297+df420408                     AppStream                    210 k
 python3-libvirt                        x86_64                    4.5.0-2.module_el8.1.0+248+298dec18                        AppStream                    292 k
 python36                               x86_64                    3.6.8-2.module_el8.1.0+245+c39af44f                        AppStream                     19 k
 pkgconf-pkg-config                     x86_64                    1.4.2-1.el8                                                BaseOS                        15 k
Upgrading:
 glibc                                  x86_64                    2.28-72.el8_1.1                                            BaseOS                       3.7 M
 glibc-all-langpacks                    x86_64                    2.28-72.el8_1.1                                            BaseOS                        25 M
 glibc-common                           x86_64                    2.28-72.el8_1.1                                            BaseOS                       836 k
Installing dependencies:
 cpp                                    x86_64                    8.3.1-4.5.el8                                              AppStream                     10 M
 isl                                    x86_64                    0.16.1-6.el8                                               AppStream                    841 k
 libmpc                                 x86_64                    1.0.2-9.el8                                                AppStream                     59 k
 libvirt-libs                           x86_64                    4.5.0-35.3.module_el8.1.0+297+df420408                     AppStream                    4.1 M
 nmap-ncat                              x86_64                    2:7.70-5.el8                                               AppStream                    237 k
 python3-pip                            noarch                    9.0.3-15.el8                                               AppStream                     19 k
 yajl                                   x86_64                    2.1.0-10.el8                                               AppStream                     41 k
 avahi-libs                             x86_64                    0.7-19.el8                                                 BaseOS                        62 k
 binutils                               x86_64                    2.30-58.el8_1.2                                            BaseOS                       5.7 M
 cyrus-sasl                             x86_64                    2.1.27-1.el8                                               BaseOS                        96 k
 cyrus-sasl-gssapi                      x86_64                    2.1.27-1.el8                                               BaseOS                        49 k
 glibc-devel                            x86_64                    2.28-72.el8_1.1                                            BaseOS                       1.0 M
 glibc-headers                          x86_64                    2.28-72.el8_1.1                                            BaseOS                       469 k
 kernel-headers                         x86_64                    4.18.0-147.8.1.el8_1                                       BaseOS                       2.7 M
 libpkgconf                             x86_64                    1.4.2-1.el8                                                BaseOS                        35 k
 libxcrypt-devel                        x86_64                    4.1.1-4.el8                                                BaseOS                        25 k
 pkgconf                                x86_64                    1.4.2-1.el8                                                BaseOS                        38 k
 pkgconf-m4                             noarch                    1.4.2-1.el8                                                BaseOS                        17 k
 python3-setuptools                     noarch                    39.2.0-5.el8                                               BaseOS                       162 k
Enabling module streams:
 python36                                                         3.6

Transaction Summary
================================================================================================================================================================
Install  25 Packages
Upgrade   3 Packages

Total download size: 80 M
Downloading Packages:
(1/28): ipmitool-1.8.18-12.el8_1.x86_64.rpm                                                                                     3.0 MB/s | 394 kB     00:00
(2/28): isl-0.16.1-6.el8.x86_64.rpm                                                                                              11 MB/s | 841 kB     00:00
(3/28): libmpc-1.0.2-9.el8.x86_64.rpm                                                                                           2.4 MB/s |  59 kB     00:00
(4/28): cpp-8.3.1-4.5.el8.x86_64.rpm                                                                                             25 MB/s |  10 MB     00:00
(5/28): libvirt-libs-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64.rpm                                                           25 MB/s | 4.1 MB     00:00
(6/28): libvirt-devel-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64.rpm                                                         583 kB/s | 210 kB     00:00
(7/28): python3-libvirt-4.5.0-2.module_el8.1.0+248+298dec18.x86_64.rpm                                                          3.8 MB/s | 292 kB     00:00
(8/28): python3-pip-9.0.3-15.el8.noarch.rpm                                                                                     1.3 MB/s |  19 kB     00:00
(9/28): python36-3.6.8-2.module_el8.1.0+245+c39af44f.x86_64.rpm                                                                 1.3 MB/s |  19 kB     00:00
(10/28): yajl-2.1.0-10.el8.x86_64.rpm                                                                                           2.5 MB/s |  41 kB     00:00
(11/28): avahi-libs-0.7-19.el8.x86_64.rpm                                                                                       949 kB/s |  62 kB     00:00
(12/28): gcc-8.3.1-4.5.el8.x86_64.rpm                                                                                            27 MB/s |  23 MB     00:00
(13/28): nmap-ncat-7.70-5.el8.x86_64.rpm                                                                                        790 kB/s | 237 kB     00:00
(14/28): cyrus-sasl-2.1.27-1.el8.x86_64.rpm                                                                                     2.7 MB/s |  96 kB     00:00
(15/28): cyrus-sasl-gssapi-2.1.27-1.el8.x86_64.rpm                                                                              1.5 MB/s |  49 kB     00:00
(16/28): glibc-headers-2.28-72.el8_1.1.x86_64.rpm                                                                                12 MB/s | 469 kB     00:00
(17/28): binutils-2.30-58.el8_1.2.x86_64.rpm                                                                                     24 MB/s | 5.7 MB     00:00
(18/28): libpkgconf-1.4.2-1.el8.x86_64.rpm                                                                                      1.6 MB/s |  35 kB     00:00
(19/28): glibc-devel-2.28-72.el8_1.1.x86_64.rpm                                                                                 7.7 MB/s | 1.0 MB     00:00
(20/28): libxcrypt-devel-4.1.1-4.el8.x86_64.rpm                                                                                 1.4 MB/s |  25 kB     00:00
(21/28): pkgconf-1.4.2-1.el8.x86_64.rpm                                                                                         2.1 MB/s |  38 kB     00:00
(22/28): pkgconf-m4-1.4.2-1.el8.noarch.rpm                                                                                      1.1 MB/s |  17 kB     00:00
(23/28): pkgconf-pkg-config-1.4.2-1.el8.x86_64.rpm                                                                              1.5 MB/s |  15 kB     00:00
(24/28): python3-setuptools-39.2.0-5.el8.noarch.rpm                                                                              14 MB/s | 162 kB     00:00
(25/28): kernel-headers-4.18.0-147.8.1.el8_1.x86_64.rpm                                                                          12 MB/s | 2.7 MB     00:00
(26/28): glibc-common-2.28-72.el8_1.1.x86_64.rpm                                                                                 16 MB/s | 836 kB     00:00
(27/28): glibc-2.28-72.el8_1.1.x86_64.rpm                                                                                        11 MB/s | 3.7 MB     00:00
(28/28): glibc-all-langpacks-2.28-72.el8_1.1.x86_64.rpm                                                                          51 MB/s |  25 MB     00:00
----------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                            46 MB/s |  80 MB     00:01
warning: /var/cache/dnf/AppStream-a3ce6348fe6cbd6c/packages/cpp-8.3.1-4.5.el8.x86_64.rpm: Header V3 RSA/SHA256 Signature, key ID 8483c65d: NOKEY
CentOS-8 - AppStream                                                                                                            1.6 MB/s | 1.6 kB     00:00
Importing GPG key 0x8483C65D:
 Userid     : "CentOS (CentOS Official Signing Key) <security@centos.org>"
 Fingerprint: 99DB 70FA E1D7 CE22 7FB6 4882 05B5 55B3 8483 C65D
 From       : /etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
Key imported successfully
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                        1/1
  Upgrading        : glibc-all-langpacks-2.28-72.el8_1.1.x86_64                                                                                            1/31
  Upgrading        : glibc-common-2.28-72.el8_1.1.x86_64                                                                                                   2/31
  Running scriptlet: glibc-2.28-72.el8_1.1.x86_64                                                                                                          3/31
  Upgrading        : glibc-2.28-72.el8_1.1.x86_64                                                                                                          3/31
  Running scriptlet: glibc-2.28-72.el8_1.1.x86_64                                                                                                          3/31
  Installing       : libmpc-1.0.2-9.el8.x86_64                                                                                                             4/31
  Running scriptlet: libmpc-1.0.2-9.el8.x86_64                                                                                                             4/31
  Installing       : cpp-8.3.1-4.5.el8.x86_64                                                                                                              5/31
  Running scriptlet: cpp-8.3.1-4.5.el8.x86_64                                                                                                              5/31
  Installing       : isl-0.16.1-6.el8.x86_64                                                                                                               6/31
  Running scriptlet: isl-0.16.1-6.el8.x86_64                                                                                                               6/31
  Installing       : nmap-ncat-2:7.70-5.el8.x86_64                                                                                                         7/31
  Running scriptlet: nmap-ncat-2:7.70-5.el8.x86_64                                                                                                         7/31
  Installing       : yajl-2.1.0-10.el8.x86_64                                                                                                              8/31
  Installing       : avahi-libs-0.7-19.el8.x86_64                                                                                                          9/31
  Installing       : binutils-2.30-58.el8_1.2.x86_64                                                                                                      10/31
  Running scriptlet: binutils-2.30-58.el8_1.2.x86_64                                                                                                      10/31
  Running scriptlet: cyrus-sasl-2.1.27-1.el8.x86_64                                                                                                       11/31
  Installing       : cyrus-sasl-2.1.27-1.el8.x86_64                                                                                                       11/31
  Running scriptlet: cyrus-sasl-2.1.27-1.el8.x86_64                                                                                                       11/31
  Installing       : cyrus-sasl-gssapi-2.1.27-1.el8.x86_64                                                                                                12/31
  Installing       : libvirt-libs-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64                                                                           13/31
  Installing       : libpkgconf-1.4.2-1.el8.x86_64                                                                                                        14/31
  Installing       : pkgconf-1.4.2-1.el8.x86_64                                                                                                           15/31
  Installing       : python3-setuptools-39.2.0-5.el8.noarch                                                                                               16/31
  Installing       : python36-3.6.8-2.module_el8.1.0+245+c39af44f.x86_64                                                                                  17/31
  Running scriptlet: python36-3.6.8-2.module_el8.1.0+245+c39af44f.x86_64                                                                                  17/31
  Installing       : python3-pip-9.0.3-15.el8.noarch                                                                                                      18/31
  Installing       : pkgconf-m4-1.4.2-1.el8.noarch                                                                                                        19/31
  Installing       : pkgconf-pkg-config-1.4.2-1.el8.x86_64                                                                                                20/31
  Installing       : kernel-headers-4.18.0-147.8.1.el8_1.x86_64                                                                                           21/31
  Running scriptlet: glibc-headers-2.28-72.el8_1.1.x86_64                                                                                                 22/31
  Installing       : glibc-headers-2.28-72.el8_1.1.x86_64                                                                                                 22/31
  Installing       : libxcrypt-devel-4.1.1-4.el8.x86_64                                                                                                   23/31
  Installing       : glibc-devel-2.28-72.el8_1.1.x86_64                                                                                                   24/31
  Running scriptlet: glibc-devel-2.28-72.el8_1.1.x86_64                                                                                                   24/31
  Installing       : gcc-8.3.1-4.5.el8.x86_64                                                                                                             25/31
  Running scriptlet: gcc-8.3.1-4.5.el8.x86_64                                                                                                             25/31
  Installing       : libvirt-devel-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64                                                                          26/31
  Installing       : python3-libvirt-4.5.0-2.module_el8.1.0+248+298dec18.x86_64                                                                           27/31
  Installing       : ipmitool-1.8.18-12.el8_1.x86_64                                                                                                      28/31
  Cleanup          : glibc-common-2.28-72.el8.x86_64                                                                                                      29/31
  Cleanup          : glibc-2.28-72.el8.x86_64                                                                                                             30/31
  Cleanup          : glibc-all-langpacks-2.28-72.el8.x86_64                                                                                               31/31
  Running scriptlet: glibc-all-langpacks-2.28-72.el8.x86_64                                                                                               31/31
  Running scriptlet: glibc-all-langpacks-2.28-72.el8_1.1.x86_64                                                                                           31/31
  Running scriptlet: glibc-all-langpacks-2.28-72.el8.x86_64                                                                                               31/31
  Running scriptlet: glibc-common-2.28-72.el8_1.1.x86_64                                                                                                  31/31
  Verifying        : cpp-8.3.1-4.5.el8.x86_64                                                                                                              1/31
  Verifying        : gcc-8.3.1-4.5.el8.x86_64                                                                                                              2/31
  Verifying        : ipmitool-1.8.18-12.el8_1.x86_64                                                                                                       3/31
  Verifying        : isl-0.16.1-6.el8.x86_64                                                                                                               4/31
  Verifying        : libmpc-1.0.2-9.el8.x86_64                                                                                                             5/31
  Verifying        : libvirt-devel-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64                                                                           6/31
  Verifying        : libvirt-libs-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64                                                                            7/31
  Verifying        : nmap-ncat-2:7.70-5.el8.x86_64                                                                                                         8/31
  Verifying        : python3-libvirt-4.5.0-2.module_el8.1.0+248+298dec18.x86_64                                                                            9/31
  Verifying        : python3-pip-9.0.3-15.el8.noarch                                                                                                      10/31
  Verifying        : python36-3.6.8-2.module_el8.1.0+245+c39af44f.x86_64                                                                                  11/31
  Verifying        : yajl-2.1.0-10.el8.x86_64                                                                                                             12/31
  Verifying        : avahi-libs-0.7-19.el8.x86_64                                                                                                         13/31
  Verifying        : binutils-2.30-58.el8_1.2.x86_64                                                                                                      14/31
  Verifying        : cyrus-sasl-2.1.27-1.el8.x86_64                                                                                                       15/31
  Verifying        : cyrus-sasl-gssapi-2.1.27-1.el8.x86_64                                                                                                16/31
  Verifying        : glibc-devel-2.28-72.el8_1.1.x86_64                                                                                                   17/31
  Verifying        : glibc-headers-2.28-72.el8_1.1.x86_64                                                                                                 18/31
  Verifying        : kernel-headers-4.18.0-147.8.1.el8_1.x86_64                                                                                           19/31
  Verifying        : libpkgconf-1.4.2-1.el8.x86_64                                                                                                        20/31
  Verifying        : libxcrypt-devel-4.1.1-4.el8.x86_64                                                                                                   21/31
  Verifying        : pkgconf-1.4.2-1.el8.x86_64                                                                                                           22/31
  Verifying        : pkgconf-m4-1.4.2-1.el8.noarch                                                                                                        23/31
  Verifying        : pkgconf-pkg-config-1.4.2-1.el8.x86_64                                                                                                24/31
  Verifying        : python3-setuptools-39.2.0-5.el8.noarch                                                                                               25/31
  Verifying        : glibc-2.28-72.el8_1.1.x86_64                                                                                                         26/31
  Verifying        : glibc-2.28-72.el8.x86_64                                                                                                             27/31
  Verifying        : glibc-all-langpacks-2.28-72.el8_1.1.x86_64                                                                                           28/31
  Verifying        : glibc-all-langpacks-2.28-72.el8.x86_64                                                                                               29/31
  Verifying        : glibc-common-2.28-72.el8_1.1.x86_64                                                                                                  30/31
  Verifying        : glibc-common-2.28-72.el8.x86_64                                                                                                      31/31

Upgraded:
  glibc-2.28-72.el8_1.1.x86_64                  glibc-all-langpacks-2.28-72.el8_1.1.x86_64                  glibc-common-2.28-72.el8_1.1.x86_64

Installed:
  gcc-8.3.1-4.5.el8.x86_64                                                        ipmitool-1.8.18-12.el8_1.x86_64
  libvirt-devel-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64                     python3-libvirt-4.5.0-2.module_el8.1.0+248+298dec18.x86_64
  python36-3.6.8-2.module_el8.1.0+245+c39af44f.x86_64                             pkgconf-pkg-config-1.4.2-1.el8.x86_64
  cpp-8.3.1-4.5.el8.x86_64                                                        isl-0.16.1-6.el8.x86_64
  libmpc-1.0.2-9.el8.x86_64                                                       libvirt-libs-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64
  nmap-ncat-2:7.70-5.el8.x86_64                                                   python3-pip-9.0.3-15.el8.noarch
  yajl-2.1.0-10.el8.x86_64                                                        avahi-libs-0.7-19.el8.x86_64
  binutils-2.30-58.el8_1.2.x86_64                                                 cyrus-sasl-2.1.27-1.el8.x86_64
  cyrus-sasl-gssapi-2.1.27-1.el8.x86_64                                           glibc-devel-2.28-72.el8_1.1.x86_64
  glibc-headers-2.28-72.el8_1.1.x86_64                                            kernel-headers-4.18.0-147.8.1.el8_1.x86_64
  libpkgconf-1.4.2-1.el8.x86_64                                                   libxcrypt-devel-4.1.1-4.el8.x86_64
  pkgconf-1.4.2-1.el8.x86_64                                                      pkgconf-m4-1.4.2-1.el8.noarch
  python3-setuptools-39.2.0-5.el8.noarch

Complete!
WARNING: Running pip install with root privileges is generally not a good idea. Try `pip3 install --user` instead.
Collecting virtualbmc
  Downloading https://files.pythonhosted.org/packages/85/b3/bcf54457a7a23df476ce61ce3e54228d666a11c608ef0601da6e831630dd/virtualbmc-2.1.0-py3-none-any.whl
Collecting pyghmi>=1.0.22 (from virtualbmc)
  Downloading https://files.pythonhosted.org/packages/f8/41/6e98294c5cba3da371cb204bf2e95eeeb37c7e23f4f23a1d49235f6b1049/pyghmi-1.5.14-py3-none-any.whl (226kB)
    100% |████████████████████████████████| 235kB 3.3MB/s
Requirement already satisfied: libvirt-python!=4.1.0,>=3.7.0 in /usr/lib64/python3.6/site-packages (from virtualbmc)
Collecting pbr!=2.1.0,>=2.0.0 (from virtualbmc)
  Downloading https://files.pythonhosted.org/packages/96/ba/aa953a11ec014b23df057ecdbc922fdb40ca8463466b1193f3367d2711a6/pbr-5.4.5-py2.py3-none-any.whl (110kB)
    100% |████████████████████████████████| 112kB 5.1MB/s
Collecting cliff!=2.9.0,>=2.8.0 (from virtualbmc)
  Downloading https://files.pythonhosted.org/packages/b9/17/57187872842bf9f65815b6969b515528ec7fd754137d2d3f49e3bc016175/cliff-3.1.0-py3-none-any.whl (80kB)
    100% |████████████████████████████████| 81kB 6.6MB/s
Collecting pyzmq>=14.3.1 (from virtualbmc)
  Downloading https://files.pythonhosted.org/packages/c9/11/bb28199dd8f186a4053b7dd94a33abf0c1162d99203e7ab32a6b71fa045b/pyzmq-19.0.1-cp36-cp36m-manylinux1_x86_64.whl (1.1MB)
    100% |████████████████████████████████| 1.1MB 936kB/s
Requirement already satisfied: cryptography>=2.1 in /usr/lib64/python3.6/site-packages (from pyghmi>=1.0.22->virtualbmc)
Collecting python-dateutil>=2.8.1 (from pyghmi>=1.0.22->virtualbmc)
  Downloading https://files.pythonhosted.org/packages/d4/70/d60450c3dd48ef87586924207ae8907090de0b306af2bce5d134d78615cb/python_dateutil-2.8.1-py2.py3-none-any.whl (227kB)
    100% |████████████████████████████████| 235kB 4.0MB/s
Requirement already satisfied: six>=1.10.0 in /usr/lib/python3.6/site-packages (from pyghmi>=1.0.22->virtualbmc)
Collecting stevedore>=1.20.0 (from cliff!=2.9.0,>=2.8.0->virtualbmc)
  Downloading https://files.pythonhosted.org/packages/e6/49/a35dd566626892d577e426dbe5ea424dd7fbe10645f2c1070dcba474eca9/stevedore-1.32.0-py2.py3-none-any.whl (43kB)
    100% |████████████████████████████████| 51kB 7.6MB/s
Collecting pyparsing>=2.1.0 (from cliff!=2.9.0,>=2.8.0->virtualbmc)
  Downloading https://files.pythonhosted.org/packages/8a/bb/488841f56197b13700afd5658fc279a2025a39e22449b7cf29864669b15d/pyparsing-2.4.7-py2.py3-none-any.whl (67kB)
    100% |████████████████████████████████| 71kB 4.1MB/s
Requirement already satisfied: PyYAML>=3.12 in /usr/lib64/python3.6/site-packages (from cliff!=2.9.0,>=2.8.0->virtualbmc)
Collecting cmd2!=0.8.3,<0.9.0,>=0.8.0 (from cliff!=2.9.0,>=2.8.0->virtualbmc)
  Downloading https://files.pythonhosted.org/packages/e9/40/a71caa2aaff10c73612a7106e2d35f693e85b8cf6e37ab0774274bca3cf9/cmd2-0.8.9-py2.py3-none-any.whl (53kB)
    100% |████████████████████████████████| 61kB 8.2MB/s
Requirement already satisfied: PrettyTable<0.8,>=0.7.2 in /usr/lib/python3.6/site-packages (from cliff!=2.9.0,>=2.8.0->virtualbmc)
Requirement already satisfied: idna>=2.1 in /usr/lib/python3.6/site-packages (from cryptography>=2.1->pyghmi>=1.0.22->virtualbmc)
Requirement already satisfied: asn1crypto>=0.21.0 in /usr/lib/python3.6/site-packages (from cryptography>=2.1->pyghmi>=1.0.22->virtualbmc)
Requirement already satisfied: cffi!=1.11.3,>=1.7 in /usr/lib64/python3.6/site-packages (from cryptography>=2.1->pyghmi>=1.0.22->virtualbmc)
Collecting wcwidth; sys_platform != "win32" (from cmd2!=0.8.3,<0.9.0,>=0.8.0->cliff!=2.9.0,>=2.8.0->virtualbmc)
  Downloading https://files.pythonhosted.org/packages/f6/d5/1ecdac957e3ea12c1b319fcdee8b6917ffaff8b4644d673c4d72d2f20b49/wcwidth-0.1.9-py2.py3-none-any.whl
Collecting pyperclip (from cmd2!=0.8.3,<0.9.0,>=0.8.0->cliff!=2.9.0,>=2.8.0->virtualbmc)
  Downloading https://files.pythonhosted.org/packages/f6/5b/55866e1cde0f86f5eec59dab5de8a66628cb0d53da74b8dbc15ad8dabda3/pyperclip-1.8.0.tar.gz
Requirement already satisfied: pycparser in /usr/lib/python3.6/site-packages (from cffi!=1.11.3,>=1.7->cryptography>=2.1->pyghmi>=1.0.22->virtualbmc)
Installing collected packages: python-dateutil, pyghmi, pbr, stevedore, pyparsing, wcwidth, pyperclip, cmd2, cliff, pyzmq, virtualbmc
  Running setup.py install for pyperclip ... done
Successfully installed cliff-3.1.0 cmd2-0.8.9 pbr-5.4.5 pyghmi-1.5.14 pyparsing-2.4.7 pyperclip-1.8.0 python-dateutil-2.8.1 pyzmq-19.0.1 stevedore-1.32.0 virtualbmc-2.1.0 wcwidth-0.1.9
# 192.168.1.6:22 SSH-2.0-OpenSSH_8.0
# 192.168.1.6:22 SSH-2.0-OpenSSH_8.0
# 192.168.1.6:22 SSH-2.0-OpenSSH_8.0
```

This script performs the following tasks:

- Install libvirt requirements as needed by the installer.
- Install virtualbmc and launch vbmcd daemon.
- Launch an helper script which registers the vms acting as masters in vbmc with default credentials set to jimi/hendrix (Yeah!)
- Patch accordingly install-config.yaml.

After the script is finished, we can verify that our masters are actually defined in vbmc with the following command:

```
vbmc list
```

Expected Output

```
+--------------+---------+---------+------+
| Domain name  | Status  | Address | Port |
+--------------+---------+---------+------+
| lab-master-0 | running | ::      | 6230 |
| lab-master-1 | running | ::      | 6231 |
| lab-master-2 | running | ::      | 6232 |
+--------------+---------+---------+------+
```

Virtual BMC allows us to treat those virtual masters as if they were physical nodes at IPMI level.

For instance, we can check power status of our first master, which we associated to port *6230*:

```
IP=$(hostname -I)
ipmitool -H $IP -U jimi -P hendrix -I lanplus -p 6230 chassis power status
```

Expected Output

```
Chassis Power is off
```

Futhermore, the helper script `ipmi.py` can be used to report power status of all the nodes defined in *install-config.yaml*

```
ipmi.py status
```

Expected Output

```
ipmitool -H 192.168.123.234 -U root -P calvin -I lanplus -p 6230 chassis power status
Chassis Power is off
ipmitool -H 192.168.123.234 -U root -P calvin -I lanplus -p 6231 chassis power status
Chassis Power is off
ipmitool -H 192.168.123.234 -U root -P calvin -I lanplus -p 6232 chassis power status
Chassis Power is off
```

We will use this same script prior to deploying Openshift to make sure all the nodes are powered off prior to launching deployment.

In a full baremetal setup, virtualbmc wouldn't be needed but only access through IPMI to the nodes of the install. The helper script is still usable in this context.

# Initial installconfig modifications

In this section, we do a basic patching of install-config.yaml to add mandatory elements to it:

```
/root/01_patch_installconfig.sh
```

Expected Output

```
# 192.168.1.6:22 SSH-2.0-OpenSSH_8.0
# 192.168.1.6:22 SSH-2.0-OpenSSH_8.0
# 192.168.1.6:22 SSH-2.0-OpenSSH_8.0
```

This script adds pull secret and public key to *install-config.yaml*.

# Package requisites

In this section, we add some required packages:

```
/root/02_packages.sh
```

Expected Output

```
Last metadata expiration check: 0:24:05 ago on Tue 12 May 2020 01:50:05 PM UTC.
Package libvirt-libs-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64 is already installed.
Package ipmitool-1.8.18-12.el8_1.x86_64 is already installed.
Dependencies resolved.
================================================================================================================================================================
 Package                                   Architecture             Version                                                   Repository                   Size
================================================================================================================================================================
Installing:
 genisoimage                               x86_64                   1.1.11-39.el8                                             AppStream                   316 k
 git                                       x86_64                   2.18.2-2.el8_1                                            AppStream                   186 k
 libvirt-client                            x86_64                   4.5.0-35.3.module_el8.1.0+297+df420408                    AppStream                   351 k
 make                                      x86_64                   1:4.2.1-9.el8                                             BaseOS                      498 k
 tmux                                      x86_64                   2.7-1.el8                                                 BaseOS                      317 k
Installing dependencies:
 autogen-libopts                           x86_64                   5.18.12-7.el8                                             AppStream                    75 k
 git-core                                  x86_64                   2.18.2-2.el8_1                                            AppStream                   5.0 M
 git-core-doc                              noarch                   2.18.2-2.el8_1                                            AppStream                   2.3 M
 gnutls-dane                               x86_64                   3.6.8-8.el8                                               AppStream                    45 k
 gnutls-utils                              x86_64                   3.6.8-8.el8                                               AppStream                   341 k
 libusal                                   x86_64                   1.1.11-39.el8                                             AppStream                   145 k
 libvirt-bash-completion                   x86_64                   4.5.0-35.3.module_el8.1.0+297+df420408                    AppStream                    50 k
 perl-Digest                               noarch                   1.17-395.el8                                              AppStream                    27 k
 perl-Digest-MD5                           x86_64                   2.55-396.el8                                              AppStream                    37 k
 perl-Error                                noarch                   1:0.17025-2.el8                                           AppStream                    46 k
 perl-Git                                  noarch                   2.18.2-2.el8_1                                            AppStream                    77 k
 perl-Net-SSLeay                           x86_64                   1.88-1.el8                                                AppStream                   379 k
 perl-TermReadKey                          x86_64                   2.37-7.el8                                                AppStream                    40 k
 perl-URI                                  noarch                   1.73-3.el8                                                AppStream                   116 k
 perl-libnet                               noarch                   3.11-3.el8                                                AppStream                   121 k
 emacs-filesystem                          noarch                   1:26.1-5.el8                                              BaseOS                       69 k
 perl-Carp                                 noarch                   1.42-396.el8                                              BaseOS                       30 k
 perl-Data-Dumper                          x86_64                   2.167-399.el8                                             BaseOS                       58 k
 perl-Encode                               x86_64                   4:2.97-3.el8                                              BaseOS                      1.5 M
 perl-Errno                                x86_64                   1.28-416.el8                                              BaseOS                       76 k
 perl-Exporter                             noarch                   5.72-396.el8                                              BaseOS                       34 k
 perl-File-Path                            noarch                   2.15-2.el8                                                BaseOS                       38 k
 perl-File-Temp                            noarch                   0.230.600-1.el8                                           BaseOS                       63 k
 perl-Getopt-Long                          noarch                   1:2.50-4.el8                                              BaseOS                       63 k
 perl-HTTP-Tiny                            noarch                   0.074-1.el8                                               BaseOS                       58 k
 perl-IO                                   x86_64                   1.38-416.el8                                              BaseOS                      141 k
 perl-MIME-Base64                          x86_64                   3.15-396.el8                                              BaseOS                       31 k
 perl-PathTools                            x86_64                   3.74-1.el8                                                BaseOS                       90 k
 perl-Pod-Escapes                          noarch                   1:1.07-395.el8                                            BaseOS                       20 k
 perl-Pod-Perldoc                          noarch                   3.28-396.el8                                              BaseOS                       86 k
 perl-Pod-Simple                           noarch                   1:3.35-395.el8                                            BaseOS                      213 k
 perl-Pod-Usage                            noarch                   4:1.69-395.el8                                            BaseOS                       34 k
 perl-Scalar-List-Utils                    x86_64                   3:1.49-2.el8                                              BaseOS                       68 k
 perl-Socket                               x86_64                   4:2.027-3.el8                                             BaseOS                       59 k
 perl-Storable                             x86_64                   1:3.11-3.el8                                              BaseOS                       98 k
 perl-Term-ANSIColor                       noarch                   4.06-396.el8                                              BaseOS                       46 k
 perl-Term-Cap                             noarch                   1.17-395.el8                                              BaseOS                       23 k
 perl-Text-ParseWords                      noarch                   3.30-395.el8                                              BaseOS                       18 k
 perl-Text-Tabs+Wrap                       noarch                   2013.0523-395.el8                                         BaseOS                       24 k
 perl-Time-Local                           noarch                   1:1.280-1.el8                                             BaseOS                       34 k
 perl-Unicode-Normalize                    x86_64                   1.25-396.el8                                              BaseOS                       82 k
 perl-constant                             noarch                   1.33-396.el8                                              BaseOS                       25 k
 perl-interpreter                          x86_64                   4:5.26.3-416.el8                                          BaseOS                      6.3 M
 perl-libs                                 x86_64                   4:5.26.3-416.el8                                          BaseOS                      1.6 M
 perl-macros                               x86_64                   4:5.26.3-416.el8                                          BaseOS                       72 k
 perl-parent                               noarch                   1:0.237-1.el8                                             BaseOS                       20 k
 perl-podlators                            noarch                   4.11-1.el8                                                BaseOS                      118 k
 perl-threads                              x86_64                   1:2.21-2.el8                                              BaseOS                       61 k
 perl-threads-shared                       x86_64                   1.58-2.el8                                                BaseOS                       48 k
Installing weak dependencies:
 perl-IO-Socket-IP                         noarch                   0.39-5.el8                                                AppStream                    47 k
 perl-IO-Socket-SSL                        noarch                   2.066-3.el8                                               AppStream                   297 k
 perl-Mozilla-CA                           noarch                   20160104-7.el8                                            AppStream                    15 k

Transaction Summary
================================================================================================================================================================
Install  57 Packages

Total download size: 22 M
Installed size: 84 M
Downloading Packages:
(1/57): autogen-libopts-5.18.12-7.el8.x86_64.rpm                                                                                1.0 MB/s |  75 kB     00:00
(2/57): git-2.18.2-2.el8_1.x86_64.rpm                                                                                           2.1 MB/s | 186 kB     00:00
(3/57): genisoimage-1.1.11-39.el8.x86_64.rpm                                                                                    2.8 MB/s | 316 kB     00:00
(4/57): gnutls-dane-3.6.8-8.el8.x86_64.rpm                                                                                      1.9 MB/s |  45 kB     00:00
(5/57): gnutls-utils-3.6.8-8.el8.x86_64.rpm                                                                                     6.8 MB/s | 341 kB     00:00
(6/57): git-core-doc-2.18.2-2.el8_1.noarch.rpm                                                                                   17 MB/s | 2.3 MB     00:00
(7/57): libusal-1.1.11-39.el8.x86_64.rpm                                                                                        3.1 MB/s | 145 kB     00:00
(8/57): libvirt-bash-completion-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64.rpm                                               2.8 MB/s |  50 kB     00:00
(9/57): perl-Digest-1.17-395.el8.noarch.rpm                                                                                     1.7 MB/s |  27 kB     00:00
(10/57): git-core-2.18.2-2.el8_1.x86_64.rpm                                                                                      22 MB/s | 5.0 MB     00:00
(11/57): perl-Digest-MD5-2.55-396.el8.x86_64.rpm                                                                                878 kB/s |  37 kB     00:00
(12/57): libvirt-client-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64.rpm                                                       4.7 MB/s | 351 kB     00:00
(13/57): perl-Git-2.18.2-2.el8_1.noarch.rpm                                                                                     4.4 MB/s |  77 kB     00:00
(14/57): perl-IO-Socket-IP-0.39-5.el8.noarch.rpm                                                                                2.9 MB/s |  47 kB     00:00
(15/57): perl-Error-0.17025-2.el8.noarch.rpm                                                                                    1.7 MB/s |  46 kB     00:00
(16/57): perl-Mozilla-CA-20160104-7.el8.noarch.rpm                                                                              907 kB/s |  15 kB     00:00
(17/57): perl-TermReadKey-2.37-7.el8.x86_64.rpm                                                                                 2.0 MB/s |  40 kB     00:00
(18/57): perl-IO-Socket-SSL-2.066-3.el8.noarch.rpm                                                                              6.3 MB/s | 297 kB     00:00
(19/57): perl-Net-SSLeay-1.88-1.el8.x86_64.rpm                                                                                  7.5 MB/s | 379 kB     00:00
(20/57): perl-URI-1.73-3.el8.noarch.rpm                                                                                         3.5 MB/s | 116 kB     00:00
(21/57): make-4.2.1-9.el8.x86_64.rpm                                                                                            6.9 MB/s | 498 kB     00:00
(22/57): emacs-filesystem-26.1-5.el8.noarch.rpm                                                                                 661 kB/s |  69 kB     00:00
(23/57): perl-Carp-1.42-396.el8.noarch.rpm                                                                                      1.1 MB/s |  30 kB     00:00
(24/57): perl-Data-Dumper-2.167-399.el8.x86_64.rpm                                                                              1.0 MB/s |  58 kB     00:00
(25/57): perl-libnet-3.11-3.el8.noarch.rpm                                                                                      435 kB/s | 121 kB     00:00
(26/57): perl-Encode-2.97-3.el8.x86_64.rpm                                                                                      8.2 MB/s | 1.5 MB     00:00
(27/57): perl-Errno-1.28-416.el8.x86_64.rpm                                                                                     446 kB/s |  76 kB     00:00
(28/57): perl-Exporter-5.72-396.el8.noarch.rpm                                                                                  495 kB/s |  34 kB     00:00
(29/57): perl-File-Path-2.15-2.el8.noarch.rpm                                                                                   815 kB/s |  38 kB     00:00
(30/57): perl-HTTP-Tiny-0.074-1.el8.noarch.rpm                                                                                  5.3 MB/s |  58 kB     00:00
(31/57): perl-Getopt-Long-2.50-4.el8.noarch.rpm                                                                                 2.7 MB/s |  63 kB     00:00
(32/57): perl-IO-1.38-416.el8.x86_64.rpm                                                                                         10 MB/s | 141 kB     00:00
(33/57): perl-MIME-Base64-3.15-396.el8.x86_64.rpm                                                                               1.9 MB/s |  31 kB     00:00
(34/57): perl-File-Temp-0.230.600-1.el8.noarch.rpm                                                                              898 kB/s |  63 kB     00:00
(35/57): perl-Pod-Escapes-1.07-395.el8.noarch.rpm                                                                               727 kB/s |  20 kB     00:00
(36/57): perl-PathTools-3.74-1.el8.x86_64.rpm                                                                                   2.2 MB/s |  90 kB     00:00
(37/57): perl-Pod-Perldoc-3.28-396.el8.noarch.rpm                                                                               4.0 MB/s |  86 kB     00:00
(38/57): perl-Pod-Usage-1.69-395.el8.noarch.rpm                                                                                 1.6 MB/s |  34 kB     00:00
(39/57): perl-Pod-Simple-3.35-395.el8.noarch.rpm                                                                                6.5 MB/s | 213 kB     00:00
(40/57): perl-Socket-2.027-3.el8.x86_64.rpm                                                                                     1.5 MB/s |  59 kB     00:00
(41/57): perl-Scalar-List-Utils-1.49-2.el8.x86_64.rpm                                                                           1.4 MB/s |  68 kB     00:00
(42/57): perl-Storable-3.11-3.el8.x86_64.rpm                                                                                    2.4 MB/s |  98 kB     00:00
(43/57): perl-Text-ParseWords-3.30-395.el8.noarch.rpm                                                                           2.5 MB/s |  18 kB     00:00
(44/57): perl-Term-ANSIColor-4.06-396.el8.noarch.rpm                                                                            2.3 MB/s |  46 kB     00:00
(45/57): perl-Text-Tabs+Wrap-2013.0523-395.el8.noarch.rpm                                                                       3.1 MB/s |  24 kB     00:00
(46/57): perl-Unicode-Normalize-1.25-396.el8.x86_64.rpm                                                                         7.9 MB/s |  82 kB     00:00
(47/57): perl-Time-Local-1.280-1.el8.noarch.rpm                                                                                 1.7 MB/s |  34 kB     00:00
(48/57): perl-Term-Cap-1.17-395.el8.noarch.rpm                                                                                  554 kB/s |  23 kB     00:00
(49/57): perl-constant-1.33-396.el8.noarch.rpm                                                                                  2.5 MB/s |  25 kB     00:00
(50/57): perl-macros-5.26.3-416.el8.x86_64.rpm                                                                                  533 kB/s |  72 kB     00:00
(51/57): perl-libs-5.26.3-416.el8.x86_64.rpm                                                                                    8.0 MB/s | 1.6 MB     00:00
(52/57): perl-parent-0.237-1.el8.noarch.rpm                                                                                     221 kB/s |  20 kB     00:00
(53/57): perl-podlators-4.11-1.el8.noarch.rpm                                                                                   742 kB/s | 118 kB     00:00
(54/57): perl-threads-2.21-2.el8.x86_64.rpm                                                                                     409 kB/s |  61 kB     00:00
(55/57): perl-interpreter-5.26.3-416.el8.x86_64.rpm                                                                              12 MB/s | 6.3 MB     00:00
(56/57): perl-threads-shared-1.58-2.el8.x86_64.rpm                                                                              249 kB/s |  48 kB     00:00
(57/57): tmux-2.7-1.el8.x86_64.rpm                                                                                              1.8 MB/s | 317 kB     00:00
----------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                            11 MB/s |  22 MB     00:02
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                        1/1
  Installing       : perl-Exporter-5.72-396.el8.noarch                                                                                                     1/57
  Installing       : perl-libs-4:5.26.3-416.el8.x86_64                                                                                                     2/57
  Installing       : perl-Carp-1.42-396.el8.noarch                                                                                                         3/57
  Installing       : perl-Scalar-List-Utils-3:1.49-2.el8.x86_64                                                                                            4/57
  Installing       : perl-parent-1:0.237-1.el8.noarch                                                                                                      5/57
  Installing       : perl-Text-ParseWords-3.30-395.el8.noarch                                                                                              6/57
  Installing       : git-core-2.18.2-2.el8_1.x86_64                                                                                                        7/57
  Installing       : git-core-doc-2.18.2-2.el8_1.noarch                                                                                                    8/57
  Installing       : perl-Term-ANSIColor-4.06-396.el8.noarch                                                                                               9/57
  Installing       : perl-macros-4:5.26.3-416.el8.x86_64                                                                                                  10/57
  Installing       : perl-Errno-1.28-416.el8.x86_64                                                                                                       11/57
  Installing       : perl-Socket-4:2.027-3.el8.x86_64                                                                                                     12/57
  Installing       : perl-Text-Tabs+Wrap-2013.0523-395.el8.noarch                                                                                         13/57
  Installing       : perl-Unicode-Normalize-1.25-396.el8.x86_64                                                                                           14/57
  Installing       : perl-File-Path-2.15-2.el8.noarch                                                                                                     15/57
  Installing       : perl-IO-1.38-416.el8.x86_64                                                                                                          16/57
  Installing       : perl-PathTools-3.74-1.el8.x86_64                                                                                                     17/57
  Installing       : perl-constant-1.33-396.el8.noarch                                                                                                    18/57
  Installing       : perl-threads-1:2.21-2.el8.x86_64                                                                                                     19/57
  Installing       : perl-threads-shared-1.58-2.el8.x86_64                                                                                                20/57
  Installing       : perl-interpreter-4:5.26.3-416.el8.x86_64                                                                                             21/57
  Installing       : perl-MIME-Base64-3.15-396.el8.x86_64                                                                                                 22/57
  Installing       : perl-IO-Socket-IP-0.39-5.el8.noarch                                                                                                  23/57
  Installing       : perl-Time-Local-1:1.280-1.el8.noarch                                                                                                 24/57
  Installing       : perl-File-Temp-0.230.600-1.el8.noarch                                                                                                25/57
  Installing       : perl-Digest-1.17-395.el8.noarch                                                                                                      26/57
  Installing       : perl-Digest-MD5-2.55-396.el8.x86_64                                                                                                  27/57
  Installing       : perl-Net-SSLeay-1.88-1.el8.x86_64                                                                                                    28/57
  Installing       : perl-Error-1:0.17025-2.el8.noarch                                                                                                    29/57
  Installing       : perl-TermReadKey-2.37-7.el8.x86_64                                                                                                   30/57
  Installing       : perl-Data-Dumper-2.167-399.el8.x86_64                                                                                                31/57
  Installing       : perl-Pod-Escapes-1:1.07-395.el8.noarch                                                                                               32/57
  Installing       : perl-Storable-1:3.11-3.el8.x86_64                                                                                                    33/57
  Installing       : perl-Term-Cap-1.17-395.el8.noarch                                                                                                    34/57
  Installing       : perl-Mozilla-CA-20160104-7.el8.noarch                                                                                                35/57
  Installing       : perl-Encode-4:2.97-3.el8.x86_64                                                                                                      36/57
  Installing       : perl-Pod-Simple-1:3.35-395.el8.noarch                                                                                                37/57
  Installing       : perl-Getopt-Long-1:2.50-4.el8.noarch                                                                                                 38/57
  Installing       : perl-podlators-4.11-1.el8.noarch                                                                                                     39/57
  Installing       : perl-Pod-Usage-4:1.69-395.el8.noarch                                                                                                 40/57
  Installing       : perl-Pod-Perldoc-3.28-396.el8.noarch                                                                                                 41/57
  Installing       : perl-HTTP-Tiny-0.074-1.el8.noarch                                                                                                    42/57
  Installing       : perl-IO-Socket-SSL-2.066-3.el8.noarch                                                                                                43/57
  Installing       : perl-libnet-3.11-3.el8.noarch                                                                                                        44/57
  Installing       : perl-URI-1.73-3.el8.noarch                                                                                                           45/57
  Installing       : emacs-filesystem-1:26.1-5.el8.noarch                                                                                                 46/57
  Installing       : perl-Git-2.18.2-2.el8_1.noarch                                                                                                       47/57
  Installing       : git-2.18.2-2.el8_1.x86_64                                                                                                            48/57
  Installing       : libvirt-bash-completion-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64                                                                49/57
  Installing       : libusal-1.1.11-39.el8.x86_64                                                                                                         50/57
  Running scriptlet: libusal-1.1.11-39.el8.x86_64                                                                                                         50/57
  Installing       : gnutls-dane-3.6.8-8.el8.x86_64                                                                                                       51/57
  Installing       : autogen-libopts-5.18.12-7.el8.x86_64                                                                                                 52/57
  Installing       : gnutls-utils-3.6.8-8.el8.x86_64                                                                                                      53/57
  Installing       : libvirt-client-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64                                                                         54/57
  Running scriptlet: libvirt-client-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64                                                                         54/57
  Installing       : genisoimage-1.1.11-39.el8.x86_64                                                                                                     55/57
  Running scriptlet: genisoimage-1.1.11-39.el8.x86_64                                                                                                     55/57
  Installing       : tmux-2.7-1.el8.x86_64                                                                                                                56/57
  Running scriptlet: tmux-2.7-1.el8.x86_64                                                                                                                56/57
  Installing       : make-1:4.2.1-9.el8.x86_64                                                                                                            57/57
  Running scriptlet: make-1:4.2.1-9.el8.x86_64                                                                                                            57/57
  Verifying        : autogen-libopts-5.18.12-7.el8.x86_64                                                                                                  1/57
  Verifying        : genisoimage-1.1.11-39.el8.x86_64                                                                                                      2/57
  Verifying        : git-2.18.2-2.el8_1.x86_64                                                                                                             3/57
  Verifying        : git-core-2.18.2-2.el8_1.x86_64                                                                                                        4/57
  Verifying        : git-core-doc-2.18.2-2.el8_1.noarch                                                                                                    5/57
  Verifying        : gnutls-dane-3.6.8-8.el8.x86_64                                                                                                        6/57
  Verifying        : gnutls-utils-3.6.8-8.el8.x86_64                                                                                                       7/57
  Verifying        : libusal-1.1.11-39.el8.x86_64                                                                                                          8/57
  Verifying        : libvirt-bash-completion-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64                                                                 9/57
  Verifying        : libvirt-client-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64                                                                         10/57
  Verifying        : perl-Digest-1.17-395.el8.noarch                                                                                                      11/57
  Verifying        : perl-Digest-MD5-2.55-396.el8.x86_64                                                                                                  12/57
  Verifying        : perl-Error-1:0.17025-2.el8.noarch                                                                                                    13/57
  Verifying        : perl-Git-2.18.2-2.el8_1.noarch                                                                                                       14/57
  Verifying        : perl-IO-Socket-IP-0.39-5.el8.noarch                                                                                                  15/57
  Verifying        : perl-IO-Socket-SSL-2.066-3.el8.noarch                                                                                                16/57
  Verifying        : perl-Mozilla-CA-20160104-7.el8.noarch                                                                                                17/57
  Verifying        : perl-Net-SSLeay-1.88-1.el8.x86_64                                                                                                    18/57
  Verifying        : perl-TermReadKey-2.37-7.el8.x86_64                                                                                                   19/57
  Verifying        : perl-URI-1.73-3.el8.noarch                                                                                                           20/57
  Verifying        : perl-libnet-3.11-3.el8.noarch                                                                                                        21/57
  Verifying        : emacs-filesystem-1:26.1-5.el8.noarch                                                                                                 22/57
  Verifying        : make-1:4.2.1-9.el8.x86_64                                                                                                            23/57
  Verifying        : perl-Carp-1.42-396.el8.noarch                                                                                                        24/57
  Verifying        : perl-Data-Dumper-2.167-399.el8.x86_64                                                                                                25/57
  Verifying        : perl-Encode-4:2.97-3.el8.x86_64                                                                                                      26/57
  Verifying        : perl-Errno-1.28-416.el8.x86_64                                                                                                       27/57
  Verifying        : perl-Exporter-5.72-396.el8.noarch                                                                                                    28/57
  Verifying        : perl-File-Path-2.15-2.el8.noarch                                                                                                     29/57
  Verifying        : perl-File-Temp-0.230.600-1.el8.noarch                                                                                                30/57
  Verifying        : perl-Getopt-Long-1:2.50-4.el8.noarch                                                                                                 31/57
  Verifying        : perl-HTTP-Tiny-0.074-1.el8.noarch                                                                                                    32/57
  Verifying        : perl-IO-1.38-416.el8.x86_64                                                                                                          33/57
  Verifying        : perl-MIME-Base64-3.15-396.el8.x86_64                                                                                                 34/57
  Verifying        : perl-PathTools-3.74-1.el8.x86_64                                                                                                     35/57
  Verifying        : perl-Pod-Escapes-1:1.07-395.el8.noarch                                                                                               36/57
  Verifying        : perl-Pod-Perldoc-3.28-396.el8.noarch                                                                                                 37/57
  Verifying        : perl-Pod-Simple-1:3.35-395.el8.noarch                                                                                                38/57
  Verifying        : perl-Pod-Usage-4:1.69-395.el8.noarch                                                                                                 39/57
  Verifying        : perl-Scalar-List-Utils-3:1.49-2.el8.x86_64                                                                                           40/57
  Verifying        : perl-Socket-4:2.027-3.el8.x86_64                                                                                                     41/57
  Verifying        : perl-Storable-1:3.11-3.el8.x86_64                                                                                                    42/57
  Verifying        : perl-Term-ANSIColor-4.06-396.el8.noarch                                                                                              43/57
  Verifying        : perl-Term-Cap-1.17-395.el8.noarch                                                                                                    44/57
  Verifying        : perl-Text-ParseWords-3.30-395.el8.noarch                                                                                             45/57
  Verifying        : perl-Text-Tabs+Wrap-2013.0523-395.el8.noarch                                                                                         46/57
  Verifying        : perl-Time-Local-1:1.280-1.el8.noarch                                                                                                 47/57
  Verifying        : perl-Unicode-Normalize-1.25-396.el8.x86_64                                                                                           48/57
  Verifying        : perl-constant-1.33-396.el8.noarch                                                                                                    49/57
  Verifying        : perl-interpreter-4:5.26.3-416.el8.x86_64                                                                                             50/57
  Verifying        : perl-libs-4:5.26.3-416.el8.x86_64                                                                                                    51/57
  Verifying        : perl-macros-4:5.26.3-416.el8.x86_64                                                                                                  52/57
  Verifying        : perl-parent-1:0.237-1.el8.noarch                                                                                                     53/57
  Verifying        : perl-podlators-4.11-1.el8.noarch                                                                                                     54/57
  Verifying        : perl-threads-1:2.21-2.el8.x86_64                                                                                                     55/57
  Verifying        : perl-threads-shared-1.58-2.el8.x86_64                                                                                                56/57
  Verifying        : tmux-2.7-1.el8.x86_64                                                                                                                57/57

Installed:
  genisoimage-1.1.11-39.el8.x86_64           git-2.18.2-2.el8_1.x86_64                    libvirt-client-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64
  make-1:4.2.1-9.el8.x86_64                  tmux-2.7-1.el8.x86_64                        perl-IO-Socket-IP-0.39-5.el8.noarch
  perl-IO-Socket-SSL-2.066-3.el8.noarch      perl-Mozilla-CA-20160104-7.el8.noarch        autogen-libopts-5.18.12-7.el8.x86_64
  git-core-2.18.2-2.el8_1.x86_64             git-core-doc-2.18.2-2.el8_1.noarch           gnutls-dane-3.6.8-8.el8.x86_64
  gnutls-utils-3.6.8-8.el8.x86_64            libusal-1.1.11-39.el8.x86_64                 libvirt-bash-completion-4.5.0-35.3.module_el8.1.0+297+df420408.x86_64
  perl-Digest-1.17-395.el8.noarch            perl-Digest-MD5-2.55-396.el8.x86_64          perl-Error-1:0.17025-2.el8.noarch
  perl-Git-2.18.2-2.el8_1.noarch             perl-Net-SSLeay-1.88-1.el8.x86_64            perl-TermReadKey-2.37-7.el8.x86_64
  perl-URI-1.73-3.el8.noarch                 perl-libnet-3.11-3.el8.noarch                emacs-filesystem-1:26.1-5.el8.noarch
  perl-Carp-1.42-396.el8.noarch              perl-Data-Dumper-2.167-399.el8.x86_64        perl-Encode-4:2.97-3.el8.x86_64
  perl-Errno-1.28-416.el8.x86_64             perl-Exporter-5.72-396.el8.noarch            perl-File-Path-2.15-2.el8.noarch
  perl-File-Temp-0.230.600-1.el8.noarch      perl-Getopt-Long-1:2.50-4.el8.noarch         perl-HTTP-Tiny-0.074-1.el8.noarch
  perl-IO-1.38-416.el8.x86_64                perl-MIME-Base64-3.15-396.el8.x86_64         perl-PathTools-3.74-1.el8.x86_64
  perl-Pod-Escapes-1:1.07-395.el8.noarch     perl-Pod-Perldoc-3.28-396.el8.noarch         perl-Pod-Simple-1:3.35-395.el8.noarch
  perl-Pod-Usage-4:1.69-395.el8.noarch       perl-Scalar-List-Utils-3:1.49-2.el8.x86_64   perl-Socket-4:2.027-3.el8.x86_64
  perl-Storable-1:3.11-3.el8.x86_64          perl-Term-ANSIColor-4.06-396.el8.noarch      perl-Term-Cap-1.17-395.el8.noarch
  perl-Text-ParseWords-3.30-395.el8.noarch   perl-Text-Tabs+Wrap-2013.0523-395.el8.noarch perl-Time-Local-1:1.280-1.el8.noarch
  perl-Unicode-Normalize-1.25-396.el8.x86_64 perl-constant-1.33-396.el8.noarch            perl-interpreter-4:5.26.3-416.el8.x86_64
  perl-libs-4:5.26.3-416.el8.x86_64          perl-macros-4:5.26.3-416.el8.x86_64          perl-parent-1:0.237-1.el8.noarch
  perl-podlators-4.11-1.el8.noarch           perl-threads-1:2.21-2.el8.x86_64             perl-threads-shared-1.58-2.el8.x86_64

Complete!
Last metadata expiration check: 0:24:17 ago on Tue 12 May 2020 01:50:05 PM UTC.
Package python36-3.6.8-2.module_el8.1.0+245+c39af44f.x86_64 is already installed.
Dependencies resolved.
Nothing to do.
Complete!
WARNING: Running pip install with root privileges is generally not a good idea. Try `pip3 install --user` instead.
Collecting python-openstackclient
  Downloading https://files.pythonhosted.org/packages/8f/f1/bb5c4069a3f2ce943545247da67dd7aaa00a908cbefd82546e63fcb2fab5/python_openstackclient-5.2.0-py3-none-any.whl (883kB)
    100% |████████████████████████████████| 890kB 1.4MB/s
Collecting python-ironicclient
  Downloading https://files.pythonhosted.org/packages/40/b3/5aa6578cd9e05af789f2e51799c0c9cedd2fe4e77d57e28b1a024e139b02/python_ironicclient-4.1.0-py3-none-any.whl (236kB)
    100% |████████████████████████████████| 245kB 4.3MB/s
Collecting python-cinderclient>=3.3.0 (from python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/64/8f/c675ad3f12d52739948b299607285a56d0a1e7d1bcc72ceed1f625a38fff/python_cinderclient-7.0.0-py3-none-any.whl (275kB)
    100% |████████████████████████████████| 276kB 4.2MB/s
Collecting osc-lib>=2.0.0 (from python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/72/f3/d872dd8b6d8a15456958f517eb9913aa98b10d82d3996b40f96a4adaf2d9/osc_lib-2.0.0-py2.py3-none-any.whl (89kB)
    100% |████████████████████████████████| 92kB 8.3MB/s
Collecting python-novaclient>=15.1.0 (from python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/75/3c/56221c131cd1e67e224f5162dce1ca6033056e6aebee23a1402d53bc1b79/python_novaclient-17.0.0-py3-none-any.whl (331kB)
    100% |████████████████████████████████| 337kB 3.5MB/s
Collecting openstacksdk>=0.36.0 (from python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/2f/21/2eb68fcdea3e2deaa53491b74c3b1333c182b408620ca1968afc78a3b003/openstacksdk-0.46.0-py3-none-any.whl (1.3MB)
    100% |████████████████████████████████| 1.3MB 997kB/s
Collecting python-keystoneclient>=3.22.0 (from python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/92/7a/95722507a75904d8af0162faa86c4bae9488ade27a0f27228c12f3125e8a/python_keystoneclient-4.0.0-py3-none-any.whl (397kB)
    100% |████████████████████████████████| 399kB 3.1MB/s
Requirement already satisfied: pbr!=2.1.0,>=2.0.0 in /usr/local/lib/python3.6/site-packages (from python-openstackclient)
Requirement already satisfied: six>=1.10.0 in /usr/lib/python3.6/site-packages (from python-openstackclient)
Requirement already satisfied: Babel!=2.4.0,>=2.3.4 in /usr/lib/python3.6/site-packages (from python-openstackclient)
Collecting oslo.i18n>=3.15.3 (from python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/d1/59/16e07470ba39f9a18d679755d66452acd36ca3e03e98aa109f3ff7def649/oslo.i18n-4.0.1-py3-none-any.whl (47kB)
    100% |████████████████████████████████| 51kB 9.2MB/s
Requirement already satisfied: cliff!=2.9.0,>=2.8.0 in /usr/local/lib/python3.6/site-packages (from python-openstackclient)
Collecting oslo.utils>=3.33.0 (from python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/a6/4b/a589adaf957c89818102a19c800ae04fb3d6f4c7eaf670b23cd3c8e4f3c5/oslo.utils-4.1.1-py3-none-any.whl (100kB)
    100% |████████████████████████████████| 102kB 9.7MB/s
Requirement already satisfied: jsonschema>=2.6.0 in /usr/lib/python3.6/site-packages (from python-ironicclient)
Collecting appdirs>=1.3.0 (from python-ironicclient)
  Downloading https://files.pythonhosted.org/packages/3b/00/2344469e2084fb287c2e0b57b72910309874c3245463acd6cf5e3db69324/appdirs-1.4.4-py2.py3-none-any.whl
Collecting oslo.serialization!=2.19.1,>=2.18.0 (from python-ironicclient)
  Downloading https://files.pythonhosted.org/packages/1e/95/7b2911102a78df16bb6feb1267821608da9f422375b86466cfc75a6ad4c9/oslo.serialization-3.1.1-py3-none-any.whl
Requirement already satisfied: requests>=2.14.2 in /usr/lib/python3.6/site-packages (from python-ironicclient)
Collecting keystoneauth1>=3.4.0 (from python-ironicclient)
  Downloading https://files.pythonhosted.org/packages/52/11/9f1538cd8186b6a684ded6ed816176ed262a0ed872285e9e733cbea88025/keystoneauth1-4.0.0-py3-none-any.whl (310kB)
    100% |████████████████████████████████| 317kB 4.1MB/s
Requirement already satisfied: stevedore>=1.20.0 in /usr/local/lib/python3.6/site-packages (from python-ironicclient)
Collecting dogpile.cache>=0.6.2 (from python-ironicclient)
  Downloading https://files.pythonhosted.org/packages/b5/02/9692c82808341747afc87a7c2b701c8eed76c05ec6bc98844c102a537de7/dogpile.cache-0.9.2.tar.gz (329kB)
    100% |████████████████████████████████| 337kB 3.6MB/s
Requirement already satisfied: PyYAML>=3.12 in /usr/lib64/python3.6/site-packages (from python-ironicclient)
Requirement already satisfied: PrettyTable<0.8,>=0.7.1 in /usr/lib/python3.6/site-packages (from python-cinderclient>=3.3.0->python-openstackclient)
Collecting simplejson>=3.5.1 (from python-cinderclient>=3.3.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/98/87/a7b98aa9256c8843f92878966dc3d8d914c14aad97e2c5ce4798d5743e07/simplejson-3.17.0.tar.gz (83kB)
    100% |████████████████████████████████| 92kB 10.4MB/s
Collecting iso8601>=0.1.11 (from python-novaclient>=15.1.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/ef/57/7162609dab394d38bbc7077b7ba0a6f10fb09d8b7701ea56fa1edc0c4345/iso8601-0.1.12-py2.py3-none-any.whl
Collecting os-service-types>=1.7.0 (from openstacksdk>=0.36.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/10/2d/318b2b631f68e0fc221ba8f45d163bf810cdb795cf242fe85ad3e5d45639/os_service_types-1.7.0-py2.py3-none-any.whl
Collecting munch>=2.1.0 (from openstacksdk>=0.36.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/cc/ab/85d8da5c9a45e072301beb37ad7f833cd344e04c817d97e0cc75681d248f/munch-2.5.0-py2.py3-none-any.whl
Requirement already satisfied: jsonpatch!=1.20,>=1.16 in /usr/lib/python3.6/site-packages (from openstacksdk>=0.36.0->python-openstackclient)
Collecting jmespath>=0.9.0 (from openstacksdk>=0.36.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/a3/43/1e939e1fcd87b827fe192d0c9fc25b48c5b3368902bfb913de7754b0dc03/jmespath-0.9.5-py2.py3-none-any.whl
Collecting requestsexceptions>=1.2.0 (from openstacksdk>=0.36.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/01/8c/49ca60ea8c907260da4662582c434bec98716177674e88df3fd340acf06d/requestsexceptions-1.4.0-py2.py3-none-any.whl
Collecting decorator>=4.4.1 (from openstacksdk>=0.36.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/ed/1b/72a1821152d07cf1d8b6fce298aeb06a7eb90f4d6d41acec9861e7cc6df0/decorator-4.4.2-py2.py3-none-any.whl
Requirement already satisfied: cryptography>=2.1 in /usr/lib64/python3.6/site-packages (from openstacksdk>=0.36.0->python-openstackclient)
Requirement already satisfied: netifaces>=0.10.4 in /usr/lib64/python3.6/site-packages (from openstacksdk>=0.36.0->python-openstackclient)
Collecting oslo.config>=5.2.0 (from python-keystoneclient>=3.22.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/0b/5f/6e0e167a3365c7b71876949def05900e6f4bb1e9a6e4bbd3baf1ebe311a1/oslo.config-8.0.2-py3-none-any.whl (125kB)
    100% |████████████████████████████████| 133kB 8.2MB/s
Collecting debtcollector>=1.2.0 (from python-keystoneclient>=3.22.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/d0/9e/d3c893e756fa4901f6851bd1cc625629c1f57804ebce6726884aa1efa5e0/debtcollector-2.0.1-py3-none-any.whl
Requirement already satisfied: pytz in /usr/lib/python3.6/site-packages (from Babel!=2.4.0,>=2.3.4->python-openstackclient)
Requirement already satisfied: pyparsing>=2.1.0 in /usr/local/lib/python3.6/site-packages (from cliff!=2.9.0,>=2.8.0->python-openstackclient)
Requirement already satisfied: cmd2!=0.8.3,<0.9.0,>=0.8.0 in /usr/local/lib/python3.6/site-packages (from cliff!=2.9.0,>=2.8.0->python-openstackclient)
Collecting netaddr>=0.7.18 (from oslo.utils>=3.33.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/ba/97/ce14451a9fd7bdb5a397abf99b24a1a6bb7a1a440b019bebd2e9a0dbec74/netaddr-0.7.19-py2.py3-none-any.whl (1.6MB)
    100% |████████████████████████████████| 1.6MB 766kB/s
Collecting msgpack>=0.5.2 (from oslo.serialization!=2.19.1,>=2.18.0->python-ironicclient)
  Downloading https://files.pythonhosted.org/packages/c9/35/33aa1af0700d21beabdf74373f31c52c048be8ee082f98edbc37ba3ae956/msgpack-1.0.0-cp36-cp36m-manylinux1_x86_64.whl (274kB)
    100% |████████████████████████████████| 276kB 4.1MB/s
Requirement already satisfied: chardet<3.1.0,>=3.0.2 in /usr/lib/python3.6/site-packages (from requests>=2.14.2->python-ironicclient)
Requirement already satisfied: idna<2.8,>=2.5 in /usr/lib/python3.6/site-packages (from requests>=2.14.2->python-ironicclient)
Requirement already satisfied: urllib3<1.25,>=1.21.1 in /usr/lib/python3.6/site-packages (from requests>=2.14.2->python-ironicclient)
Requirement already satisfied: jsonpointer>=1.9 in /usr/lib/python3.6/site-packages (from jsonpatch!=1.20,>=1.16->openstacksdk>=0.36.0->python-openstackclient)
Requirement already satisfied: asn1crypto>=0.21.0 in /usr/lib/python3.6/site-packages (from cryptography>=2.1->openstacksdk>=0.36.0->python-openstackclient)
Requirement already satisfied: cffi!=1.11.3,>=1.7 in /usr/lib64/python3.6/site-packages (from cryptography>=2.1->openstacksdk>=0.36.0->python-openstackclient)
Collecting rfc3986>=1.2.0 (from oslo.config>=5.2.0->python-keystoneclient>=3.22.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/78/be/7b8b99fd74ff5684225f50dd0e865393d2265656ef3b4ba9eaaaffe622b8/rfc3986-1.4.0-py2.py3-none-any.whl
Collecting wrapt>=1.7.0 (from debtcollector>=1.2.0->python-keystoneclient>=3.22.0->python-openstackclient)
  Downloading https://files.pythonhosted.org/packages/82/f7/e43cefbe88c5fd371f4cf0cf5eb3feccd07515af9fd6cf7dbf1d1793a797/wrapt-1.12.1.tar.gz
Requirement already satisfied: wcwidth; sys_platform != "win32" in /usr/local/lib/python3.6/site-packages (from cmd2!=0.8.3,<0.9.0,>=0.8.0->cliff!=2.9.0,>=2.8.0->python-openstackclient)
Requirement already satisfied: pyperclip in /usr/local/lib/python3.6/site-packages (from cmd2!=0.8.3,<0.9.0,>=0.8.0->cliff!=2.9.0,>=2.8.0->python-openstackclient)
Requirement already satisfied: pycparser in /usr/lib/python3.6/site-packages (from cffi!=1.11.3,>=1.7->cryptography>=2.1->openstacksdk>=0.36.0->python-openstackclient)
Installing collected packages: os-service-types, iso8601, keystoneauth1, simplejson, oslo.i18n, netaddr, wrapt, debtcollector, oslo.utils, python-cinderclient, munch, decorator, dogpile.cache, appdirs, jmespath, requestsexceptions, openstacksdk, osc-lib, msgpack, oslo.serialization, python-novaclient, rfc3986, oslo.config, python-keystoneclient, python-openstackclient, python-ironicclient
  Running setup.py install for simplejson ... done
  Running setup.py install for wrapt ... done
  Running setup.py install for dogpile.cache ... done
Successfully installed appdirs-1.4.4 debtcollector-2.0.1 decorator-4.4.2 dogpile.cache-0.9.2 iso8601-0.1.12 jmespath-0.9.5 keystoneauth1-4.0.0 msgpack-1.0.0 munch-2.5.0 netaddr-0.7.19 openstacksdk-0.46.0 os-service-types-1.7.0 osc-lib-2.0.0 oslo.config-8.0.2 oslo.i18n-4.0.1 oslo.serialization-3.1.1 oslo.utils-4.1.1 python-cinderclient-7.0.0 python-ironicclient-4.1.0 python-keystoneclient-4.0.0 python-novaclient-17.0.0 python-openstackclient-5.2.0 requestsexceptions-1.4.0 rfc3986-1.4.0 simplejson-3.17.0 wrapt-1.12.1
```

Beyond typical packages, we also install openstack and ironic client for troubleshooting purposes only.

openstack client is not strictly needed, since ironic is to be seen as an implementation detail for the installer, but this can still be helpful to check progress of the masters or workers deployment.

# Network requisites

In this section, we configure networking with nmcli the same way it would be done in the provisioning node by creating appropriate bridges:

```
/root/03_network.sh
```

Expected Output

```
Connection 'lab-prov' (32ef4a95-272d-48bd-bfca-c62728992a6d) successfully added.
Connection 'bridge-slave-eth1' (7e36a352-15f9-41fa-8c48-d6769324871f) successfully added.
Connection 'lab-baremetal' (37664e02-9f73-4edd-bf02-928d36f85c99) successfully added.
Connection 'bridge-slave-eth0' (afc32624-c3cc-45c1-87e1-691255a77c4f) successfully added.
Connection 'System eth0' successfully deactivated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/1)
Connection 'lab-prov' successfully deactivated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/55)

(process:18180): GLib-GIO-WARNING **: 15:25:20.286: gdbusobjectmanagerclient.c:1589: Processing InterfaceRemoved signal for path /org/freedesktop/NetworkManager/ActiveConnection/55 but no object proxy exists
Connection successfully activated (master waiting for slaves) (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/59)
```

Two bridges get created:

- lab-baremetal on top of the default interface of the node.
- lab-prov, which is where provisioning of the nodes will be done. No dhcp needs to exist on this bridge, since this is where the provisioning artifacts will be deployed. We configure a static ip in 172.22.0.0/24 range.

# Binaries retrieval

In this section, we fetch binaries required for the install:

```
/root/04_get_clients.sh
```

Expected Output

```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 41.9M  100 41.9M    0     0  44.6M      0 --:--:-- --:--:-- --:--:-- 44.5M
```

The script downloads the following objects:

- oc
- kubectl.
- openshift-baremetal-install using oc and by specifying which OPENSHIFT_RELEASE_IMAGE to use.

# Images caching

In this section, we gather rhcos images needed for the install to speed up deployment time:

```
/root/05_cache.sh
```

Expected Output

```
CentOS-8 - AppStream                                                                                                                                            37 kB/s | 4.3 kB     00:00
CentOS-8 - Base                                                                                                                                                 15 kB/s | 3.9 kB     00:00
CentOS-8 - Extras                                                                                                                                               20 kB/s | 1.5 kB     00:00
Dependencies resolved.
===============================================================================================================================================================================================
 Package                                       Architecture                      Version                                                            Repository                            Size
===============================================================================================================================================================================================
Installing:
 httpd                                         x86_64                            2.4.37-16.module_el8.1.0+256+ae790463                              AppStream                            1.7 M
Installing dependencies:
 apr                                           x86_64                            1.6.3-9.el8                                                        AppStream                            125 k
 apr-util                                      x86_64                            1.6.1-6.el8                                                        AppStream                            105 k
 centos-logos-httpd                            noarch                            80.5-2.el8                                                         AppStream                             24 k
 httpd-filesystem                              noarch                            2.4.37-16.module_el8.1.0+256+ae790463                              AppStream                             35 k
 httpd-tools                                   x86_64                            2.4.37-16.module_el8.1.0+256+ae790463                              AppStream                            103 k
 mod_http2                                     x86_64                            1.11.3-3.module_el8.1.0+213+acce2796                               AppStream                            158 k
 mailcap                                       noarch                            2.1.48-3.el8                                                       BaseOS                                39 k
Installing weak dependencies:
 apr-util-bdb                                  x86_64                            1.6.1-6.el8                                                        AppStream                             25 k
 apr-util-openssl                              x86_64                            1.6.1-6.el8                                                        AppStream                             27 k
Enabling module streams:
 httpd                                                                           2.4

Transaction Summary
===============================================================================================================================================================================================
Install  10 Packages

Total download size: 2.3 M
Installed size: 6.6 M
Downloading Packages:
CentOS-8 - Base                                                             206% [=============================================================================================================(1/10): apr-util-bdb-1.6.1-6.el8.x86_64.rpm                                                                                                                    602 kB/s |  25 kB     00:00
(2/10): apr-util-openssl-1.6.1-6.el8.x86_64.rpm                                                                                                                1.8 MB/s |  27 kB     00:00
(3/10): apr-util-1.6.1-6.el8.x86_64.rpm                                                                                                                        1.6 MB/s | 105 kB     00:00
(4/10): apr-1.6.3-9.el8.x86_64.rpm                                                                                                                             1.8 MB/s | 125 kB     00:00
(5/10): centos-logos-httpd-80.5-2.el8.noarch.rpm                                                                                                               1.3 MB/s |  24 kB     00:00
(6/10): httpd-filesystem-2.4.37-16.module_el8.1.0+256+ae790463.noarch.rpm                                                                                      2.0 MB/s |  35 kB     00:00
(7/10): httpd-tools-2.4.37-16.module_el8.1.0+256+ae790463.x86_64.rpm                                                                                           3.7 MB/s | 103 kB     00:00
(8/10): mod_http2-1.11.3-3.module_el8.1.0+213+acce2796.x86_64.rpm                                                                                              6.0 MB/s | 158 kB     00:00
(9/10): httpd-2.4.37-16.module_el8.1.0+256+ae790463.x86_64.rpm                                                                                                  24 MB/s | 1.7 MB     00:00
(10/10): mailcap-2.1.48-3.el8.noarch.rpm                                                                                                                       673 kB/s |  39 kB     00:00
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                          4.7 MB/s | 2.3 MB     00:00
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                       1/1
  Installing       : apr-1.6.3-9.el8.x86_64                                                                                                                                               1/10
  Running scriptlet: apr-1.6.3-9.el8.x86_64                                                                                                                                               1/10
  Installing       : apr-util-bdb-1.6.1-6.el8.x86_64                                                                                                                                      2/10
  Installing       : apr-util-openssl-1.6.1-6.el8.x86_64                                                                                                                                  3/10
  Installing       : apr-util-1.6.1-6.el8.x86_64                                                                                                                                          4/10
  Running scriptlet: apr-util-1.6.1-6.el8.x86_64                                                                                                                                          4/10
  Installing       : httpd-tools-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                                                                                             5/10
  Installing       : mailcap-2.1.48-3.el8.noarch                                                                                                                                          6/10
  Running scriptlet: httpd-filesystem-2.4.37-16.module_el8.1.0+256+ae790463.noarch                                                                                                        7/10
  Installing       : httpd-filesystem-2.4.37-16.module_el8.1.0+256+ae790463.noarch                                                                                                        7/10
  Installing       : centos-logos-httpd-80.5-2.el8.noarch                                                                                                                                 8/10
  Installing       : mod_http2-1.11.3-3.module_el8.1.0+213+acce2796.x86_64                                                                                                                9/10
  Installing       : httpd-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                                                                                                  10/10
  Running scriptlet: httpd-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                                                                                                  10/10
  Verifying        : apr-1.6.3-9.el8.x86_64                                                                                                                                               1/10
  Verifying        : apr-util-1.6.1-6.el8.x86_64                                                                                                                                          2/10
  Verifying        : apr-util-bdb-1.6.1-6.el8.x86_64                                                                                                                                      3/10
  Verifying        : apr-util-openssl-1.6.1-6.el8.x86_64                                                                                                                                  4/10
  Verifying        : centos-logos-httpd-80.5-2.el8.noarch                                                                                                                                 5/10
  Verifying        : httpd-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                                                                                                   6/10
  Verifying        : httpd-filesystem-2.4.37-16.module_el8.1.0+256+ae790463.noarch                                                                                                        7/10
  Verifying        : httpd-tools-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                                                                                             8/10
  Verifying        : mod_http2-1.11.3-3.module_el8.1.0+213+acce2796.x86_64                                                                                                                9/10
  Verifying        : mailcap-2.1.48-3.el8.noarch                                                                                                                                         10/10

Installed:
  httpd-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                 apr-util-bdb-1.6.1-6.el8.x86_64                               apr-util-openssl-1.6.1-6.el8.x86_64
  apr-1.6.3-9.el8.x86_64                                             apr-util-1.6.1-6.el8.x86_64                                   centos-logos-httpd-80.5-2.el8.noarch
  httpd-filesystem-2.4.37-16.module_el8.1.0+256+ae790463.noarch      httpd-tools-2.4.37-16.module_el8.1.0+256+ae790463.x86_64      mod_http2-1.11.3-3.module_el8.1.0+213+acce2796.x86_64
  mailcap-2.1.48-3.el8.noarch

Complete!
Created symlink /etc/systemd/system/multi-user.target.wants/httpd.service → /usr/lib/systemd/system/httpd.service.
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   161  100   161    0     0    244      0 --:--:-- --:--:-- --:--:--   243
100  810M  100  810M    0     0  21.0M      0  0:00:38  0:00:38 --:--:-- 34.4M
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   161  100   161    0     0    306      0 --:--:-- --:--:-- --:--:--   306
100  809M  100  809M    0     0  25.5M      0  0:00:31  0:00:31 --:--:-- 31.7M
```

This script does the following things:

- Installs and enables httpd.
- Evaluates rhcos openstack and qemu urls by gathering openshift-barremetal-install binary commit id and uses github to fetch the relevant data in rhcos.json file.
- Fetches those images.
- Patches *install-config.yaml* so it points to those downloaded images.
- Prepares a *metal3-config.yaml* based on this data. This is/was only needed for Openshift 4.3.


# Disconnected environment (Optional)

In this section, we enable a registry and sync content so we can deploy Openshift in a disconnected environment:

**NOTE:** In order to make use of this during the install, DNS resolution in place is needed to provide resolution for the fqdn of this local registry. 

```
/root/06_disconnected.sh
```

Expected Output

```
CentOS-8 - AppStream                                                                                                                                           6.2 MB/s | 7.0 MB     00:01
CentOS-8 - Base                                                                                                                                                6.3 MB/s | 2.2 MB     00:00
CentOS-8 - Extras                                                                                                                                               23 kB/s | 5.9 kB     00:00
Dependencies resolved.
===============================================================================================================================================================================================
 Package                                            Architecture                  Version                                                               Repository                        Size
===============================================================================================================================================================================================
Installing:
 httpd                                              x86_64                        2.4.37-16.module_el8.1.0+256+ae790463                                 AppStream                        1.7 M
 httpd-tools                                        x86_64                        2.4.37-16.module_el8.1.0+256+ae790463                                 AppStream                        103 k
 jq                                                 x86_64                        1.5-12.el8                                                            AppStream                        161 k
 podman                                             x86_64                        1.6.4-4.module_el8.1.0+298+41f9343a                                   AppStream                         12 M
Installing dependencies:
 apr                                                x86_64                        1.6.3-9.el8                                                           AppStream                        125 k
 apr-util                                           x86_64                        1.6.1-6.el8                                                           AppStream                        105 k
 centos-logos-httpd                                 noarch                        80.5-2.el8                                                            AppStream                         24 k
 conmon                                             x86_64                        2:2.0.6-1.module_el8.1.0+298+41f9343a                                 AppStream                         37 k
 container-selinux                                  noarch                        2:2.124.0-1.module_el8.1.0+298+41f9343a                               AppStream                         47 k
 containernetworking-plugins                        x86_64                        0.8.3-4.module_el8.1.0+298+41f9343a                                   AppStream                         20 M
 containers-common                                  x86_64                        1:0.1.40-8.module_el8.1.0+298+41f9343a                                AppStream                         49 k
 criu                                               x86_64                        3.12-9.el8                                                            AppStream                        482 k
 fuse-overlayfs                                     x86_64                        0.7.2-5.module_el8.1.0+298+41f9343a                                   AppStream                         60 k
 httpd-filesystem                                   noarch                        2.4.37-16.module_el8.1.0+256+ae790463                                 AppStream                         35 k
 libnet                                             x86_64                        1.1.6-15.el8                                                          AppStream                         67 k
 mod_http2                                          x86_64                        1.11.3-3.module_el8.1.0+213+acce2796                                  AppStream                        158 k
 oniguruma                                          x86_64                        6.8.2-1.el8                                                           AppStream                        188 k
 podman-manpages                                    noarch                        1.6.4-4.module_el8.1.0+298+41f9343a                                   AppStream                        176 k
 protobuf-c                                         x86_64                        1.3.0-4.el8                                                           AppStream                         37 k
 runc                                               x86_64                        1.0.0-64.rc9.module_el8.1.0+298+41f9343a                              AppStream                        2.6 M
 slirp4netns                                        x86_64                        0.4.2-3.git21fdece.module_el8.1.0+298+41f9343a                        AppStream                         88 k
 fuse3-libs                                         x86_64                        3.2.1-12.el8                                                          BaseOS                            94 k
 iptables                                           x86_64                        1.8.2-16.el8                                                          BaseOS                           586 k
 libnetfilter_conntrack                             x86_64                        1.0.6-5.el8                                                           BaseOS                            65 k
 libnfnetlink                                       x86_64                        1.0.1-13.el8                                                          BaseOS                            33 k
 libnftnl                                           x86_64                        1.1.1-4.el8                                                           BaseOS                            83 k
 libvarlink                                         x86_64                        18-3.el8                                                              BaseOS                            44 k
 mailcap                                            noarch                        2.1.48-3.el8                                                          BaseOS                            39 k
 nftables                                           x86_64                        1:0.9.0-14.el8_1.1                                                    BaseOS                           263 k
Installing weak dependencies:
 apr-util-bdb                                       x86_64                        1.6.1-6.el8                                                           AppStream                         25 k
 apr-util-openssl                                   x86_64                        1.6.1-6.el8                                                           AppStream                         27 k
Enabling module streams:
 container-tools                                                                  rhel8
 httpd                                                                            2.4

Transaction Summary
===============================================================================================================================================================================================
Install  31 Packages

Total download size: 39 M
Installed size: 149 M
Downloading Packages:
(1/31): apr-util-bdb-1.6.1-6.el8.x86_64.rpm                                                                                                                    893 kB/s |  25 kB     00:00
(2/31): apr-1.6.3-9.el8.x86_64.rpm                                                                                                                             2.9 MB/s | 125 kB     00:00
(3/31): apr-util-1.6.1-6.el8.x86_64.rpm                                                                                                                        2.3 MB/s | 105 kB     00:00
(4/31): conmon-2.0.6-1.module_el8.1.0+298+41f9343a.x86_64.rpm                                                                                                  2.4 MB/s |  37 kB     00:00
(5/31): apr-util-openssl-1.6.1-6.el8.x86_64.rpm                                                                                                                522 kB/s |  27 kB     00:00
(6/31): centos-logos-httpd-80.5-2.el8.noarch.rpm                                                                                                               613 kB/s |  24 kB     00:00
(7/31): container-selinux-2.124.0-1.module_el8.1.0+298+41f9343a.noarch.rpm                                                                                     2.1 MB/s |  47 kB     00:00
(8/31): containers-common-0.1.40-8.module_el8.1.0+298+41f9343a.x86_64.rpm                                                                                      2.4 MB/s |  49 kB     00:00
(9/31): criu-3.12-9.el8.x86_64.rpm                                                                                                                              12 MB/s | 482 kB     00:00
(10/31): fuse-overlayfs-0.7.2-5.module_el8.1.0+298+41f9343a.x86_64.rpm                                                                                         2.9 MB/s |  60 kB     00:00
(11/31): httpd-filesystem-2.4.37-16.module_el8.1.0+256+ae790463.noarch.rpm                                                                                     2.2 MB/s |  35 kB     00:00
(12/31): httpd-tools-2.4.37-16.module_el8.1.0+256+ae790463.x86_64.rpm                                                                                          5.7 MB/s | 103 kB     00:00
(13/31): httpd-2.4.37-16.module_el8.1.0+256+ae790463.x86_64.rpm                                                                                                 29 MB/s | 1.7 MB     00:00
(14/31): jq-1.5-12.el8.x86_64.rpm                                                                                                                              6.6 MB/s | 161 kB     00:00
(15/31): libnet-1.1.6-15.el8.x86_64.rpm                                                                                                                        8.1 MB/s |  67 kB     00:00
(16/31): mod_http2-1.11.3-3.module_el8.1.0+213+acce2796.x86_64.rpm                                                                                              19 MB/s | 158 kB     00:00
(17/31): oniguruma-6.8.2-1.el8.x86_64.rpm                                                                                                                      9.3 MB/s | 188 kB     00:00
(18/31): podman-manpages-1.6.4-4.module_el8.1.0+298+41f9343a.noarch.rpm                                                                                         10 MB/s | 176 kB     00:00
(19/31): protobuf-c-1.3.0-4.el8.x86_64.rpm                                                                                                                     3.3 MB/s |  37 kB     00:00
(20/31): runc-1.0.0-64.rc9.module_el8.1.0+298+41f9343a.x86_64.rpm                                                                                               18 MB/s | 2.6 MB     00:00
(21/31): slirp4netns-0.4.2-3.git21fdece.module_el8.1.0+298+41f9343a.x86_64.rpm                                                                                 8.9 MB/s |  88 kB     00:00
(22/31): fuse3-libs-3.2.1-12.el8.x86_64.rpm                                                                                                                    2.3 MB/s |  94 kB     00:00
(23/31): iptables-1.8.2-16.el8.x86_64.rpm                                                                                                                       20 MB/s | 586 kB     00:00
(24/31): libnetfilter_conntrack-1.0.6-5.el8.x86_64.rpm                                                                                                         6.4 MB/s |  65 kB     00:00
(25/31): libnfnetlink-1.0.1-13.el8.x86_64.rpm                                                                                                                  3.5 MB/s |  33 kB     00:00
(26/31): libnftnl-1.1.1-4.el8.x86_64.rpm                                                                                                                       9.7 MB/s |  83 kB     00:00
(27/31): libvarlink-18-3.el8.x86_64.rpm                                                                                                                        5.8 MB/s |  44 kB     00:00
(28/31): mailcap-2.1.48-3.el8.noarch.rpm                                                                                                                       4.8 MB/s |  39 kB     00:00
(29/31): nftables-0.9.0-14.el8_1.1.x86_64.rpm                                                                                                                   22 MB/s | 263 kB     00:00
(30/31): podman-1.6.4-4.module_el8.1.0+298+41f9343a.x86_64.rpm                                                                                                  26 MB/s |  12 MB     00:00
(31/31): containernetworking-plugins-0.8.3-4.module_el8.1.0+298+41f9343a.x86_64.rpm                                                                             26 MB/s |  20 MB     00:00
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                                           34 MB/s |  39 MB     00:01
warning: /var/cache/dnf/AppStream-a3ce6348fe6cbd6c/packages/apr-1.6.3-9.el8.x86_64.rpm: Header V3 RSA/SHA256 Signature, key ID 8483c65d: NOKEY
CentOS-8 - AppStream                                                                                                                                           1.6 MB/s | 1.6 kB     00:00
Importing GPG key 0x8483C65D:
 Userid     : "CentOS (CentOS Official Signing Key) <security@centos.org>"
 Fingerprint: 99DB 70FA E1D7 CE22 7FB6 4882 05B5 55B3 8483 C65D
 From       : /etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
Key imported successfully
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                       1/1
  Installing       : apr-1.6.3-9.el8.x86_64                                                                                                                                               1/31
  Running scriptlet: apr-1.6.3-9.el8.x86_64                                                                                                                                               1/31
  Installing       : apr-util-bdb-1.6.1-6.el8.x86_64                                                                                                                                      2/31
  Installing       : apr-util-openssl-1.6.1-6.el8.x86_64                                                                                                                                  3/31
  Installing       : apr-util-1.6.1-6.el8.x86_64                                                                                                                                          4/31
  Running scriptlet: apr-util-1.6.1-6.el8.x86_64                                                                                                                                          4/31
  Installing       : libnftnl-1.1.1-4.el8.x86_64                                                                                                                                          5/31
  Running scriptlet: libnftnl-1.1.1-4.el8.x86_64                                                                                                                                          5/31
  Installing       : libnfnetlink-1.0.1-13.el8.x86_64                                                                                                                                     6/31
  Running scriptlet: libnfnetlink-1.0.1-13.el8.x86_64                                                                                                                                     6/31
  Installing       : slirp4netns-0.4.2-3.git21fdece.module_el8.1.0+298+41f9343a.x86_64                                                                                                    7/31
  Running scriptlet: container-selinux-2:2.124.0-1.module_el8.1.0+298+41f9343a.noarch                                                                                                     8/31
  Installing       : container-selinux-2:2.124.0-1.module_el8.1.0+298+41f9343a.noarch                                                                                                     8/31
  Running scriptlet: container-selinux-2:2.124.0-1.module_el8.1.0+298+41f9343a.noarch                                                                                                     8/31
  Installing       : libnetfilter_conntrack-1.0.6-5.el8.x86_64                                                                                                                            9/31
  Running scriptlet: libnetfilter_conntrack-1.0.6-5.el8.x86_64                                                                                                                            9/31
  Running scriptlet: iptables-1.8.2-16.el8.x86_64                                                                                                                                        10/31
  Installing       : iptables-1.8.2-16.el8.x86_64                                                                                                                                        10/31
  Running scriptlet: iptables-1.8.2-16.el8.x86_64                                                                                                                                        10/31
  Installing       : nftables-1:0.9.0-14.el8_1.1.x86_64                                                                                                                                  11/31
  Running scriptlet: nftables-1:0.9.0-14.el8_1.1.x86_64                                                                                                                                  11/31
  Installing       : httpd-tools-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                                                                                            12/31
  Installing       : mailcap-2.1.48-3.el8.noarch                                                                                                                                         13/31
  Installing       : libvarlink-18-3.el8.x86_64                                                                                                                                          14/31
  Running scriptlet: libvarlink-18-3.el8.x86_64                                                                                                                                          14/31
  Installing       : fuse3-libs-3.2.1-12.el8.x86_64                                                                                                                                      15/31
  Running scriptlet: fuse3-libs-3.2.1-12.el8.x86_64                                                                                                                                      15/31
  Installing       : fuse-overlayfs-0.7.2-5.module_el8.1.0+298+41f9343a.x86_64                                                                                                           16/31
  Installing       : containers-common-1:0.1.40-8.module_el8.1.0+298+41f9343a.x86_64                                                                                                     17/31
  Installing       : protobuf-c-1.3.0-4.el8.x86_64                                                                                                                                       18/31
  Installing       : podman-manpages-1.6.4-4.module_el8.1.0+298+41f9343a.noarch                                                                                                          19/31
  Installing       : oniguruma-6.8.2-1.el8.x86_64                                                                                                                                        20/31
  Running scriptlet: oniguruma-6.8.2-1.el8.x86_64                                                                                                                                        20/31
  Installing       : libnet-1.1.6-15.el8.x86_64                                                                                                                                          21/31
  Running scriptlet: libnet-1.1.6-15.el8.x86_64                                                                                                                                          21/31
  Installing       : criu-3.12-9.el8.x86_64                                                                                                                                              22/31
  Installing       : runc-1.0.0-64.rc9.module_el8.1.0+298+41f9343a.x86_64                                                                                                                23/31
  Running scriptlet: httpd-filesystem-2.4.37-16.module_el8.1.0+256+ae790463.noarch                                                                                                       24/31
  Installing       : httpd-filesystem-2.4.37-16.module_el8.1.0+256+ae790463.noarch                                                                                                       24/31
  Installing       : containernetworking-plugins-0.8.3-4.module_el8.1.0+298+41f9343a.x86_64                                                                                              25/31
  Installing       : conmon-2:2.0.6-1.module_el8.1.0+298+41f9343a.x86_64                                                                                                                 26/31
  Installing       : centos-logos-httpd-80.5-2.el8.noarch                                                                                                                                27/31
  Installing       : mod_http2-1.11.3-3.module_el8.1.0+213+acce2796.x86_64                                                                                                               28/31
  Installing       : httpd-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                                                                                                  29/31
  Running scriptlet: httpd-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                                                                                                  29/31
  Installing       : podman-1.6.4-4.module_el8.1.0+298+41f9343a.x86_64                                                                                                                   30/31
  Installing       : jq-1.5-12.el8.x86_64                                                                                                                                                31/31
  Running scriptlet: container-selinux-2:2.124.0-1.module_el8.1.0+298+41f9343a.noarch                                                                                                    31/31
  Running scriptlet: httpd-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                                                                                                  31/31
  Running scriptlet: jq-1.5-12.el8.x86_64                                                                                                                                                31/31
  Verifying        : apr-1.6.3-9.el8.x86_64                                                                                                                                               1/31
  Verifying        : apr-util-1.6.1-6.el8.x86_64                                                                                                                                          2/31
  Verifying        : apr-util-bdb-1.6.1-6.el8.x86_64                                                                                                                                      3/31
  Verifying        : apr-util-openssl-1.6.1-6.el8.x86_64                                                                                                                                  4/31
  Verifying        : centos-logos-httpd-80.5-2.el8.noarch                                                                                                                                 5/31
  Verifying        : conmon-2:2.0.6-1.module_el8.1.0+298+41f9343a.x86_64                                                                                                                  6/31
  Verifying        : container-selinux-2:2.124.0-1.module_el8.1.0+298+41f9343a.noarch                                                                                                     7/31
  Verifying        : containernetworking-plugins-0.8.3-4.module_el8.1.0+298+41f9343a.x86_64                                                                                               8/31
  Verifying        : containers-common-1:0.1.40-8.module_el8.1.0+298+41f9343a.x86_64                                                                                                      9/31
  Verifying        : criu-3.12-9.el8.x86_64                                                                                                                                              10/31
  Verifying        : fuse-overlayfs-0.7.2-5.module_el8.1.0+298+41f9343a.x86_64                                                                                                           11/31
  Verifying        : httpd-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                                                                                                  12/31
  Verifying        : httpd-filesystem-2.4.37-16.module_el8.1.0+256+ae790463.noarch                                                                                                       13/31
  Verifying        : httpd-tools-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                                                                                            14/31
  Verifying        : jq-1.5-12.el8.x86_64                                                                                                                                                15/31
  Verifying        : libnet-1.1.6-15.el8.x86_64                                                                                                                                          16/31
  Verifying        : mod_http2-1.11.3-3.module_el8.1.0+213+acce2796.x86_64                                                                                                               17/31
  Verifying        : oniguruma-6.8.2-1.el8.x86_64                                                                                                                                        18/31
  Verifying        : podman-1.6.4-4.module_el8.1.0+298+41f9343a.x86_64                                                                                                                   19/31
  Verifying        : podman-manpages-1.6.4-4.module_el8.1.0+298+41f9343a.noarch                                                                                                          20/31
  Verifying        : protobuf-c-1.3.0-4.el8.x86_64                                                                                                                                       21/31
  Verifying        : runc-1.0.0-64.rc9.module_el8.1.0+298+41f9343a.x86_64                                                                                                                22/31
  Verifying        : slirp4netns-0.4.2-3.git21fdece.module_el8.1.0+298+41f9343a.x86_64                                                                                                   23/31
  Verifying        : fuse3-libs-3.2.1-12.el8.x86_64                                                                                                                                      24/31
  Verifying        : iptables-1.8.2-16.el8.x86_64                                                                                                                                        25/31
  Verifying        : libnetfilter_conntrack-1.0.6-5.el8.x86_64                                                                                                                           26/31
  Verifying        : libnfnetlink-1.0.1-13.el8.x86_64                                                                                                                                    27/31
  Verifying        : libnftnl-1.1.1-4.el8.x86_64                                                                                                                                         28/31
  Verifying        : libvarlink-18-3.el8.x86_64                                                                                                                                          29/31
  Verifying        : mailcap-2.1.48-3.el8.noarch                                                                                                                                         30/31
  Verifying        : nftables-1:0.9.0-14.el8_1.1.x86_64                                                                                                                                  31/31

Installed:
  httpd-2.4.37-16.module_el8.1.0+256+ae790463.x86_64                                          httpd-tools-2.4.37-16.module_el8.1.0+256+ae790463.x86_64
  jq-1.5-12.el8.x86_64                                                                        podman-1.6.4-4.module_el8.1.0+298+41f9343a.x86_64
  apr-util-bdb-1.6.1-6.el8.x86_64                                                             apr-util-openssl-1.6.1-6.el8.x86_64
  apr-1.6.3-9.el8.x86_64                                                                      apr-util-1.6.1-6.el8.x86_64
  centos-logos-httpd-80.5-2.el8.noarch                                                        conmon-2:2.0.6-1.module_el8.1.0+298+41f9343a.x86_64
  container-selinux-2:2.124.0-1.module_el8.1.0+298+41f9343a.noarch                            containernetworking-plugins-0.8.3-4.module_el8.1.0+298+41f9343a.x86_64
  containers-common-1:0.1.40-8.module_el8.1.0+298+41f9343a.x86_64                             criu-3.12-9.el8.x86_64
  fuse-overlayfs-0.7.2-5.module_el8.1.0+298+41f9343a.x86_64                                   httpd-filesystem-2.4.37-16.module_el8.1.0+256+ae790463.noarch
  libnet-1.1.6-15.el8.x86_64                                                                  mod_http2-1.11.3-3.module_el8.1.0+213+acce2796.x86_64
  oniguruma-6.8.2-1.el8.x86_64                                                                podman-manpages-1.6.4-4.module_el8.1.0+298+41f9343a.noarch
  protobuf-c-1.3.0-4.el8.x86_64                                                               runc-1.0.0-64.rc9.module_el8.1.0+298+41f9343a.x86_64
  slirp4netns-0.4.2-3.git21fdece.module_el8.1.0+298+41f9343a.x86_64                           fuse3-libs-3.2.1-12.el8.x86_64
  iptables-1.8.2-16.el8.x86_64                                                                libnetfilter_conntrack-1.0.6-5.el8.x86_64
  libnfnetlink-1.0.1-13.el8.x86_64                                                            libnftnl-1.1.1-4.el8.x86_64
  libvarlink-18-3.el8.x86_64                                                                  mailcap-2.1.48-3.el8.noarch
  nftables-1:0.9.0-14.el8_1.1.x86_64

Complete!
Generating a RSA private key
.................................................++++
.....................................................................................................................................................................................................................................................................++++
writing new private key to '/opt/registry/certs/domain.key'
-----
Adding password for user dummy
Trying to pull docker.io/library/registry:2...
Getting image source signatures
Copying blob ba51a3b098e6 done
Copying blob 8bb4c43d6c8e done
Copying blob 42bc10b72f42 done
Copying blob 486039affc0a done
Copying blob 6f5f453e5f2d done
Copying config 708bc6af7e done
Writing manifest to image destination
Storing signatures
c0137e67f863babef973126421cf5610ad4c9397df9d161baa8bed6bdd282101
registry
info: Mirroring 109 images to lab-installer.baremetal:5000/ocp/release ...
lab-installer.baremetal:5000/
  ocp/release
    blobs:
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f7da2b9ac57b68ee18dcedeaee9c0a6a539be6738352d5c74debe335d0586af2 631B
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:58e1deb9693dfb1704ccce2f1cf0e4d663ac77098a7a0f699708a71549cbd924 1.527KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:cf5693de4d3cdd6f352978b87c8f89ead294eff44938598f57a91cf7a02417d2 1.582KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5abeb4f4fc09cd3dd95ef2d2910d5ea92c840e626a5e1a265d08b5e5c7dd6dc6 1.672KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:d81829836c61000dfcda5628ed76b154c82d46ab3eac0f559858660045f80552 4.406KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2d304fa2221eb71947b3b2c278d098d881fac260447fc39d6a6161dafb9c47d0 4.437KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e955f4df88e88e17193b83cfa824025048906e174200ac721300d53e50e2fce0 4.745KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b785b52bb10639349ff2855f73f96d24b6734b5cbef13b7547b560ba32509c77 4.781KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6f8771b1d3bed5f8c35049b379cb3a22401b5696b547768036d4a02faff90e17 4.87KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:93259aa47fe12b506f59de2df601e3ce62cd38d079fa362369445d8a4ce1a268 4.915KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8732a97fc60d371643bddc313f5fb7275efb1e8e7856f2bdb23ec478b6859096 5.047KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b00c164103989653db218cf0f15a5783e9a4bdca0fa8b11749bca98212f15d72 5.047KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:27315660ac36ec5e2b95de015bcc0df03e86a8298155d77c0c063fdc79ecc889 5.051KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:72617feaffd4da544e59cf8b69f74054bc5168ca3bda4a087e6a9a9380ecf269 5.053KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:20921f0a11f720f36489d58768b54af6725892ed9229ef1ef887c81d942a50ef 5.068KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4171c1f60aed99fb161333bf657bed119eb939248f1a8fa9d3b7542838ef4d72 5.122KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:570876266458b84ea9983df71392f57c0c9012a24c3202de8a6ee782d8463b70 5.128KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:abaf0fb6ead1118bd61a6d2bf5f7fffc14f98dbd9f20f07341f85b6c6c7c4555 5.206KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e4f694fb9b23678b6d4121791440ab8dae4cc96ba119dc698a648777b3d74afa 5.213KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2daa4382d61058a31feb058f173b730c73d769aa1d73732ad4f5c395a4a82d0b 5.216KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f134e67f667946f2a757c27bff184f3f531b8435816f8de97c482310244b8b70 5.257KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0a37b154df3dfcd0fa403af56a24c5e1beabf48c585d8a42cd63479425bf5b90 5.259KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:17139caa8cb9af5917d5a5f6ae6aad2673d920c3d1d68541a092b2ab80a091e6 5.261KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:827ed6ed15d12ac3ab8c86686ee4327255fd2031c05d685a9155c6b51fd10dac 5.264KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2fbb6d67b95438ed76255548c82ea9c4477b1dd1bd4fafe682c1c3f841180581 5.265KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:52a79a3ff69b2948ae0c95a2f30305ada648111a80c76f13f804c5886ae4b351 5.269KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:807978df1388f2b6f918a20a56e986b836d4af776df8d3b47433a8ecd8898262 5.272KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:55c80d9a524cfcac3b23ddbac6f740121adcd2570396c09f78d6bc2acef4d776 5.286KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:155e891f52bbcf8cdf635b9c423c7d277117610185c1743eadff8af2c0dbebbd 5.297KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1ccd3c4ebf7801bb3d961bbd0ba8010b24f6e69b9492721f78fa373e4ba96a35 5.299KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:37c46d402addb580ab73a501c753905a5ae82ed1fbe11c23ea6420efdce14127 5.304KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f060ef270be4fc078fa4d03dea323b5eb7ede89d8fff1b0298c21114801d97a0 5.304KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:247648ade87e38d5d37046212029926736a065b107d77ca7fc5c55b478925081 5.305KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ee7065c322c2add50de27f32cc37656366c004cd5868b5993f50a37d9dea2a76 5.312KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2b0cb66722d41e3aaca5b28bef4b3080aa574423e0848646e71288bdb4417d8d 5.315KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:397f40d4f4fc11430abf80decb671fe947e57cdeee59b673f7ad69a7e5ea56f7 5.315KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:398dc4cdae49aa39b1838ebb84d1971422fe3d562cadce69f44cfe93b53eec60 5.317KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:828dcfd90771ca70777a43be98f4eaed6cd3ebbf6ed2643b5edad8d2eb79fa3a 5.319KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9c1b4201320164844e6af34ed8ca4654fc7fc6b5f320d3502faf1f9da4aafae2 5.322KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:383702efd4765a154899cb26c48fcaa7d05189f033d674cda2f9980874d5028e 5.328KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4242755a78e56e0985e0e62b6f5fa8a0729505f5ff5fae32c84d5fc1c654a11c 5.337KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3aaef2ef4e9964efad544e258ef02a601dfaa23b340fe5b9b5d2e063170f773d 5.338KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3ef24d7faab2a25065550996a062644403a88817217b454941c0e09c386a5a78 5.347KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f81493bcd63de826f08c722b67c0131242dee27ea90552fcd0c54b3feee10b16 5.352KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:da25061cf9c9040bbaa7d48d6d450f3ec85816f3df21acdf116eb5a31ad6d3e9 5.366KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:09752325aa17262646e6b5d53f7bf00806a00f292940da0e5eb5b99a33636995 5.37KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ba02667400579817f751bea7d3abe61f479cc633f165946ebe0e12508b6d9d0d 5.374KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5f481f0cbea542ba096b364e2183508d7d046c291894259ff901fe3b903003e0 5.375KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8402ae7292a7f41b64b04f2692d61899087251be9b0bd613835530c8e123b872 5.376KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c3f75a0752981b2c9e17aca7ae19b3a2b744315b8fa17843ab962f4b4f6f24ad 5.377KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4f9299159e62e6ebc2cbefa4f5a8c23a3efb46e5170bfd44f1c12b1f7c28ef4b 5.378KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:19d7e6f0db60b4b4b0a544aae5fed7f1309c733b5c4c313b38c2ee4307625911 5.383KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8724079bfcc5e732488f315a9cfadc23d345dd2d2430c3099cc973fe53b6fad6 5.383KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e4d439369b98aede2052c8d9058d2e32057f99ef332807005b4a68a8b52ad393 5.388KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b5857587f9f3b7271bcee018bd9a8720ba56df39365baec58f88f90e93d9c6f9 5.39KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:de599a5a6e7f571d863a17a1a84d722d55dbf8a123e77545037ca78815dad26f 5.39KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0384f0182aa6b3fa3ba52d3de35732b26c71710d159dcd8b2d05364421ed5669 5.392KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c658dcf621b614a09b3a9aa4b16e0e61f0975905a0fabf79dd2ae225df550e23 5.4KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:badae1a7e1009c086e84f200ba1d3ac31fa90314628d6383d5e3da7a7cfda698 5.411KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2d6ec0f11ffd765e85df5b4a9a058fc0f7631139df70c95889e2a318a5068efb 5.415KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f6e55f583326121e0c9a4cb8fb5046dd56594b470dbd41b3c0b8e167ffb141e6 5.417KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:71ee8aba4f998561a02e1b6327560ad7f74a7a5babd9b145ce70dd8d30d638a5 5.422KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c66d326237ff5bfe0286b7846caaa0e844b87a8f3fea4bb3225077f36954a194 5.423KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f86c93f45dbb1735d016cec3e9508ddf1670e0181a3a674607d9d952a04f4c75 5.433KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:fab32138961aafcf4c48d1088ad65e6022dd9bd154027c67ed2b5fce8f54db52 5.434KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ff92603cb90b741117c6192974d0a8a83e2b7abc1c49ba730ec72bad33130766 5.438KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c4a16e5278a699ed0dbda97963ea20dfc89c621dff6799eda22b6ae94f7f8783 5.438KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e607da46dc66b8c519585a65a6f6ce554affb576316123e8b01c0ab21da7d85e 5.438KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:cbd97234176ad476b7dc71f4bdd21a78990f2dc93c529c354a996524ff3ac704 5.445KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:939f577afb744a318a0545d875a2b8dcc941c897e0e2e5f3b1b61c11fa106481 5.449KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f369be16b02fffde4d5733b495853e29b97344060e8550867a8cba39b3bebd2f 5.453KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:eada0a478bed63bc96723fa46ac32b0fa16642ee11a07e832aa6dda5afad895e 5.454KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f6bfa3b868f16a0231eff47755a5e7651d190355b03fa45397a9a87f6b20bcd1 5.456KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4fe45bd156d09910047580a42f31ae1ac1b97c16caae779fd26410bd5e84b690 5.458KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:df739b2ac19644a87e16712a31d9eaa9cb17cefefb00abf4b8bc780ec2559a93 5.459KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:481ca9e594d2f70f735494b2560082344eabad257630985b55be7091a71c7a74 5.462KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:37af3684077b2809df2de9733fa7a831a659ac4fd11047948d5c956c8db864b4 5.464KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:68c669a56c9131ee533fec0e9bb6301a75aa99d39274bf4e684f675d3d9923c8 5.464KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3b9ff8d043cbb4f087aec9d4d1f61540987bdfebbf0419931b0418853f108e38 5.465KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:56a3c6f30433acb94d89affc55903b7a4f0f29b7a1a06359696864d56e2a6dd9 5.472KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5280c6bc6d4a5d23cb40be2642903e889169b3b6fd296a584b69756e22a706b6 5.473KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0e98ee1268ab67104f0688f8b6041bff0de7afbce5f7c90dd0808d62797a93d2 5.476KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1af058b10a893dd7633bbe3cc07cb066b6959e7ec50cbb0e64008314e5bb173b 5.476KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:df02687412efaeb9fa312386237f7dd3ee619e117ed9b325b0e06a2a028e2782 5.476KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0d0c7e233b57192704b2dedd5d4f0dfda4bed6338b319a4812360343b979ee92 5.478KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f583627dbb996c80511fe634a61bdeb8f3dd35eb187133e78a698378fca95b13 5.486KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:88aaef5f8299eee7d78a2b1ad1241abdea159603a40bc868ac83a934a5ec999d 5.493KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:15a9096d15a92d5b10841e5aad29aad6412e950cbc74024ba4475230591f8d3c 5.494KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:558504fd7771b0082f60671247ead83c2fd8b8f14491c1c99b99ec66dab40376 5.494KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:d89a70dc04fc6e70d292f3322aaee071eaaafdfd7e953ceb161c98259619f64b 5.498KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c8219e29d050a107f6985f7bd967279b1fd7ceb5fa83be3c142694d104f858bb 5.5KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3e2b86094e4ac64120d462e4d53e4b7c36254b662c875b0ab31850a52fb90256 5.504KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8be8f5bf2b455746cbf562d609b2e8f54df5efec8df24ee9b56460a730895f69 5.507KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:12932ac9181b1a1a59e0382c117c3dfb5ee6cb2dc2496fd2b6b802aea481464f 5.508KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3a3312cb7e6150b81d7e58c3514647a9a11e83ab95a7e2ff84998c7a64d78783 5.515KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:d17a8cbbf328e76cfcd3eb547eb3dab43b0e133a90e03bdf7699f8839d865edd 5.524KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:92085f2694455ad42f6e10ca2cea07d1b5e6c81d6e83cf7d16221a620ca55fb1 5.525KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:34999445a8e16b0f806263f3c3c12cbc548d9126c717735867e01f831daf529e 5.534KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:20ece8184da485249e438c3cec7629810ec028a15d8bee8695e832cb6163e181 5.539KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:05354db57daa1b551680c37ac8c69c0ae211f8299a73b07310a51347866a67f8 5.54KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5276a9fb191e97f6b88dc74a4bbd2958edcf92a36fb56a5c51b068476b093044 5.541KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:df051b2ab733377fca5ca322be7813189f6090b4790d31fcbca5555ebd87cee5 5.549KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7f42f0f4226a224005eba7a922868dee92eab897262c94ea91cf6f0c8d92e91b 5.556KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:23853d0450a8215823e0e08cc58edf465497612736d360bd822fe01431b426fc 5.564KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:62ed6cf22673a84fe834bbf0e3007d0466b30a014a46b78ffb39ae3275f2174b 5.597KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6e0f0825ec529511e57756cd62a9f5ede0707c4efd22a320ae1988579012eb5f 5.637KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4165e7b8ba961af3593e32d7bd5faeba1e5ae8ab004cb10003a94018b0af367a 5.646KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:26c1d2c2bd96aa7c6d33f978e3799fd3f4d67f379e965bc7e0528b36858e3bc1 5.697KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:685763523acb73f1ddb07ec941b8301308ce1814553817af0e351df7c8ef17d8 5.714KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e74f0ffd4a76f59b227fe1cae11f3d45118c1f4eeab32e4b7fd70e8b69e38ae5 5.888KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:fc13b70f44efc4cf6bed2392aa0bfcd06a15d1f4ae5cb2497b3007d60508e8ee 5.917KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ab43c93c7fb7f23844450231399401666154d0242390ad2fa0d2e1c710040b4e 6.559KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:dbf9377f6234bfdf29a8d6d3abe62a3583d2c209bbaff5486b7c2f556a4ca9fb 6.635KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b59e537855eb8c630a2eaec3964de75b0eeea18328dc8b8867bbb6a4b646b77f 732.4KiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2af143c6c47ae0f226b8eb1110c5aa852311bdbbe0636a9129ec1a3e971b79c3 2.88MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a92f5179b0178f44f503689504e8106ee82d2f625c4e47989142c21ba5f500c7 3.202MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:01fa36ca6909f0e514a00f33ad5edbd0de2b131429797c9c052ee1737f8f7245 4.047MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:24ae7c7b0e3eb42d46333edf62be552c3c86d46e9faf6c39523b8c17155bbc33 4.99MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:87f1d04592edb4fc71983365e203040d882d6f41a5bf17291eb88e9542cb1208 5.182MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0ca795aa6cdec112022d9f5c7cf6310faacf7538bc7e31a8b369c05938611da7 6.087MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4870d2a978695fa0fa092e1e96b45c9d3f24936327f5b7ed01333bc988f464db 6.822MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:47171109e41ce8a3c5f4bb94b0535599865850404657419cd96c377bb7e5be59 6.917MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:83f5f7e4a7addcbf0ede62145af77394dd8edb974d1c16f36c912643f79bd518 7.569MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b585adfe5cfaa5b34ca7b54f12f40eba39ab5cb82b47b7e7599261e3136a4ad9 7.85MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6bdb2282142dd7852d2e1f58b3fd108be39f526a30410aeb5f0a7375330882d8 8.029MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2b2718ebf543971d5b52c8c39845823d07389691d571b739c1ce4b82d7f1f346 8.292MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:467f4f78c166252a31b099b859131cf15221cbaed7e2308f62d878834788dea8 8.499MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e3feff852a7d868ed0dd2e419ed5e00ad245051bb1ec46ca090b6ece85849a61 9.247MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:bf48549af9c55c9115069f079e3934e55f48cdcd5d7b23382adfc0af548cfa52 9.681MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f47dca5f2ae8acba2b14b6f6beb8c4a010e1588c0da05811b29499d5fa4685fe 9.83MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b105bcbf9de06322be61260ffcca07094305ca9b04129d9cd1e4f7dac31feecd 11.17MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6159dec5a784445d9b1c9c51d6ea85c398b6f321564282489e6d9a5c8e5d20f6 11.19MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f7fbf9880ea092360c996995148fb1fb267ade50f929ad651a4fe78017e53299 11.6MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0e76325c9d49e5bc09d3034a4e11a66c094125422db5f89344592b514977875a 13MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c1e8604903b6bdc3bf783b708f9bd64fa943ffaf26f228fb9e1b434fd46d909f 13.17MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:969788af89e4e73465593637818d6e2a4800b3520f69409e3b66c6569072787c 13.69MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e328d6bf4ec4d87d68919ca2f9134e93ba3d21f27be672a2f36620ec119c28f9 13.81MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:bd351232d6454a262be7bb5acf6a5866b0901f1411aabff859b3fa85e775ac1d 14.25MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:62567556c5122b3cbb6448a158215644a97fea1d9c88fcd494cd54559bad3361 14.42MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1fb41adb5e4848a33463516c019fc506654af0432f8417bd21aca00071af317e 14.52MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:301c6345ae9822abe51268fb5879e4482fe9352101b43eea2abb1bb140c7cc18 14.58MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3bc14829c9f2431ea7c1386e7c383ec6e6aeea54d1b44ce163e3618c017ee88c 14.62MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c61d6688415fe2d1ec9dcdb0326bc1a10dd6fc0ef42863246ab09be083bfdc03 14.67MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:73be59b3fb299a2870d1cee913c5a48ab78c64d8df7118a4122229a9586983bf 14.69MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:82724c32b28701f2e55bd32b326baf9f6dac0daa2c05fa964fb19c06e1e18d0e 14.75MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e98f78d8fc4efc52a2179e92da06a01a650eb2183c327d564b409f4d643f2720 14.85MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b840e37a9991b4aaf088613b3b40102da2eebb064c34d6c8e7cffc4ca2811663 15.11MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:33af296f9550ac8619fbdfc618b43c1e1a80030e253f3de11635357a66d2aa1c 15.14MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:555e0b3714ed43d189c78bc6aa8ddce57edea8afd8006eabf902c50132f9d1e5 15.5MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f38b5eb607da36536d75cf4276cd5ca595059b8b5517d55bce2ade3bd74236d3 15.75MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6b74822a7ffd309aba7cbbbd4876e1c588c35e9b64748660c753536688677ed8 15.77MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5382155f45ce16157d984cedd99def0a5423e7ceacbbf11a9fb0153652e426ff 15.92MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1a8b6ffac8314a38a91a05fafea6975d166414f0fa4b8a76e366433d9bad8f5e 15.96MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ce7e423b853dce0c0c172eacb0e50030120389f0689a30fc83bf86324a9e44f0 16.08MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3843dfcc36f497c95d910ff520f4b2ed191c093d377393cabd4b2a6fbd862f2d 16.2MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f311920a63d47f2e921dd7e2b32a782663ba6b90e497804aa91fb190d4943bbb 16.84MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f86a01aff6320364f4a03680f596db653857ce7caf968f6089d686684ff561cf 17.09MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:02ef1a4c96345b12837f89d4ff3bd1f871fc6af4cfcb18f6504707687ee07927 18.49MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:74ff743c4e8b7acf74bb6d8c383fcb65620bd92052bf0a87752f39138fb09db4 18.68MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ce48d108d2cd60beaf8b4ede1c60d71050a38a1f0e55f7f92cc72584b6a04a08 19.01MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7b278e4551a4881b922d14d9c57ad39fb44c48c5e5c9037976051085248b9cc3 19.96MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b2488c20f2a9df9a3ff6c9878a9093947db18469df87036fa9c6f75201acba01 20.1MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:78346d355a2722376df2a06768b929e868ec030f3a87a7bf44494f13d4fcda1d 20.12MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4eba5962921a71cef922ccb9553876964eb61547c670c46e9d931898394ff33e 20.25MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c0484b43cab925de2f3a0c672b6bceb7af20c4fa6fca0ae82f15556c4d3e93f2 20.8MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:008bd91abc1d1d519d41f31915eb15ac732482c51b2115e18fc7c0633d20626d 21.09MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2761257be2b0959e925dd0bbb4f906934af4fef1534ccfe86cc52ea1697d4b59 21.09MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ce1c2a99d84e8b27784c0613219118f19a0243e89d46b843a5b5e3075c5130f8 21.3MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:cdd756c3fca4c66ba90842f6e88aba95c90ca110b3c2f74c0fa05b246b5a5a48 21.8MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7b05aa5cdada720a5bf5b3bcfb91c8884125741d213faaa0a167b9529e11f28f 21.94MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:defcf0a7196c72ad9eb4e487a92ac3c3b9f01261407bdd6d762cfbf902d9c0cb 22.24MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:d4ef9985e9a1817ef203fbea17edae54dd27a81f7e9b867b82ee4a5ebf942930 22.61MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:fb7399e55a7ef1f8251bcb673aa7aa987823ce2785fac304acbc1ec62e57bf89 23.01MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:56e6bcbacf5a00815fde354b62784598d60a482f1b1efb84655d108ec643cc88 24.94MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:954a73f6028b81cb9993ea8606e050cbb23df0f843d4f755be26ba20a274bfbb 25.27MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:30794b7d602c59e7881c1474fadf54f8c61d6a2fb79be6a9a22cf6416be368c9 25.53MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8a38c077bd7962dcac8c1d59f7a1a6ec8cffe0f6c675f3c92a3151faa9bf37bd 25.88MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:345ecff04653665152298a1c6d6875aa21ed518f2306fb94e688ec39baf18dee 25.95MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:03b09fcf1998a76516dc88c94b8153edb7533127b0f747c1e2ec39a124be5a51 26MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a4e55ef066c23bd923a88b0f9419d44e30d25f6dfdf5edee7dc4620a66369810 26.39MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5ba13583a74632a703468a70c73bcc5bef79144e607b993a3f172d9e6d2af3e4 26.93MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:40ae56c8f450ecb53aa5c7400ef3bd2bb270e7038c8f00f689f809b7ec3ad9d8 27.56MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:602211e3f43d3c81e568c52ff9a6fd1629e29e66ab28d6265bc0edf1bc36d766 27.59MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:202fb5eb74862f13cacb5cee51530be6cf8fd7c3c3f592198992f56241d9ac51 28.08MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:84b51a62f00904cd65a00f306da6a861170e1220f683bc312dad94bd8d8a56c6 30.53MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7a26e786da9d280055d3f401ebe299c60170c8a1bdc5180c3f5d22d9246343e4 31.2MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:74bf6ba81a993d1c037b51cafc6f94cf3e329bf38b97cfc6992908afff718e1d 33.05MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:d5d815565cdf434a6e2f46bc23b37efa8c4ef5ae194b960cd3ecd90822de8b58 33.27MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:80a4fe21b7a83dc291c2c21f9e964c3c55fac990b697c39f96808dcfac7e77e7 33.67MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f43081ae02375dce42e568e84a44291414d5ca973ce1c47dbf8659120e1dc77c 34.09MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1523654dc02ea64c62e253402dc20f754cb8a81a040201168a2bfd8e15c45fe3 35.1MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1111520ae65ed363d11477a00174d796fed0b9539b5708c757d45b020b400465 36.12MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b23a1d364b3e96bd1ee334e7f9788a253aefacd51f13405c2f4344d2279f08e1 36.36MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f842b9d1c1c62627c61d41283d724c53ad9ca227b7819425fd9ce49045577d97 37.46MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:173909fbfcda88cf0736b55b2adf1f3f86d3f7b4110589f03c8f9d4f7e650179 39.05MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:90c6be62c99c358304d538506fd147bee8bbff221b413dbe08926b90a1fc52e2 42.06MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e8e5683b8f4b4674b1cfebb857d97c17de836c44def3edc1881cba9315035cb3 44.13MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:97dbacedaf87e6ac3d2a2fcfa6c2f14ea533048906fa1b01c8e0e2675ef3772a 45.75MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:bc2d81b81a49c66888c25d79663934156251ccb9f9f4ec02eded5292947e9e54 48.52MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:618dc818046ab9f68892722acb736d6a32cf32d699f0116c59e5141fabb68e5b 48.96MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:260aa6a10e08227e456de71e41b4c8900f4ffb78266f69f6c69265c83d9b6927 51.17MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6536f05384033dce371a8dfdffc693b5b6b619d8d5cc1603acb267e7ef2e952e 52.61MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ef5581e0237dbac4a9f9b2d1940a0be9243c2afe94cfbd675fbb019cf0670481 55.42MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a1e3781737d115a19e7e32ce52622ba21a2502b2f97a4df510929e2b4b09bdd1 59.57MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8fd74fc7e8e80a9459ee7464fe783766a525da84f812ac68d79c2505f73a9783 60.19MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:78afc5364ad2c981e4a4919f535aaefef9ac2f990837be01c766764e025b1f31 70.59MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:23302e52b49d49a0a25da8ea870bc1973e7d51c9b306f3539cd397318bd8b0a5 72.73MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:059a956574f599b3d56f07c9402adbff767e8a866ef4ea84dcbdf357441841f2 73.72MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:439c5d4945480745585795b45d387de7a30e9e54163d77d88caa14915741b407 79.19MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2359153a27bca65c63f338e96fee80dde74d6b7980f78ad0c62addd5df7f6c9e 79.41MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6aa83f1f7f030a51ca0c5b218cef8fa9ddb3a87d6e6c96d51b148cd683c87018 82.73MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:98704810a0e82c3a3cc94777edbb1ebf605783e8182832c7aef458a20a4f1067 86.14MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0f3cff0a9201ffd8f6fddc3f3eec7f22edbfa428cf5e9b0f8f680d054d7733df 98.27MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7782933e1d24461cf1fdc1e288d5108bb83c2d5ef6b41eaa6753861c41f40162 108.3MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9279c7a69e437bc9aa2b546c958fd6e0895be664ea1b7d89758e95c3009d493d 112.4MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e6cc04222976ebc73bde00828262da8c9610c991234c4ee483c40628ebfc025c 123.3MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:36ae58177a438d826e2ffbabbed17080ff2ee72aed2f54f89c62a9c047ff4384 127.5MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9c5a8f78cc8f1ec1298753e62c70d1bdfa392c50cb78c9d0c1a484942338ec27 136.2MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1b2ebcdc92be4db78eb5ad153af851204a8956e3a96a0dbbd3f95f4822659b6d 144.3MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:efeed057f80f066283589b912b38fd365d606da7db53eeffdece216adf9e7f6e 150.5MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c62dbfc6ecf0ca202c61169528b28cd77971b35adc038061bd1bffdeb0d0cfa7 161.3MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4d84952016a91168425e5397e24822fb5be7d4b1907b2e3c897f4dd75c037089 193.9MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:98960ea4e2ba4c2976bb00ca99efeb3c3688de7b716ebcb0a229d8e87f05c39b 349MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:094bd14a797c763a529e7601431b6916e92517abe4227c5671d7966d0a6a4bdc 530.8MiB
      quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:378875186964f0bed66ee432a65cb02252be43bde26d550f8fc1de29cdda5747 764.3MiB
    blobs:
      registry.svc.ci.openshift.org/ocp/release sha256:cf5693de4d3cdd6f352978b87c8f89ead294eff44938598f57a91cf7a02417d2 1.582KiB
      registry.svc.ci.openshift.org/ocp/release sha256:941e690138be95e5ee6f2cb0dc140f4897a07606fcd2b0866cfd426450af2640 1.628KiB
      registry.svc.ci.openshift.org/ocp/release sha256:227619b3d14b82e10246b60b1308c21b872e486a63a606d7cbdc9a7f52b1be8a 607.9KiB
      registry.svc.ci.openshift.org/ocp/release sha256:01fa36ca6909f0e514a00f33ad5edbd0de2b131429797c9c052ee1737f8f7245 4.047MiB
      registry.svc.ci.openshift.org/ocp/release sha256:b585adfe5cfaa5b34ca7b54f12f40eba39ab5cb82b47b7e7599261e3136a4ad9 7.85MiB
      registry.svc.ci.openshift.org/ocp/release sha256:02ef1a4c96345b12837f89d4ff3bd1f871fc6af4cfcb18f6504707687ee07927 18.49MiB
      registry.svc.ci.openshift.org/ocp/release sha256:23302e52b49d49a0a25da8ea870bc1973e7d51c9b306f3539cd397318bd8b0a5 72.73MiB
    manifests:
      sha256:04e90a1b165f5a5525238cc66efbba8e4d1575b53e41c1a73bb7c1d072b2c415 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-bootstrap
      sha256:0bda4615e409ba89fa03d9bf2ae29b8d0a39af9987059cb62a2470858d316693 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-openshift-controller-manager-operator
      sha256:0c64e90be82b9c8e12437442dd03d028b2fb3613b574ab6825802618b2ee1c8c -> 4.4.0-0.nightly-2020-05-12-084542-prometheus
      sha256:0fe33064c89a27c191c521813d8988ea0637730f09e9464967d5dce27c1e1e3c -> 4.4.0-0.nightly-2020-05-12-084542-cluster-node-tuned
      sha256:0fe88a64940906bb5e75e4142241dc7589e316aed27970ceeea9cf63fbf8ffcb -> 4.4.0-0.nightly-2020-05-12-084542-tests
      sha256:12f37b7d20231ebcc8c7fe5a96c78f446a913e1509a0e5cf0ca1e75fc536d920 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-update-keys
      sha256:14c419c73c0057ffa754108139ab050f00ab4ca55fb36b057394e6db03bd3e95 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-autoscaler-operator
      sha256:1bb13bc0486c78aa61bda07e57b2c9ddb645fc3ea2de5f36bc63997eefcd8773 -> 4.4.0-0.nightly-2020-05-12-084542-docker-builder
      sha256:202189109f9eacb36d906faed98419cf491c6cc19f282cd32311480f1c136a46 -> 4.4.0-0.nightly-2020-05-12-084542-ironic-hardware-inventory-recorder
      sha256:2132e9d4c2533bf28326e3a1396d8877132a3252068083c50e0d5a09845dbd37 -> 4.4.0-0.nightly-2020-05-12-084542-operator-lifecycle-manager
      sha256:22edf424aa729ff07e5e4dd380a13e18d227517e5d7d94a084059afba806d027 -> 4.4.0-0.nightly-2020-05-12-084542-baremetal-installer
      sha256:274315474dc669c548004ab183d6f63f7b18849c436d46eb65c89ba9bcf1a302 -> 4.4.0-0.nightly-2020-05-12-084542-kuryr-cni
      sha256:279eb788fc275b7e5e98da14e6c1be82e8d1f5694981628dd4bca29f68ca79d5 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-network-operator
      sha256:27dd04afbb760acdb9465d3659d446adc64c7ffd45bb4905f72d7ad20ba69f62 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-authentication-operator
      sha256:29ddffd83d2035f76a649223a0fa850ad63a3ca441f6d217a721574465f47338 -> 4.4.0-0.nightly-2020-05-12-084542-coredns
      sha256:2a827b677e38178c8c89577443038adc167b68b3dd085ef2f6c1cd74919094bb -> 4.4.0-0.nightly-2020-05-12-084542-cluster-storage-operator
      sha256:2c8dc6cc04ec0b3feba4065ad50d4c741c3d914002916a219415c25ab11b115a -> 4.4.0-0.nightly-2020-05-12-084542-cli
      sha256:2cf5c438a55fa76e14804ccfb7ac4ebad197e4668ae027ca22085ca068e1ddb9 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-version-operator
      sha256:309f8d90bbbc7571676a0ac7abead9370908df74fcc4dcc1705261691e9f56d7 -> 4.4.0-0.nightly-2020-05-12-084542-prom-label-proxy
      sha256:31d0fcd6fe9aee3b995589e8f6f38179dd2310dc1c1fbf9bafad5c39ef94d990 -> 4.4.0-0.nightly-2020-05-12-084542-grafana
      sha256:38c04fb56229b8227d891f823c716905b45f70322d20c926c4c2f1816c4cb4a4 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-svcat-apiserver-operator
      sha256:39e54971c8dba664155abdde36a01c06153e39a8522ce4b07103141640efc494 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-openshift-apiserver-operator
      sha256:3e3548f71970f182836075330e34334c92bd2ffb1091520efea64f33778cc76a -> 4.4.0-0.nightly-2020-05-12-084542-kube-storage-version-migrator
      sha256:40cdcce33f8d11350979baf65a2893fb24e3d69c95117917503748aef02adb2b -> 4.4.0-0.nightly-2020-05-12-084542-cluster-node-tuning-operator
      sha256:417ce6b653bbd2b53adc22936fae430abb3da3b6108f469c2cc1580851bdc97e -> 4.4.0-0.nightly-2020-05-12-084542-console
      sha256:45dcbfa91b3f17e36b631a07d1a2971fc4e27d2bed4e043dd8e52868391ed6a3 -> 4.4.0-0.nightly-2020-05-12-084542-baremetal-operator
      sha256:47b8c0277caa1619debd9e8cb4fc70d6490bdb79a0a4cc5cb5ca9742a57371c9 -> 4.4.0-0.nightly-2020-05-12-084542-machine-config-operator
      sha256:48052dc2fc2190e75d629ce9ad7f348ea295beca1de6c07bd23c0074a59623b4 -> 4.4.0-0.nightly-2020-05-12-084542-cloud-credential-operator
      sha256:4cdf6831c9926794a6a260d458579e99d58c68e60a2ac1adfbdb2f61ebfa7185 -> 4.4.0-0.nightly-2020-05-12-084542-cli-artifacts
      sha256:4e478687ea087d47b88db680e4db07d75af9f55e83a648d28bec82ebf4b876c9 -> 4.4.0-0.nightly-2020-05-12-084542-service-catalog
      sha256:51549e2ba6f17609621b2f0c469b65abbe9469f83849c88ade0f1a9016253620 -> 4.4.0-0.nightly-2020-05-12-084542-prometheus-node-exporter
      sha256:531fe6f2038f1e7c824c4356652e390d0e0c44c53d228f46c04c0714006d7d99 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-kube-apiserver-operator
      sha256:532f6d7205b0477c07e0b5e7c1e97408623d56c71aa8a4302a5fce0458143a1c -> 4.4.0-0.nightly-2020-05-12-084542-kube-client-agent
      sha256:54202be8771734adc799f5f03607ba351c313e9f9a2dbfcc7d7106ecc97b910d -> 4.4.0-0.nightly-2020-05-12-084542-cluster-etcd-operator
      sha256:5477346ae4c3ac18d8fcfc5ced163d94eb7d1bb5a935baec507d7432fbaf21ad -> 4.4.0-0.nightly-2020-05-12-084542-cluster-ingress-operator
      sha256:5e410a6b4643cbd7369e179c3ae0a1e6a26a6100a2db214cbe7e1e0267120506 -> 4.4.0-0.nightly-2020-05-12-084542-multus-admission-controller
      sha256:5e90332b947a7cbfeebb8bcd468facfc1686280a03868a5c33509e834a44adc9 -> 4.4.0-0.nightly-2020-05-12-084542-multus-route-override-cni
      sha256:5f85eb7824a3246922296dcc41a5f36465424906d8c6d8b865d2e6283f79b3e1 -> 4.4.0-0.nightly-2020-05-12-084542-operator-marketplace
      sha256:637aebfa978ce3dfd4ddbd3f50119bed3e5eb9b8a6a4b0c0d6c651c516d8de53 -> 4.4.0-0.nightly-2020-05-12-084542-must-gather
      sha256:6594664ba965e195e06a70814e88895b2e92dc4746bdb1ec17b068f082405baf -> 4.4.0-0.nightly-2020-05-12-084542-mdns-publisher
      sha256:69aa7e333ef370d2af67f1159a7638b30dbff6ad934ae7ca64062b67456d5eef -> 4.4.0-0.nightly-2020-05-12-084542-cluster-csi-snapshot-controller-operator
      sha256:6a9fe07fe32a4de730689f1b9279e7b9f68688802d2192d2ba7ae42c93d31041 -> 4.4.0-0.nightly-2020-05-12-084542-console-operator
      sha256:6ae6b8b0285e03ca8e67674cb2c0bf0d0aa43305fdd0a43fcadbac71899ec11d -> 4.4.0-0.nightly-2020-05-12-084542-ironic-machine-os-downloader
      sha256:6b20afa0a4ada35061bf34f93795fe6553ccc67edc3ea1f9276709f55a16b311 -> 4.4.0-0.nightly-2020-05-12-084542-insights-operator
      sha256:6ea32f7d002d2c5a761f68227417280c7fbf77db856f379af2d4bac57bd236d9 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-samples-operator
      sha256:6ece6a63e4018076c9af08fb5a1ec9bd6834d7aea9c25197d3b4a9002f622c0d -> 4.4.0-0.nightly-2020-05-12-084542-oauth-server
      sha256:6f23aaaebd6193b8d1989d90a7146744bb72be0ea0425553d8da5fb88c7f027e -> 4.4.0-0.nightly-2020-05-12-084542-machine-api-operator
      sha256:718280f54468b7c6a8edc9f0b67c136fe651ea9b5bd9495d02360c52f0839a11 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-kube-controller-manager-operator
      sha256:74e91c86451c0758d7b27cc794b2a329d5f21dfccd01b49d5f1181f9e56a59e7 -> 4.4.0-0.nightly-2020-05-12-084542-kuryr-controller
      sha256:764345d2a8222bd915b8850465b1cb33178e511ee941cc3fb9e7ed4a5c6417b5 -> 4.4.0-0.nightly-2020-05-12-084542-etcd
      sha256:77f4e69ccef6321cded24a6bb61faf8196faefe33b56a057ffe7f262030fdd29 -> 4.4.0-0.nightly-2020-05-12-084542-jenkins
      sha256:78241892eb5ceb7e7c8f6d2b2f890b8a0514a94152ed81b2781024385d984b42 -> 4.4.0-0.nightly-2020-05-12-084542-keepalived-ipfailover
      sha256:7ea1164981839e136630a160dcaec2bf51a7422da87b342b6462c102cb9e61a5 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-kube-storage-version-migrator-operator
      sha256:81b478bd3e66a6de1b68ae4c49a873ef6a8745d503bbb0a92d71f0677a1beb4e -> 4.4.0-0.nightly-2020-05-12-084542-cluster-kube-scheduler-operator
      sha256:830d3f0b1c6d068e0ff0558e53fbedab3e86dc7ab2d40f6d30ad1a6d837fa357 -> 4.4.0-0.nightly-2020-05-12-084542-deployer
      sha256:843a3c9fdea2eb96078e0030b67b8696df847b5b47b151ddeda67dd0155c37a9 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-image-registry-operator
      sha256:848d83177980036852586d28206ae0d540403515d8c9052b65a8c3a02218809e -> 4.4.0-0.nightly-2020-05-12-084542-configmap-reloader
      sha256:85bcf7dd28ad04d057829521eb74aabb060da14bb6b67ac22b12f76924a9bb4d -> 4.4.0-0.nightly-2020-05-12-084542-telemeter
      sha256:8735f072f7a7ff1be26ffa093ae520e0c58dbd541c362c54324c223d24f74f5a -> 4.4.0-0.nightly-2020-05-12-084542-ironic-inspector
      sha256:90c2cc7e333b6256a262fbd803953e1de1bc44a9b3cdaddffc9aaec9336ef619 -> 4.4.0-0.nightly-2020-05-12-084542-prometheus-alertmanager
      sha256:90c7126509197ade3182af767beae4d767fe9d807c3e42fdc11053e22f142c8d -> 4.4
      sha256:90e3d51f5292bb841e97f5074425055dbaac637736d19b3be1f35476a3760958 -> 4.4.0-0.nightly-2020-05-12-084542-kube-etcd-signer-server
      sha256:94b3c2f43b6ffc0a6745a2bd0caa80097fbafa8f27ab867924fe86431bf1e835 -> 4.4.0-0.nightly-2020-05-12-084542-aws-machine-controllers
      sha256:94e8f008a2b24b4fe22614d12143ed32e4c255fc0a8cde0b9e9d267754e97c6a -> 4.4.0-0.nightly-2020-05-12-084542-hyperkube
      sha256:989f64140c18d60fcd6c5cef6baadfdcdfce2740640e9febb287ad648af75210 -> 4.4.0-0.nightly-2020-05-12-084542-ironic
      sha256:9904b89c691bb372e552936b9e7879767323a9d0df1f70d1d1862afec71bd9c4 -> 4.4.0-0.nightly-2020-05-12-084542-libvirt-machine-controllers
      sha256:9b6035e757877b64304a1b19d0315d8fe4f220ec2d14d0d10f34d85f03b77fe6 -> 4.4.0-0.nightly-2020-05-12-084542-multus-whereabouts-ipam-cni
      sha256:9c7107162f06b86678949d6010c039acdf07533c7504ae59cf119081b1a04cff -> 4.4.0-0.nightly-2020-05-12-084542-oauth-proxy
      sha256:a1a705b3d44b5b5546d6b96edc4f2e7e25aa47e4d23035df0ecaadb1161b760b -> 4.4.0-0.nightly-2020-05-12-084542-prometheus-config-reloader
      sha256:a20665686eba112407b8df6e7e7a2f739d5666b16e67fc4a468696734951b080 -> 4.4.0-0.nightly-2020-05-12-084542-thanos
      sha256:a47aea1279c42bfa4d6f8f4b692620db6c9888c8670c2b5c3da2cda26277b880 -> 4.4.0-0.nightly-2020-05-12-084542-kube-state-metrics
      sha256:a6f71083c0a245a88fc5bdb3f5451df2418c80a2276f19196478fc0b92129f72 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-autoscaler
      sha256:aa41dd47ee65b55922f97de0ed5abca86021c461f364ef0ddfabe5a39664f455 -> 4.4.0-0.nightly-2020-05-12-084542-container-networking-plugins
      sha256:b14cbc3d5f2b568df1948d9017efa22b70a6c731387efc73a90c8f5c571b736c -> 4.4.0-0.nightly-2020-05-12-084542-ovn-kubernetes
      sha256:b8eadbf0b60677ac9faa6eccf7a08ea7680b26d875d96914a038f0b68017cebd -> 4.4.0-0.nightly-2020-05-12-084542-local-storage-static-provisioner
      sha256:bd9c6cc3542a1e4cb313c4c5ae4af24658f4954072c388428d61dcbcf9ab1ea8 -> 4.4.0-0.nightly-2020-05-12-084542-openstack-machine-controllers
      sha256:bda2450134605bda3c59e1304df18dfc7b13054530d9726e4d7625d5ca19e0a7 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-policy-controller
      sha256:bf056e6c19bde86dbd42ab3637ef0d5c99ee33aa062b9c352fd4b7168d920e78 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-config-operator
      sha256:bf6590692745cc32a12779117146e87b672067c361329c6cdaa3bab1a4447004 -> 4.4.0-0.nightly-2020-05-12-084542-sdn
      sha256:cb6adb576de07ef386f14c4f0d5cd6fd0d6f871e6e508576894c1394da58eda3 -> 4.4.0-0.nightly-2020-05-12-084542-multus-cni
      sha256:cc0cc21371a77bbe9b41b7a5b9acdb04b1903f9f8995d78541ebc4fca27a7d9a -> 4.4.0-0.nightly-2020-05-12-084542-openshift-controller-manager
      sha256:cf3c5100647d8a2cf5bb0bbb4b78f93069b0980c187be4e71140b8f3bfea7261 -> 4.4.0-0.nightly-2020-05-12-084542-prometheus-operator
      sha256:cfdf08b7051be381b0f6431df98f2cc552356f2b2c910506e268b1a8bd54bd77 -> 4.4.0-0.nightly-2020-05-12-084542-gcp-machine-controllers
      sha256:d0caedb5ce4fdfe1cdb6bd122ff3e676356fb8be716508c42a00db04126d9c65 -> 4.4.0-0.nightly-2020-05-12-084542-machine-os-content
      sha256:d2b519f7834eb10b1db5ec482275b59e445c57d1541786300bd704068de0d09a -> 4.4.0-0.nightly-2020-05-12-084542-cluster-machine-approver
      sha256:d34b20bb3302bbd408a46002c47678f5bf613cf6c15966126967e7abd26c49d3 -> 4.4.0-0.nightly-2020-05-12-084542-haproxy-router
      sha256:d424724a427fe2db573c5ac15edd05289e0a9573b7a9b195ae382e05c52deb0b -> 4.4.0-0.nightly-2020-05-12-084542-kube-proxy
      sha256:d666b0ad78ea2344e18dbb71914db9816402af3c6844e1452d5c974432d7c8d0 -> 4.4.0-0.nightly-2020-05-12-084542-jenkins-agent-maven
      sha256:d6e9896151e6dfbd89147690d33e1e4a51b12e88931e36701d36d189bb2f4565 -> 4.4.0-0.nightly-2020-05-12-084542-baremetal-machine-controllers
      sha256:d852eff04adba4a32cb241db4509fcc2dcdc83752699f8e07a8ff5b52ef4ea44 -> 4.4.0-0.nightly-2020-05-12-084542-k8s-prometheus-adapter
      sha256:dd366d2025bf11f9d340cbf6b97bf4243c6c2afcab2a2bfbbb2b1aabdb6d67e0 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-dns-operator
      sha256:dd59894aba7f45baa4b9e31141df00cea389a3a90018d68c4b6801ce0cfa1c7d -> 4.4.0-0.nightly-2020-05-12-084542-openshift-apiserver
      sha256:ddc3bdec7cd26e65f3e4139f37a6ff601da9551bdc4daf7fee7b4b7a5bf19cb0 -> 4.4.0-0.nightly-2020-05-12-084542-operator-registry
      sha256:df9eb3be1abd5bd137c5c417f98339bd35dc315d6776a74fd8dea95a3bbf80af -> 4.4.0-0.nightly-2020-05-12-084542-ovirt-machine-controllers
      sha256:e03b4e754721f89e3c17300ad15554aeac2aef77b8ff65f06e72721f420e30f3 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-svcat-controller-manager-operator
      sha256:e0f9b3b61b5bfdc543373de25764958c4c1bbc639501924268c6cf4cd455f53e -> 4.4.0-0.nightly-2020-05-12-084542-baremetal-runtimecfg
      sha256:e14585f3f272412c4618dcf47b9ec0befbe029ac1eb293d7aaa39e73b22bb475 -> 4.4.0-0.nightly-2020-05-12-084542-installer-artifacts
      sha256:e25caadca2b6afce179820345d99f271304573ca54ad3e27ba20cd2141f72fbb -> 4.4.0-0.nightly-2020-05-12-084542-pod
      sha256:e2da5b5058fdd98aa5c2cf26bdb094379349fb8501dae2d8c77f891e5fdfe7f6 -> 4.4.0-0.nightly-2020-05-12-084542-kube-rbac-proxy
      sha256:e9110c2172cca8deec242dceec5f8e3846c28cc8dd7f7c586e5db7deb7740ebe -> 4.4.0-0.nightly-2020-05-12-084542-installer
      sha256:e9fb07fc68b8e0df897e4d4d5f916487dcea09b38011e942fcfcec9257af9c65 -> 4.4.0-0.nightly-2020-05-12-084542-openshift-state-metrics
      sha256:ec0aa4d53f52b1601675cd45394c2fe434ba2fe753f502e3a6140e3e41ea2386 -> 4.4.0-0.nightly-2020-05-12-084542-ironic-static-ip-manager
      sha256:f0d65fd2470905ef20dbd20e437c0d9739a14253f173f57157771b47aea455e8 -> 4.4.0-0.nightly-2020-05-12-084542-azure-machine-controllers
      sha256:f432245ebeace22416db322ede2127f3cc1b8e99f64d8dec17007d66b16a7310 -> 4.4.0-0.nightly-2020-05-12-084542-cluster-monitoring-operator
      sha256:f547f507fafcfb0a743672e7ae589f160aa6af0daf39b39ed00b4f967a5328fa -> 4.4.0-0.nightly-2020-05-12-084542-ironic-ipa-downloader
      sha256:f9870984bcbff1458d5293338f82caa512acc2b528bfab59c3be9056b42885fc -> 4.4.0-0.nightly-2020-05-12-084542-csi-snapshot-controller
      sha256:fbf1f92674538741c4717cec2da64c1dea267cb1d3c98edeb0fe2ac507302187 -> 4.4.0-0.nightly-2020-05-12-084542-service-ca-operator
      sha256:fdc4d591e97819444d69879f57f6507fd1f2b6c481c5d750675e0ef11b1953c7 -> 4.4.0-0.nightly-2020-05-12-084542-jenkins-agent-nodejs
      sha256:fde4ec95a2cca5c8799d6b45212ca2aeedd3c4964c27e6ecb7be78bc93b84bbd -> 4.4.0-0.nightly-2020-05-12-084542-docker-registry
  stats: shared=5 unique=222 size=5.431GiB ratio=0.98

phase 0:
  lab-installer.baremetal:5000 ocp/release blobs=227 mounts=0 manifests=109 shared=5

info: Planning completed in 21.15s
uploading: lab-installer.baremetal:5000/ocp/release sha256:83f5f7e4a7addcbf0ede62145af77394dd8edb974d1c16f36c912643f79bd518 7.569MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:ce1c2a99d84e8b27784c0613219118f19a0243e89d46b843a5b5e3075c5130f8 21.3MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:a92f5179b0178f44f503689504e8106ee82d2f625c4e47989142c21ba5f500c7 3.202MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:40ae56c8f450ecb53aa5c7400ef3bd2bb270e7038c8f00f689f809b7ec3ad9d8 27.56MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:2af143c6c47ae0f226b8eb1110c5aa852311bdbbe0636a9129ec1a3e971b79c3 2.88MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:6aa83f1f7f030a51ca0c5b218cef8fa9ddb3a87d6e6c96d51b148cd683c87018 82.73MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:d5d815565cdf434a6e2f46bc23b37efa8c4ef5ae194b960cd3ecd90822de8b58 33.27MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:439c5d4945480745585795b45d387de7a30e9e54163d77d88caa14915741b407 79.19MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:555e0b3714ed43d189c78bc6aa8ddce57edea8afd8006eabf902c50132f9d1e5 15.5MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:47171109e41ce8a3c5f4bb94b0535599865850404657419cd96c377bb7e5be59 6.917MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:4870d2a978695fa0fa092e1e96b45c9d3f24936327f5b7ed01333bc988f464db 6.822MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:9279c7a69e437bc9aa2b546c958fd6e0895be664ea1b7d89758e95c3009d493d 112.4MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:defcf0a7196c72ad9eb4e487a92ac3c3b9f01261407bdd6d762cfbf902d9c0cb 22.24MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:b2488c20f2a9df9a3ff6c9878a9093947db18469df87036fa9c6f75201acba01 20.1MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:6159dec5a784445d9b1c9c51d6ea85c398b6f321564282489e6d9a5c8e5d20f6 11.19MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:7a26e786da9d280055d3f401ebe299c60170c8a1bdc5180c3f5d22d9246343e4 31.2MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:23302e52b49d49a0a25da8ea870bc1973e7d51c9b306f3539cd397318bd8b0a5 72.73MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:954a73f6028b81cb9993ea8606e050cbb23df0f843d4f755be26ba20a274bfbb 25.27MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:c0484b43cab925de2f3a0c672b6bceb7af20c4fa6fca0ae82f15556c4d3e93f2 20.8MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:6bdb2282142dd7852d2e1f58b3fd108be39f526a30410aeb5f0a7375330882d8 8.029MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:3bc14829c9f2431ea7c1386e7c383ec6e6aeea54d1b44ce163e3618c017ee88c 14.62MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:f47dca5f2ae8acba2b14b6f6beb8c4a010e1588c0da05811b29499d5fa4685fe 9.83MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:e6cc04222976ebc73bde00828262da8c9610c991234c4ee483c40628ebfc025c 123.3MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:02ef1a4c96345b12837f89d4ff3bd1f871fc6af4cfcb18f6504707687ee07927 18.49MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:1a8b6ffac8314a38a91a05fafea6975d166414f0fa4b8a76e366433d9bad8f5e 15.96MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:6536f05384033dce371a8dfdffc693b5b6b619d8d5cc1603acb267e7ef2e952e 52.61MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:ce48d108d2cd60beaf8b4ede1c60d71050a38a1f0e55f7f92cc72584b6a04a08 19.01MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:4d84952016a91168425e5397e24822fb5be7d4b1907b2e3c897f4dd75c037089 193.9MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:fb7399e55a7ef1f8251bcb673aa7aa987823ce2785fac304acbc1ec62e57bf89 23.01MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:efeed057f80f066283589b912b38fd365d606da7db53eeffdece216adf9e7f6e 150.5MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:84b51a62f00904cd65a00f306da6a861170e1220f683bc312dad94bd8d8a56c6 30.53MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:e8e5683b8f4b4674b1cfebb857d97c17de836c44def3edc1881cba9315035cb3 44.13MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:173909fbfcda88cf0736b55b2adf1f3f86d3f7b4110589f03c8f9d4f7e650179 39.05MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:5382155f45ce16157d984cedd99def0a5423e7ceacbbf11a9fb0153652e426ff 15.92MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:c61d6688415fe2d1ec9dcdb0326bc1a10dd6fc0ef42863246ab09be083bfdc03 14.67MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:8fd74fc7e8e80a9459ee7464fe783766a525da84f812ac68d79c2505f73a9783 60.19MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:8a38c077bd7962dcac8c1d59f7a1a6ec8cffe0f6c675f3c92a3151faa9bf37bd 25.88MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:74ff743c4e8b7acf74bb6d8c383fcb65620bd92052bf0a87752f39138fb09db4 18.68MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:f86a01aff6320364f4a03680f596db653857ce7caf968f6089d686684ff561cf 17.09MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:345ecff04653665152298a1c6d6875aa21ed518f2306fb94e688ec39baf18dee 25.95MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:9c5a8f78cc8f1ec1298753e62c70d1bdfa392c50cb78c9d0c1a484942338ec27 136.2MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:24ae7c7b0e3eb42d46333edf62be552c3c86d46e9faf6c39523b8c17155bbc33 4.99MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:467f4f78c166252a31b099b859131cf15221cbaed7e2308f62d878834788dea8 8.499MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:82724c32b28701f2e55bd32b326baf9f6dac0daa2c05fa964fb19c06e1e18d0e 14.75MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:1523654dc02ea64c62e253402dc20f754cb8a81a040201168a2bfd8e15c45fe3 35.1MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:059a956574f599b3d56f07c9402adbff767e8a866ef4ea84dcbdf357441841f2 73.72MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:4eba5962921a71cef922ccb9553876964eb61547c670c46e9d931898394ff33e 20.25MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:260aa6a10e08227e456de71e41b4c8900f4ffb78266f69f6c69265c83d9b6927 51.17MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:56e6bcbacf5a00815fde354b62784598d60a482f1b1efb84655d108ec643cc88 24.94MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:03b09fcf1998a76516dc88c94b8153edb7533127b0f747c1e2ec39a124be5a51 26MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:bc2d81b81a49c66888c25d79663934156251ccb9f9f4ec02eded5292947e9e54 48.52MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:602211e3f43d3c81e568c52ff9a6fd1629e29e66ab28d6265bc0edf1bc36d766 27.59MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:0ca795aa6cdec112022d9f5c7cf6310faacf7538bc7e31a8b369c05938611da7 6.087MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:bf48549af9c55c9115069f079e3934e55f48cdcd5d7b23382adfc0af548cfa52 9.681MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:202fb5eb74862f13cacb5cee51530be6cf8fd7c3c3f592198992f56241d9ac51 28.08MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:1fb41adb5e4848a33463516c019fc506654af0432f8417bd21aca00071af317e 14.52MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:f38b5eb607da36536d75cf4276cd5ca595059b8b5517d55bce2ade3bd74236d3 15.75MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:33af296f9550ac8619fbdfc618b43c1e1a80030e253f3de11635357a66d2aa1c 15.14MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:7782933e1d24461cf1fdc1e288d5108bb83c2d5ef6b41eaa6753861c41f40162 108.3MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:094bd14a797c763a529e7601431b6916e92517abe4227c5671d7966d0a6a4bdc 530.8MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:618dc818046ab9f68892722acb736d6a32cf32d699f0116c59e5141fabb68e5b 48.96MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:1111520ae65ed363d11477a00174d796fed0b9539b5708c757d45b020b400465 36.12MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:c62dbfc6ecf0ca202c61169528b28cd77971b35adc038061bd1bffdeb0d0cfa7 161.3MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:f7fbf9880ea092360c996995148fb1fb267ade50f929ad651a4fe78017e53299 11.6MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:0e76325c9d49e5bc09d3034a4e11a66c094125422db5f89344592b514977875a 13MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:5ba13583a74632a703468a70c73bcc5bef79144e607b993a3f172d9e6d2af3e4 26.93MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:f311920a63d47f2e921dd7e2b32a782663ba6b90e497804aa91fb190d4943bbb 16.84MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:1b2ebcdc92be4db78eb5ad153af851204a8956e3a96a0dbbd3f95f4822659b6d 144.3MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:73be59b3fb299a2870d1cee913c5a48ab78c64d8df7118a4122229a9586983bf 14.69MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:36ae58177a438d826e2ffbabbed17080ff2ee72aed2f54f89c62a9c047ff4384 127.5MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:87f1d04592edb4fc71983365e203040d882d6f41a5bf17291eb88e9542cb1208 5.182MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:a1e3781737d115a19e7e32ce52622ba21a2502b2f97a4df510929e2b4b09bdd1 59.57MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:01fa36ca6909f0e514a00f33ad5edbd0de2b131429797c9c052ee1737f8f7245 4.047MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:7b05aa5cdada720a5bf5b3bcfb91c8884125741d213faaa0a167b9529e11f28f 21.94MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:98960ea4e2ba4c2976bb00ca99efeb3c3688de7b716ebcb0a229d8e87f05c39b 349MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:301c6345ae9822abe51268fb5879e4482fe9352101b43eea2abb1bb140c7cc18 14.58MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:378875186964f0bed66ee432a65cb02252be43bde26d550f8fc1de29cdda5747 764.3MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:f43081ae02375dce42e568e84a44291414d5ca973ce1c47dbf8659120e1dc77c 34.09MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:008bd91abc1d1d519d41f31915eb15ac732482c51b2115e18fc7c0633d20626d 21.09MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:c1e8604903b6bdc3bf783b708f9bd64fa943ffaf26f228fb9e1b434fd46d909f 13.17MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:80a4fe21b7a83dc291c2c21f9e964c3c55fac990b697c39f96808dcfac7e77e7 33.67MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:e98f78d8fc4efc52a2179e92da06a01a650eb2183c327d564b409f4d643f2720 14.85MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:2761257be2b0959e925dd0bbb4f906934af4fef1534ccfe86cc52ea1697d4b59 21.09MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:3843dfcc36f497c95d910ff520f4b2ed191c093d377393cabd4b2a6fbd862f2d 16.2MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:78346d355a2722376df2a06768b929e868ec030f3a87a7bf44494f13d4fcda1d 20.12MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:97dbacedaf87e6ac3d2a2fcfa6c2f14ea533048906fa1b01c8e0e2675ef3772a 45.75MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:d4ef9985e9a1817ef203fbea17edae54dd27a81f7e9b867b82ee4a5ebf942930 22.61MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:e3feff852a7d868ed0dd2e419ed5e00ad245051bb1ec46ca090b6ece85849a61 9.247MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:b23a1d364b3e96bd1ee334e7f9788a253aefacd51f13405c2f4344d2279f08e1 36.36MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:bd351232d6454a262be7bb5acf6a5866b0901f1411aabff859b3fa85e775ac1d 14.25MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:62567556c5122b3cbb6448a158215644a97fea1d9c88fcd494cd54559bad3361 14.42MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:e328d6bf4ec4d87d68919ca2f9134e93ba3d21f27be672a2f36620ec119c28f9 13.81MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:ef5581e0237dbac4a9f9b2d1940a0be9243c2afe94cfbd675fbb019cf0670481 55.42MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:a4e55ef066c23bd923a88b0f9419d44e30d25f6dfdf5edee7dc4620a66369810 26.39MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:90c6be62c99c358304d538506fd147bee8bbff221b413dbe08926b90a1fc52e2 42.06MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:b59e537855eb8c630a2eaec3964de75b0eeea18328dc8b8867bbb6a4b646b77f 732.4KiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:74bf6ba81a993d1c037b51cafc6f94cf3e329bf38b97cfc6992908afff718e1d 33.05MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:f842b9d1c1c62627c61d41283d724c53ad9ca227b7819425fd9ce49045577d97 37.46MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:2b2718ebf543971d5b52c8c39845823d07389691d571b739c1ce4b82d7f1f346 8.292MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:b105bcbf9de06322be61260ffcca07094305ca9b04129d9cd1e4f7dac31feecd 11.17MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:cdd756c3fca4c66ba90842f6e88aba95c90ca110b3c2f74c0fa05b246b5a5a48 21.8MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:2359153a27bca65c63f338e96fee80dde74d6b7980f78ad0c62addd5df7f6c9e 79.41MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:78afc5364ad2c981e4a4919f535aaefef9ac2f990837be01c766764e025b1f31 70.59MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:6b74822a7ffd309aba7cbbbd4876e1c588c35e9b64748660c753536688677ed8 15.77MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:b585adfe5cfaa5b34ca7b54f12f40eba39ab5cb82b47b7e7599261e3136a4ad9 7.85MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:7b278e4551a4881b922d14d9c57ad39fb44c48c5e5c9037976051085248b9cc3 19.96MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:b840e37a9991b4aaf088613b3b40102da2eebb064c34d6c8e7cffc4ca2811663 15.11MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:969788af89e4e73465593637818d6e2a4800b3520f69409e3b66c6569072787c 13.69MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:ce7e423b853dce0c0c172eacb0e50030120389f0689a30fc83bf86324a9e44f0 16.08MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:98704810a0e82c3a3cc94777edbb1ebf605783e8182832c7aef458a20a4f1067 86.14MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:0f3cff0a9201ffd8f6fddc3f3eec7f22edbfa428cf5e9b0f8f680d054d7733df 98.27MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:30794b7d602c59e7881c1474fadf54f8c61d6a2fb79be6a9a22cf6416be368c9 25.53MiB
uploading: lab-installer.baremetal:5000/ocp/release sha256:227619b3d14b82e10246b60b1308c21b872e486a63a606d7cbdc9a7f52b1be8a 607.9KiB
sha256:ec0aa4d53f52b1601675cd45394c2fe434ba2fe753f502e3a6140e3e41ea2386 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-ironic-static-ip-manager
sha256:718280f54468b7c6a8edc9f0b67c136fe651ea9b5bd9495d02360c52f0839a11 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-kube-controller-manager-operator
sha256:27dd04afbb760acdb9465d3659d446adc64c7ffd45bb4905f72d7ad20ba69f62 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-authentication-operator
sha256:848d83177980036852586d28206ae0d540403515d8c9052b65a8c3a02218809e lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-configmap-reloader
sha256:29ddffd83d2035f76a649223a0fa850ad63a3ca441f6d217a721574465f47338 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-coredns
sha256:90c2cc7e333b6256a262fbd803953e1de1bc44a9b3cdaddffc9aaec9336ef619 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-prometheus-alertmanager
sha256:9c7107162f06b86678949d6010c039acdf07533c7504ae59cf119081b1a04cff lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-oauth-proxy
sha256:d666b0ad78ea2344e18dbb71914db9816402af3c6844e1452d5c974432d7c8d0 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-jenkins-agent-maven
sha256:39e54971c8dba664155abdde36a01c06153e39a8522ce4b07103141640efc494 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-openshift-apiserver-operator
sha256:cf3c5100647d8a2cf5bb0bbb4b78f93069b0980c187be4e71140b8f3bfea7261 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-prometheus-operator
sha256:74e91c86451c0758d7b27cc794b2a329d5f21dfccd01b49d5f1181f9e56a59e7 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-kuryr-controller
sha256:5e410a6b4643cbd7369e179c3ae0a1e6a26a6100a2db214cbe7e1e0267120506 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-multus-admission-controller
sha256:1bb13bc0486c78aa61bda07e57b2c9ddb645fc3ea2de5f36bc63997eefcd8773 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-docker-builder
sha256:a20665686eba112407b8df6e7e7a2f739d5666b16e67fc4a468696734951b080 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-thanos
sha256:2132e9d4c2533bf28326e3a1396d8877132a3252068083c50e0d5a09845dbd37 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-operator-lifecycle-manager
sha256:5477346ae4c3ac18d8fcfc5ced163d94eb7d1bb5a935baec507d7432fbaf21ad lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-ingress-operator
sha256:6f23aaaebd6193b8d1989d90a7146744bb72be0ea0425553d8da5fb88c7f027e lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-machine-api-operator
sha256:6ece6a63e4018076c9af08fb5a1ec9bd6834d7aea9c25197d3b4a9002f622c0d lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-oauth-server
sha256:2cf5c438a55fa76e14804ccfb7ac4ebad197e4668ae027ca22085ca068e1ddb9 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-version-operator
sha256:81b478bd3e66a6de1b68ae4c49a873ef6a8745d503bbb0a92d71f0677a1beb4e lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-kube-scheduler-operator
sha256:d2b519f7834eb10b1db5ec482275b59e445c57d1541786300bd704068de0d09a lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-machine-approver
sha256:78241892eb5ceb7e7c8f6d2b2f890b8a0514a94152ed81b2781024385d984b42 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-keepalived-ipfailover
sha256:85bcf7dd28ad04d057829521eb74aabb060da14bb6b67ac22b12f76924a9bb4d lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-telemeter
sha256:e03b4e754721f89e3c17300ad15554aeac2aef77b8ff65f06e72721f420e30f3 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-svcat-controller-manager-operator
sha256:e9fb07fc68b8e0df897e4d4d5f916487dcea09b38011e942fcfcec9257af9c65 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-openshift-state-metrics
sha256:274315474dc669c548004ab183d6f63f7b18849c436d46eb65c89ba9bcf1a302 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-kuryr-cni
sha256:cfdf08b7051be381b0f6431df98f2cc552356f2b2c910506e268b1a8bd54bd77 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-gcp-machine-controllers
sha256:764345d2a8222bd915b8850465b1cb33178e511ee941cc3fb9e7ed4a5c6417b5 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-etcd
sha256:d6e9896151e6dfbd89147690d33e1e4a51b12e88931e36701d36d189bb2f4565 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-baremetal-machine-controllers
sha256:f0d65fd2470905ef20dbd20e437c0d9739a14253f173f57157771b47aea455e8 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-azure-machine-controllers
sha256:f9870984bcbff1458d5293338f82caa512acc2b528bfab59c3be9056b42885fc lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-csi-snapshot-controller
sha256:14c419c73c0057ffa754108139ab050f00ab4ca55fb36b057394e6db03bd3e95 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-autoscaler-operator
sha256:47b8c0277caa1619debd9e8cb4fc70d6490bdb79a0a4cc5cb5ca9742a57371c9 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-machine-config-operator
sha256:6594664ba965e195e06a70814e88895b2e92dc4746bdb1ec17b068f082405baf lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-mdns-publisher
sha256:0fe88a64940906bb5e75e4142241dc7589e316aed27970ceeea9cf63fbf8ffcb lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-tests
sha256:e14585f3f272412c4618dcf47b9ec0befbe029ac1eb293d7aaa39e73b22bb475 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-installer-artifacts
sha256:7ea1164981839e136630a160dcaec2bf51a7422da87b342b6462c102cb9e61a5 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-kube-storage-version-migrator-operator
sha256:0fe33064c89a27c191c521813d8988ea0637730f09e9464967d5dce27c1e1e3c lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-node-tuned
sha256:e25caadca2b6afce179820345d99f271304573ca54ad3e27ba20cd2141f72fbb lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-pod
sha256:2c8dc6cc04ec0b3feba4065ad50d4c741c3d914002916a219415c25ab11b115a lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cli
sha256:d424724a427fe2db573c5ac15edd05289e0a9573b7a9b195ae382e05c52deb0b lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-kube-proxy
sha256:cc0cc21371a77bbe9b41b7a5b9acdb04b1903f9f8995d78541ebc4fca27a7d9a lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-openshift-controller-manager
sha256:e0f9b3b61b5bfdc543373de25764958c4c1bbc639501924268c6cf4cd455f53e lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-baremetal-runtimecfg
sha256:d0caedb5ce4fdfe1cdb6bd122ff3e676356fb8be716508c42a00db04126d9c65 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-machine-os-content
sha256:6b20afa0a4ada35061bf34f93795fe6553ccc67edc3ea1f9276709f55a16b311 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-insights-operator
sha256:40cdcce33f8d11350979baf65a2893fb24e3d69c95117917503748aef02adb2b lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-node-tuning-operator
sha256:df9eb3be1abd5bd137c5c417f98339bd35dc315d6776a74fd8dea95a3bbf80af lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-ovirt-machine-controllers
sha256:6a9fe07fe32a4de730689f1b9279e7b9f68688802d2192d2ba7ae42c93d31041 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-console-operator
sha256:bda2450134605bda3c59e1304df18dfc7b13054530d9726e4d7625d5ca19e0a7 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-policy-controller
sha256:69aa7e333ef370d2af67f1159a7638b30dbff6ad934ae7ca64062b67456d5eef lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-csi-snapshot-controller-operator
sha256:fde4ec95a2cca5c8799d6b45212ca2aeedd3c4964c27e6ecb7be78bc93b84bbd lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-docker-registry
sha256:ddc3bdec7cd26e65f3e4139f37a6ff601da9551bdc4daf7fee7b4b7a5bf19cb0 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-operator-registry
sha256:fdc4d591e97819444d69879f57f6507fd1f2b6c481c5d750675e0ef11b1953c7 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-jenkins-agent-nodejs
sha256:9904b89c691bb372e552936b9e7879767323a9d0df1f70d1d1862afec71bd9c4 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-libvirt-machine-controllers
sha256:dd366d2025bf11f9d340cbf6b97bf4243c6c2afcab2a2bfbbb2b1aabdb6d67e0 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-dns-operator
sha256:a47aea1279c42bfa4d6f8f4b692620db6c9888c8670c2b5c3da2cda26277b880 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-kube-state-metrics
sha256:989f64140c18d60fcd6c5cef6baadfdcdfce2740640e9febb287ad648af75210 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-ironic
sha256:0c64e90be82b9c8e12437442dd03d028b2fb3613b574ab6825802618b2ee1c8c lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-prometheus
sha256:38c04fb56229b8227d891f823c716905b45f70322d20c926c4c2f1816c4cb4a4 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-svcat-apiserver-operator
sha256:f432245ebeace22416db322ede2127f3cc1b8e99f64d8dec17007d66b16a7310 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-monitoring-operator
sha256:279eb788fc275b7e5e98da14e6c1be82e8d1f5694981628dd4bca29f68ca79d5 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-network-operator
sha256:04e90a1b165f5a5525238cc66efbba8e4d1575b53e41c1a73bb7c1d072b2c415 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-bootstrap
sha256:5f85eb7824a3246922296dcc41a5f36465424906d8c6d8b865d2e6283f79b3e1 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-operator-marketplace
sha256:31d0fcd6fe9aee3b995589e8f6f38179dd2310dc1c1fbf9bafad5c39ef94d990 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-grafana
sha256:202189109f9eacb36d906faed98419cf491c6cc19f282cd32311480f1c136a46 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-ironic-hardware-inventory-recorder
sha256:90e3d51f5292bb841e97f5074425055dbaac637736d19b3be1f35476a3760958 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-kube-etcd-signer-server
sha256:3e3548f71970f182836075330e34334c92bd2ffb1091520efea64f33778cc76a lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-kube-storage-version-migrator
sha256:5e90332b947a7cbfeebb8bcd468facfc1686280a03868a5c33509e834a44adc9 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-multus-route-override-cni
sha256:fbf1f92674538741c4717cec2da64c1dea267cb1d3c98edeb0fe2ac507302187 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-service-ca-operator
sha256:51549e2ba6f17609621b2f0c469b65abbe9469f83849c88ade0f1a9016253620 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-prometheus-node-exporter
sha256:12f37b7d20231ebcc8c7fe5a96c78f446a913e1509a0e5cf0ca1e75fc536d920 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-update-keys
sha256:830d3f0b1c6d068e0ff0558e53fbedab3e86dc7ab2d40f6d30ad1a6d837fa357 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-deployer
sha256:417ce6b653bbd2b53adc22936fae430abb3da3b6108f469c2cc1580851bdc97e lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-console
sha256:45dcbfa91b3f17e36b631a07d1a2971fc4e27d2bed4e043dd8e52868391ed6a3 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-baremetal-operator
sha256:6ea32f7d002d2c5a761f68227417280c7fbf77db856f379af2d4bac57bd236d9 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-samples-operator
sha256:843a3c9fdea2eb96078e0030b67b8696df847b5b47b151ddeda67dd0155c37a9 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-image-registry-operator
sha256:e2da5b5058fdd98aa5c2cf26bdb094379349fb8501dae2d8c77f891e5fdfe7f6 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-kube-rbac-proxy
sha256:d852eff04adba4a32cb241db4509fcc2dcdc83752699f8e07a8ff5b52ef4ea44 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-k8s-prometheus-adapter
sha256:4cdf6831c9926794a6a260d458579e99d58c68e60a2ac1adfbdb2f61ebfa7185 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cli-artifacts
sha256:6ae6b8b0285e03ca8e67674cb2c0bf0d0aa43305fdd0a43fcadbac71899ec11d lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-ironic-machine-os-downloader
sha256:bf056e6c19bde86dbd42ab3637ef0d5c99ee33aa062b9c352fd4b7168d920e78 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-config-operator
sha256:e9110c2172cca8deec242dceec5f8e3846c28cc8dd7f7c586e5db7deb7740ebe lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-installer
sha256:a1a705b3d44b5b5546d6b96edc4f2e7e25aa47e4d23035df0ecaadb1161b760b lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-prometheus-config-reloader
sha256:94e8f008a2b24b4fe22614d12143ed32e4c255fc0a8cde0b9e9d267754e97c6a lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-hyperkube
sha256:cb6adb576de07ef386f14c4f0d5cd6fd0d6f871e6e508576894c1394da58eda3 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-multus-cni
sha256:aa41dd47ee65b55922f97de0ed5abca86021c461f364ef0ddfabe5a39664f455 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-container-networking-plugins
sha256:77f4e69ccef6321cded24a6bb61faf8196faefe33b56a057ffe7f262030fdd29 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-jenkins
sha256:d34b20bb3302bbd408a46002c47678f5bf613cf6c15966126967e7abd26c49d3 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-haproxy-router
sha256:2a827b677e38178c8c89577443038adc167b68b3dd085ef2f6c1cd74919094bb lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-storage-operator
sha256:8735f072f7a7ff1be26ffa093ae520e0c58dbd541c362c54324c223d24f74f5a lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-ironic-inspector
sha256:dd59894aba7f45baa4b9e31141df00cea389a3a90018d68c4b6801ce0cfa1c7d lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-openshift-apiserver
sha256:531fe6f2038f1e7c824c4356652e390d0e0c44c53d228f46c04c0714006d7d99 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-kube-apiserver-operator
sha256:94b3c2f43b6ffc0a6745a2bd0caa80097fbafa8f27ab867924fe86431bf1e835 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-aws-machine-controllers
sha256:48052dc2fc2190e75d629ce9ad7f348ea295beca1de6c07bd23c0074a59623b4 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cloud-credential-operator
sha256:54202be8771734adc799f5f03607ba351c313e9f9a2dbfcc7d7106ecc97b910d lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-etcd-operator
sha256:f547f507fafcfb0a743672e7ae589f160aa6af0daf39b39ed00b4f967a5328fa lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-ironic-ipa-downloader
sha256:637aebfa978ce3dfd4ddbd3f50119bed3e5eb9b8a6a4b0c0d6c651c516d8de53 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-must-gather
sha256:4e478687ea087d47b88db680e4db07d75af9f55e83a648d28bec82ebf4b876c9 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-service-catalog
sha256:bd9c6cc3542a1e4cb313c4c5ae4af24658f4954072c388428d61dcbcf9ab1ea8 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-openstack-machine-controllers
sha256:b14cbc3d5f2b568df1948d9017efa22b70a6c731387efc73a90c8f5c571b736c lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-ovn-kubernetes
sha256:b8eadbf0b60677ac9faa6eccf7a08ea7680b26d875d96914a038f0b68017cebd lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-local-storage-static-provisioner
sha256:90c7126509197ade3182af767beae4d767fe9d807c3e42fdc11053e22f142c8d lab-installer.baremetal:5000/ocp/release:4.4
sha256:9b6035e757877b64304a1b19d0315d8fe4f220ec2d14d0d10f34d85f03b77fe6 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-multus-whereabouts-ipam-cni
sha256:22edf424aa729ff07e5e4dd380a13e18d227517e5d7d94a084059afba806d027 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-baremetal-installer
sha256:532f6d7205b0477c07e0b5e7c1e97408623d56c71aa8a4302a5fce0458143a1c lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-kube-client-agent
sha256:0bda4615e409ba89fa03d9bf2ae29b8d0a39af9987059cb62a2470858d316693 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-openshift-controller-manager-operator
sha256:a6f71083c0a245a88fc5bdb3f5451df2418c80a2276f19196478fc0b92129f72 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-cluster-autoscaler
sha256:bf6590692745cc32a12779117146e87b672067c361329c6cdaa3bab1a4447004 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-sdn
sha256:309f8d90bbbc7571676a0ac7abead9370908df74fcc4dcc1705261691e9f56d7 lab-installer.baremetal:5000/ocp/release:4.4.0-0.nightly-2020-05-12-084542-prom-label-proxy
info: Mirroring completed in 1m26.36s (67.52MB/s)

Success
Update image:  lab-installer.baremetal:5000/ocp/release:4.4
Mirror prefix: lab-installer.baremetal:5000/ocp/release

To use the new mirrored repository to install, add the following section to the install-config.yaml:

imageContentSources:
- mirrors:
  - lab-installer.baremetal:5000/ocp/release
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
- mirrors:
  - lab-installer.baremetal:5000/ocp/release
  source: registry.svc.ci.openshift.org/ocp/release


To use the new mirrored repository for upgrades, use the following to create an ImageContentSourcePolicy:

apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: example
spec:
  repositoryDigestMirrors:
  - mirrors:
    - lab-installer.baremetal:5000/ocp/release
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
  - mirrors:
    - lab-installer.baremetal:5000/ocp/release
    source: registry.svc.ci.openshift.org/ocp/release
```

This scripts does the following:

- Install podman and openssl.
- Creates SSL certificates.
- Creates a htpasswd file.
- Creates and launches a registry using tls and said htpasswd for authentication.
- Leverages `oc adm release mirror` to fetch Openshift content and push it to our local registry.
- Patches the *install-config.yaml* so that it makes use of our internal registry during deployment. In particular, imagecontentsources and ca as additionalTrustBundle are added to the file.

# Openshift deployment

Now, we can finally launch the deployment!!!

```
/root/07_deploy_openshift.sh
```

Expected Output

```
time="2020-05-12T09:56:03Z" level=debug msg="OpenShift Installer 4.5.0-0.nightly-2020-05-12-065413"
time="2020-05-12T09:56:03Z" level=debug msg="Built from commit e476c483ed99c9cf2982529178e668dbcaf3ed5e"
time="2020-05-12T09:56:03Z" level=debug msg="Fetching Master Machines..."
time="2020-05-12T09:56:03Z" level=debug msg="Loading Master Machines..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="      Loading SSH Key..."
time="2020-05-12T09:56:03Z" level=debug msg="      Loading Base Domain..."
time="2020-05-12T09:56:03Z" level=debug msg="        Loading Platform..."
time="2020-05-12T09:56:03Z" level=debug msg="      Loading Cluster Name..."
time="2020-05-12T09:56:03Z" level=debug msg="        Loading Base Domain..."
time="2020-05-12T09:56:03Z" level=debug msg="        Loading Platform..."
time="2020-05-12T09:56:03Z" level=debug msg="      Loading Pull Secret..."
time="2020-05-12T09:56:03Z" level=debug msg="      Loading Platform..."
time="2020-05-12T09:56:03Z" level=debug msg="    Using Install Config loaded from target directory"
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Platform Credentials Check..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Image..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Master Ignition Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Root CA..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Platform Credentials Check..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Platform Credentials Check..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Image..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Image..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Master Ignition Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Root CA..."
time="2020-05-12T09:56:03Z" level=debug msg="    Generating Root CA..."
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Master Ignition Config..."
time="2020-05-12T09:56:03Z" level=debug msg="Generating Master Machines..."
time="2020-05-12T09:56:03Z" level=info msg="Consuming Install Config from target directory"
time="2020-05-12T09:56:03Z" level=debug msg="Purging asset \"Install Config\" from disk"
time="2020-05-12T09:56:03Z" level=debug msg="Fetching Worker Machines..."
time="2020-05-12T09:56:03Z" level=debug msg="Loading Worker Machines..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Platform Credentials Check..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Image..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Worker Ignition Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Root CA..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="  Reusing previously-fetched Cluster ID"
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Platform Credentials Check..."
time="2020-05-12T09:56:03Z" level=debug msg="  Reusing previously-fetched Platform Credentials Check"
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Image..."
time="2020-05-12T09:56:03Z" level=debug msg="  Reusing previously-fetched Image"
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Worker Ignition Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Root CA..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Root CA"
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Worker Ignition Config..."
time="2020-05-12T09:56:03Z" level=debug msg="Generating Worker Machines..."
time="2020-05-12T09:56:03Z" level=debug msg="Fetching Common Manifests..."
time="2020-05-12T09:56:03Z" level=debug msg="Loading Common Manifests..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Ingress Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading DNS Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Platform Credentials Check..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Infrastructure Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Cloud Provider Config..."
time="2020-05-12T09:56:03Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="      Loading Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="      Loading Platform Credentials Check..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Additional Trust Bundle Config..."
time="2020-05-12T09:56:03Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Network Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Network CRDs..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Proxy Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Network Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Scheduler Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Image Content Source Policy..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Root CA..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Certificate (etcd-signer)..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Certificate (etcd-ca-bundle)..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Certificate (etcd-signer)..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Certificate (etcd-client)..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Certificate (etcd-signer)..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Certificate (etcd-metric-ca-bundle)..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Certificate (etcd-metric-signer-client)..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading Certificate (mcs)..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Root CA..."
time="2020-05-12T09:56:03Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading CVOOverrides..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading EtcdCAConfigMap..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading EtcdClientSecret..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading EtcdHostServiceEndpoints..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading EtcdHostService..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading EtcdMetricClientSecret..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading EtcdMetricServingCAConfigMap..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading EtcdMetricSignerSecret..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading EtcdNamespace..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading EtcdService..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading EtcdSignerSecret..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading KubeCloudConfig..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading EtcdServingCAConfigMap..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading KubeSystemConfigmapRootCA..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading MachineConfigServerTLSSecret..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading OpenshiftConfigSecretPullSecret..."
time="2020-05-12T09:56:03Z" level=debug msg="  Loading OpenshiftMachineConfigOperator..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="  Reusing previously-fetched Cluster ID"
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Ingress Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Ingress Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching DNS Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Cluster ID"
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Platform Credentials Check..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Platform Credentials Check"
time="2020-05-12T09:56:03Z" level=debug msg="  Generating DNS Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Infrastructure Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Cluster ID"
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Cloud Provider Config..."
time="2020-05-12T09:56:03Z" level=debug msg="      Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="      Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="      Fetching Cluster ID..."
time="2020-05-12T09:56:03Z" level=debug msg="      Reusing previously-fetched Cluster ID"
time="2020-05-12T09:56:03Z" level=debug msg="      Fetching Platform Credentials Check..."
time="2020-05-12T09:56:03Z" level=debug msg="      Reusing previously-fetched Platform Credentials Check"
time="2020-05-12T09:56:03Z" level=debug msg="    Generating Cloud Provider Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Additional Trust Bundle Config..."
time="2020-05-12T09:56:03Z" level=debug msg="      Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="      Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="    Generating Additional Trust Bundle Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Infrastructure Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Network Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Network CRDs..."
time="2020-05-12T09:56:03Z" level=debug msg="    Generating Network CRDs..."
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Network Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Proxy Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Network Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Network Config"
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Proxy Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Scheduler Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Scheduler Config..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Image Content Source Policy..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Image Content Source Policy..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Root CA..."
time="2020-05-12T09:56:03Z" level=debug msg="  Reusing previously-fetched Root CA"
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Certificate (etcd-signer)..."
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Certificate (etcd-signer)..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Certificate (etcd-ca-bundle)..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Certificate (etcd-signer)..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Certificate (etcd-signer)"
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Certificate (etcd-ca-bundle)..."
time="2020-05-12T09:56:03Z" level=debug msg="  Fetching Certificate (etcd-client)..."
time="2020-05-12T09:56:03Z" level=debug msg="    Fetching Certificate (etcd-signer)..."
time="2020-05-12T09:56:03Z" level=debug msg="    Reusing previously-fetched Certificate (etcd-signer)"
time="2020-05-12T09:56:03Z" level=debug msg="  Generating Certificate (etcd-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Certificate (etcd-metric-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Fetching Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Generating Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating Certificate (etcd-metric-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="  Reusing previously-fetched Certificate (etcd-metric-signer)"
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Certificate (etcd-metric-signer-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Fetching Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Reusing previously-fetched Certificate (etcd-metric-signer)"
time="2020-05-12T09:56:04Z" level=debug msg="  Generating Certificate (etcd-metric-signer-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Certificate (mcs)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Fetching Root CA..."
time="2020-05-12T09:56:04Z" level=debug msg="    Reusing previously-fetched Root CA"
time="2020-05-12T09:56:04Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:04Z" level=debug msg="  Generating Certificate (mcs)..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching CVOOverrides..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating CVOOverrides..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching EtcdCAConfigMap..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating EtcdCAConfigMap..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching EtcdClientSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating EtcdClientSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching EtcdHostServiceEndpoints..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating EtcdHostServiceEndpoints..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching EtcdHostService..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating EtcdHostService..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching EtcdMetricClientSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating EtcdMetricClientSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching EtcdMetricServingCAConfigMap..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating EtcdMetricServingCAConfigMap..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching EtcdMetricSignerSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating EtcdMetricSignerSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching EtcdNamespace..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating EtcdNamespace..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching EtcdService..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating EtcdService..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching EtcdSignerSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating EtcdSignerSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching KubeCloudConfig..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating KubeCloudConfig..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching EtcdServingCAConfigMap..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating EtcdServingCAConfigMap..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching KubeSystemConfigmapRootCA..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating KubeSystemConfigmapRootCA..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching MachineConfigServerTLSSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating MachineConfigServerTLSSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching OpenshiftConfigSecretPullSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating OpenshiftConfigSecretPullSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching OpenshiftMachineConfigOperator..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating OpenshiftMachineConfigOperator..."
time="2020-05-12T09:56:04Z" level=debug msg="Generating Common Manifests..."
time="2020-05-12T09:56:04Z" level=debug msg="Fetching Openshift Manifests..."
time="2020-05-12T09:56:04Z" level=debug msg="Loading Openshift Manifests..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Kubeadmin Password..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading OpenShift Install (Manifests)..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading CloudCredsSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading KubeadminPasswordSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading RoleCloudCredsSecretReader..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Private Cluster Outbound Service..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Baremetal Config CR..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Image..."
time="2020-05-12T09:56:04Z" level=warning msg="Discarding the Openshift Manifests that was provided in the target directory because its dependencies are dirty and it needs to be regenerated"
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="  Reusing previously-fetched Install Config"
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="  Reusing previously-fetched Cluster ID"
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Kubeadmin Password..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating Kubeadmin Password..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching OpenShift Install (Manifests)..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating OpenShift Install (Manifests)..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching CloudCredsSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating CloudCredsSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching KubeadminPasswordSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating KubeadminPasswordSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching RoleCloudCredsSecretReader..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating RoleCloudCredsSecretReader..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Private Cluster Outbound Service..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating Private Cluster Outbound Service..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Baremetal Config CR..."
time="2020-05-12T09:56:04Z" level=debug msg="  Generating Baremetal Config CR..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Image..."
time="2020-05-12T09:56:04Z" level=debug msg="  Reusing previously-fetched Image"
time="2020-05-12T09:56:04Z" level=debug msg="Generating Openshift Manifests..."
time="2020-05-12T09:56:04Z" level=debug msg="OpenShift Installer 4.5.0-0.nightly-2020-05-12-065413"
time="2020-05-12T09:56:04Z" level=debug msg="Built from commit e476c483ed99c9cf2982529178e668dbcaf3ed5e"
time="2020-05-12T09:56:04Z" level=debug msg="Fetching Metadata..."
time="2020-05-12T09:56:04Z" level=debug msg="Loading Metadata..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading SSH Key..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Base Domain..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Platform..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Cluster Name..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Base Domain..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Platform..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Pull Secret..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Platform..."
time="2020-05-12T09:56:04Z" level=debug msg="    Using Install Config loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="  Using Cluster ID loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="  Reusing previously-fetched Cluster ID"
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="  Reusing previously-fetched Install Config"
time="2020-05-12T09:56:04Z" level=debug msg="Generating Metadata..."
time="2020-05-12T09:56:04Z" level=debug msg="Fetching Terraform Variables..."
time="2020-05-12T09:56:04Z" level=debug msg="Loading Terraform Variables..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Image..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="  Using Image loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="  Loading BootstrapImage..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Bootstrap Ignition Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Kubeconfig Admin Internal Client..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (admin-kubeconfig-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (admin-kubeconfig-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-apiserver-complete-server-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (kube-apiserver-localhost-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="          Loading Certificate (kube-apiserver-localhost-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (kube-apiserver-service-network-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="          Loading Certificate (kube-apiserver-service-network-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (kube-apiserver-lb-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="          Loading Certificate (kube-apiserver-lb-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Kubeconfig Kubelet..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-apiserver-complete-server-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kubelet-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (kubelet-bootstrap-kubeconfig-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Kubeconfig Admin Client (Loopback)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (admin-kubeconfig-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-apiserver-localhost-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Master Machines..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Platform Credentials Check..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Platform Credentials Check loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Image..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Master Ignition Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Root CA..."
time="2020-05-12T09:56:04Z" level=debug msg="        Using Root CA loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Using Master Ignition Config loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Master Machines from both state file and target directory"
time="2020-05-12T09:56:04Z" level=debug msg="    Using Master Machines loaded from target directory"
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Worker Machines..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Platform Credentials Check..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Image..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Worker Ignition Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Root CA..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Worker Ignition Config loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Worker Machines from both state file and target directory"
time="2020-05-12T09:56:04Z" level=debug msg="    Using Worker Machines loaded from target directory"
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Common Manifests..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Ingress Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Ingress Config loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading DNS Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Platform Credentials Check..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using DNS Config loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Infrastructure Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Cloud Provider Config..."
time="2020-05-12T09:56:04Z" level=debug msg="          Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="          Loading Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="          Loading Platform Credentials Check..."
time="2020-05-12T09:56:04Z" level=debug msg="        Using Cloud Provider Config loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Additional Trust Bundle Config..."
time="2020-05-12T09:56:04Z" level=debug msg="          Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Using Additional Trust Bundle Config loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Using Infrastructure Config loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Network Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Network CRDs..."
time="2020-05-12T09:56:04Z" level=debug msg="        Using Network CRDs loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Using Network Config loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Proxy Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Network Config..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Proxy Config loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Scheduler Config..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Scheduler Config loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Image Content Source Policy..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Image Content Source Policy loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Root CA..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (etcd-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Certificate (etcd-signer) loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (etcd-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (etcd-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Certificate (etcd-ca-bundle) loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (etcd-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (etcd-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Certificate (etcd-client) loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (etcd-metric-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Using Certificate (etcd-metric-signer) loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Using Certificate (etcd-metric-ca-bundle) loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (etcd-metric-signer-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Certificate (etcd-metric-signer-client) loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (mcs)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Root CA..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Certificate (mcs) loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading CVOOverrides..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using CVOOverrides loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading EtcdCAConfigMap..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using EtcdCAConfigMap loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading EtcdClientSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using EtcdClientSecret loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading EtcdHostServiceEndpoints..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using EtcdHostServiceEndpoints loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading EtcdHostService..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using EtcdHostService loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading EtcdMetricClientSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using EtcdMetricClientSecret loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading EtcdMetricServingCAConfigMap..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using EtcdMetricServingCAConfigMap loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading EtcdMetricSignerSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using EtcdMetricSignerSecret loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading EtcdNamespace..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using EtcdNamespace loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading EtcdService..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using EtcdService loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading EtcdSignerSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using EtcdSignerSecret loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading KubeCloudConfig..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using KubeCloudConfig loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading EtcdServingCAConfigMap..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using EtcdServingCAConfigMap loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading KubeSystemConfigmapRootCA..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using KubeSystemConfigmapRootCA loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading MachineConfigServerTLSSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using MachineConfigServerTLSSecret loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading OpenshiftConfigSecretPullSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using OpenshiftConfigSecretPullSecret loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading OpenshiftMachineConfigOperator..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using OpenshiftMachineConfigOperator loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Common Manifests from both state file and target directory"
time="2020-05-12T09:56:04Z" level=debug msg="    On-disk Common Manifests matches asset in state file"
time="2020-05-12T09:56:04Z" level=debug msg="    Using Common Manifests loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Openshift Manifests..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Kubeadmin Password..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Kubeadmin Password loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading OpenShift Install (Manifests)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading OpenShift Install (Manifests) from both state file and target directory"
time="2020-05-12T09:56:04Z" level=debug msg="      On-disk OpenShift Install (Manifests) matches asset in state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Using OpenShift Install (Manifests) loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading CloudCredsSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using CloudCredsSecret loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading KubeadminPasswordSecret..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using KubeadminPasswordSecret loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading RoleCloudCredsSecretReader..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using RoleCloudCredsSecretReader loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Private Cluster Outbound Service..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Private Cluster Outbound Service loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Baremetal Config CR..."
time="2020-05-12T09:56:04Z" level=debug msg="      Using Baremetal Config CR loaded from state file"
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Image..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Openshift Manifests from both state file and target directory"
time="2020-05-12T09:56:04Z" level=debug msg="    Using Openshift Manifests loaded from target directory"
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Proxy Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (admin-kubeconfig-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (admin-kubeconfig-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (aggregator)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (aggregator-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (aggregator-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (system:kube-apiserver-proxy)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (aggregator-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (aggregator-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (system:kube-apiserver-proxy)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (aggregator)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Bootstrap SSH Key Pair..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (etcd-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (etcd-metric-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (etcd-metric-signer-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (etcd-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (etcd-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (journal-gatewayd)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Root CA..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-lb-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-external-lb-server)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-apiserver-lb-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-internal-lb-server)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-apiserver-lb-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-lb-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-localhost-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-localhost-server)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-apiserver-localhost-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-localhost-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-service-network-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-service-network-server)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-apiserver-service-network-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-service-network-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-complete-server-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-complete-client-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (admin-kubeconfig-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kubelet-client-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (kubelet-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-control-plane-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (kube-control-plane-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (kube-apiserver-lb-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (kube-apiserver-localhost-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (kube-apiserver-service-network-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-apiserver-to-kubelet-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (kube-apiserver-to-kubelet-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kubelet-bootstrap-kubeconfig-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Loading Certificate (kubelet-bootstrap-kubeconfig-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-to-kubelet-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-to-kubelet-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-apiserver-to-kubelet-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-apiserver-to-kubelet-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-control-plane-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-control-plane-kube-controller-manager-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-control-plane-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-control-plane-kube-scheduler-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kube-control-plane-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kube-control-plane-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kubelet-bootstrap-kubeconfig-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kubelet-client-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kubelet-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kubelet-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (kubelet-serving-ca-bundle)..."
time="2020-05-12T09:56:04Z" level=debug msg="      Loading Certificate (kubelet-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Certificate (mcs)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Root CA..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Key Pair (service-account.pub)..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Release Image Pull Spec..."
time="2020-05-12T09:56:04Z" level=debug msg="    Loading Image..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Master Ignition Config..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Master Machines..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Worker Machines..."
time="2020-05-12T09:56:04Z" level=debug msg="  Loading Root CA..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Cluster ID..."
time="2020-05-12T09:56:04Z" level=debug msg="  Reusing previously-fetched Cluster ID"
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="  Reusing previously-fetched Install Config"
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Image..."
time="2020-05-12T09:56:04Z" level=debug msg="  Reusing previously-fetched Image"
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching BootstrapImage..."
time="2020-05-12T09:56:04Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:04Z" level=debug msg="  Generating BootstrapImage..."
time="2020-05-12T09:56:04Z" level=debug msg="  Fetching Bootstrap Ignition Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:04Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:04Z" level=debug msg="    Fetching Kubeconfig Admin Internal Client..."
time="2020-05-12T09:56:04Z" level=debug msg="      Fetching Certificate (admin-kubeconfig-client)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Fetching Certificate (admin-kubeconfig-signer)..."
time="2020-05-12T09:56:04Z" level=debug msg="        Generating Certificate (admin-kubeconfig-signer)..."
time="2020-05-12T09:56:05Z" level=debug msg="      Generating Certificate (admin-kubeconfig-client)..."
time="2020-05-12T09:56:05Z" level=debug msg="      Fetching Certificate (kube-apiserver-complete-server-ca-bundle)..."
time="2020-05-12T09:56:05Z" level=debug msg="        Fetching Certificate (kube-apiserver-localhost-ca-bundle)..."
time="2020-05-12T09:56:05Z" level=debug msg="          Fetching Certificate (kube-apiserver-localhost-signer)..."
time="2020-05-12T09:56:05Z" level=debug msg="          Generating Certificate (kube-apiserver-localhost-signer)..."
time="2020-05-12T09:56:05Z" level=debug msg="        Generating Certificate (kube-apiserver-localhost-ca-bundle)..."
time="2020-05-12T09:56:05Z" level=debug msg="        Fetching Certificate (kube-apiserver-service-network-ca-bundle)..."
time="2020-05-12T09:56:05Z" level=debug msg="          Fetching Certificate (kube-apiserver-service-network-signer)..."
time="2020-05-12T09:56:05Z" level=debug msg="          Generating Certificate (kube-apiserver-service-network-signer)..."
time="2020-05-12T09:56:05Z" level=debug msg="        Generating Certificate (kube-apiserver-service-network-ca-bundle)..."
time="2020-05-12T09:56:05Z" level=debug msg="        Fetching Certificate (kube-apiserver-lb-ca-bundle)..."
time="2020-05-12T09:56:05Z" level=debug msg="          Fetching Certificate (kube-apiserver-lb-signer)..."
time="2020-05-12T09:56:05Z" level=debug msg="          Generating Certificate (kube-apiserver-lb-signer)..."
time="2020-05-12T09:56:05Z" level=debug msg="        Generating Certificate (kube-apiserver-lb-ca-bundle)..."
time="2020-05-12T09:56:05Z" level=debug msg="      Generating Certificate (kube-apiserver-complete-server-ca-bundle)..."
time="2020-05-12T09:56:05Z" level=debug msg="      Fetching Install Config..."
time="2020-05-12T09:56:05Z" level=debug msg="      Reusing previously-fetched Install Config"
time="2020-05-12T09:56:05Z" level=debug msg="    Generating Kubeconfig Admin Internal Client..."
time="2020-05-12T09:56:05Z" level=debug msg="    Fetching Kubeconfig Kubelet..."
time="2020-05-12T09:56:05Z" level=debug msg="      Fetching Certificate (kube-apiserver-complete-server-ca-bundle)..."
time="2020-05-12T09:56:05Z" level=debug msg="      Reusing previously-fetched Certificate (kube-apiserver-complete-server-ca-bundle)"
time="2020-05-12T09:56:05Z" level=debug msg="      Fetching Certificate (kubelet-client)..."
time="2020-05-12T09:56:05Z" level=debug msg="        Fetching Certificate (kubelet-bootstrap-kubeconfig-signer)..."
time="2020-05-12T09:56:05Z" level=debug msg="        Generating Certificate (kubelet-bootstrap-kubeconfig-signer)..."
time="2020-05-12T09:56:05Z" level=debug msg="      Generating Certificate (kubelet-client)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Fetching Install Config..."
time="2020-05-12T09:56:06Z" level=debug msg="      Reusing previously-fetched Install Config"
time="2020-05-12T09:56:06Z" level=debug msg="    Generating Kubeconfig Kubelet..."
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Kubeconfig Admin Client (Loopback)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Fetching Certificate (admin-kubeconfig-client)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Reusing previously-fetched Certificate (admin-kubeconfig-client)"
time="2020-05-12T09:56:06Z" level=debug msg="      Fetching Certificate (kube-apiserver-localhost-ca-bundle)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Reusing previously-fetched Certificate (kube-apiserver-localhost-ca-bundle)"
time="2020-05-12T09:56:06Z" level=debug msg="      Fetching Install Config..."
time="2020-05-12T09:56:06Z" level=debug msg="      Reusing previously-fetched Install Config"
time="2020-05-12T09:56:06Z" level=debug msg="    Generating Kubeconfig Admin Client (Loopback)..."
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Master Machines..."
time="2020-05-12T09:56:06Z" level=debug msg="    Reusing previously-fetched Master Machines"
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Worker Machines..."
time="2020-05-12T09:56:06Z" level=debug msg="    Reusing previously-fetched Worker Machines"
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Common Manifests..."
time="2020-05-12T09:56:06Z" level=debug msg="    Reusing previously-fetched Common Manifests"
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Openshift Manifests..."
time="2020-05-12T09:56:06Z" level=debug msg="    Reusing previously-fetched Openshift Manifests"
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Proxy Config..."
time="2020-05-12T09:56:06Z" level=debug msg="    Reusing previously-fetched Proxy Config"
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Certificate (admin-kubeconfig-ca-bundle)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Fetching Certificate (admin-kubeconfig-signer)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Reusing previously-fetched Certificate (admin-kubeconfig-signer)"
time="2020-05-12T09:56:06Z" level=debug msg="    Generating Certificate (admin-kubeconfig-ca-bundle)..."
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Certificate (aggregator)..."
time="2020-05-12T09:56:06Z" level=debug msg="    Generating Certificate (aggregator)..."
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Certificate (aggregator-ca-bundle)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Fetching Certificate (aggregator-signer)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Generating Certificate (aggregator-signer)..."
time="2020-05-12T09:56:06Z" level=debug msg="    Generating Certificate (aggregator-ca-bundle)..."
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Certificate (system:kube-apiserver-proxy)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Fetching Certificate (aggregator-signer)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Reusing previously-fetched Certificate (aggregator-signer)"
time="2020-05-12T09:56:06Z" level=debug msg="    Generating Certificate (system:kube-apiserver-proxy)..."
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Certificate (aggregator-signer)..."
time="2020-05-12T09:56:06Z" level=debug msg="    Reusing previously-fetched Certificate (aggregator-signer)"
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Certificate (system:kube-apiserver-proxy)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Fetching Certificate (aggregator)..."
time="2020-05-12T09:56:06Z" level=debug msg="      Reusing previously-fetched Certificate (aggregator)"
time="2020-05-12T09:56:06Z" level=debug msg="    Generating Certificate (system:kube-apiserver-proxy)..."
time="2020-05-12T09:56:06Z" level=debug msg="    Fetching Bootstrap SSH Key Pair..."
time="2020-05-12T09:56:06Z" level=debug msg="    Generating Bootstrap SSH Key Pair..."
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (etcd-ca-bundle)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (etcd-ca-bundle)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (etcd-metric-ca-bundle)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (etcd-metric-ca-bundle)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (etcd-metric-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (etcd-metric-signer)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (etcd-metric-signer-client)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (etcd-metric-signer-client)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (etcd-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (etcd-signer)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (etcd-client)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (etcd-client)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (journal-gatewayd)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Fetching Root CA..."
time="2020-05-12T09:56:07Z" level=debug msg="      Reusing previously-fetched Root CA"
time="2020-05-12T09:56:07Z" level=debug msg="    Generating Certificate (journal-gatewayd)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-lb-ca-bundle)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (kube-apiserver-lb-ca-bundle)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-external-lb-server)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Fetching Certificate (kube-apiserver-lb-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Reusing previously-fetched Certificate (kube-apiserver-lb-signer)"
time="2020-05-12T09:56:07Z" level=debug msg="      Fetching Install Config..."
time="2020-05-12T09:56:07Z" level=debug msg="      Reusing previously-fetched Install Config"
time="2020-05-12T09:56:07Z" level=debug msg="    Generating Certificate (kube-apiserver-external-lb-server)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-internal-lb-server)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Fetching Certificate (kube-apiserver-lb-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Reusing previously-fetched Certificate (kube-apiserver-lb-signer)"
time="2020-05-12T09:56:07Z" level=debug msg="      Fetching Install Config..."
time="2020-05-12T09:56:07Z" level=debug msg="      Reusing previously-fetched Install Config"
time="2020-05-12T09:56:07Z" level=debug msg="    Generating Certificate (kube-apiserver-internal-lb-server)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-lb-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (kube-apiserver-lb-signer)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-localhost-ca-bundle)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (kube-apiserver-localhost-ca-bundle)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-localhost-server)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Fetching Certificate (kube-apiserver-localhost-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Reusing previously-fetched Certificate (kube-apiserver-localhost-signer)"
time="2020-05-12T09:56:07Z" level=debug msg="    Generating Certificate (kube-apiserver-localhost-server)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-localhost-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (kube-apiserver-localhost-signer)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-service-network-ca-bundle)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (kube-apiserver-service-network-ca-bundle)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-service-network-server)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Fetching Certificate (kube-apiserver-service-network-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Reusing previously-fetched Certificate (kube-apiserver-service-network-signer)"
time="2020-05-12T09:56:07Z" level=debug msg="      Fetching Install Config..."
time="2020-05-12T09:56:07Z" level=debug msg="      Reusing previously-fetched Install Config"
time="2020-05-12T09:56:07Z" level=debug msg="    Generating Certificate (kube-apiserver-service-network-server)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-service-network-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (kube-apiserver-service-network-signer)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-complete-server-ca-bundle)..."
time="2020-05-12T09:56:07Z" level=debug msg="    Reusing previously-fetched Certificate (kube-apiserver-complete-server-ca-bundle)"
time="2020-05-12T09:56:07Z" level=debug msg="    Fetching Certificate (kube-apiserver-complete-client-ca-bundle)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Fetching Certificate (admin-kubeconfig-ca-bundle)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Reusing previously-fetched Certificate (admin-kubeconfig-ca-bundle)"
time="2020-05-12T09:56:07Z" level=debug msg="      Fetching Certificate (kubelet-client-ca-bundle)..."
time="2020-05-12T09:56:07Z" level=debug msg="        Fetching Certificate (kubelet-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="        Generating Certificate (kubelet-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Generating Certificate (kubelet-client-ca-bundle)..."
time="2020-05-12T09:56:07Z" level=debug msg="      Fetching Certificate (kube-control-plane-ca-bundle)..."
time="2020-05-12T09:56:07Z" level=debug msg="        Fetching Certificate (kube-control-plane-signer)..."
time="2020-05-12T09:56:07Z" level=debug msg="        Generating Certificate (kube-control-plane-signer)..."
time="2020-05-12T09:56:08Z" level=debug msg="        Fetching Certificate (kube-apiserver-lb-signer)..."
time="2020-05-12T09:56:08Z" level=debug msg="        Reusing previously-fetched Certificate (kube-apiserver-lb-signer)"
time="2020-05-12T09:56:08Z" level=debug msg="        Fetching Certificate (kube-apiserver-localhost-signer)..."
time="2020-05-12T09:56:08Z" level=debug msg="        Reusing previously-fetched Certificate (kube-apiserver-localhost-signer)"
time="2020-05-12T09:56:08Z" level=debug msg="        Fetching Certificate (kube-apiserver-service-network-signer)..."
time="2020-05-12T09:56:08Z" level=debug msg="        Reusing previously-fetched Certificate (kube-apiserver-service-network-signer)"
time="2020-05-12T09:56:08Z" level=debug msg="      Generating Certificate (kube-control-plane-ca-bundle)..."
time="2020-05-12T09:56:08Z" level=debug msg="      Fetching Certificate (kube-apiserver-to-kubelet-ca-bundle)..."
time="2020-05-12T09:56:08Z" level=debug msg="        Fetching Certificate (kube-apiserver-to-kubelet-signer)..."
time="2020-05-12T09:56:08Z" level=debug msg="        Generating Certificate (kube-apiserver-to-kubelet-signer)..."
time="2020-05-12T09:56:08Z" level=debug msg="      Generating Certificate (kube-apiserver-to-kubelet-ca-bundle)..."
time="2020-05-12T09:56:08Z" level=debug msg="      Fetching Certificate (kubelet-bootstrap-kubeconfig-ca-bundle)..."
time="2020-05-12T09:56:08Z" level=debug msg="        Fetching Certificate (kubelet-bootstrap-kubeconfig-signer)..."
time="2020-05-12T09:56:08Z" level=debug msg="        Reusing previously-fetched Certificate (kubelet-bootstrap-kubeconfig-signer)"
time="2020-05-12T09:56:08Z" level=debug msg="      Generating Certificate (kubelet-bootstrap-kubeconfig-ca-bundle)..."
time="2020-05-12T09:56:08Z" level=debug msg="    Generating Certificate (kube-apiserver-complete-client-ca-bundle)..."
time="2020-05-12T09:56:08Z" level=debug msg="    Fetching Certificate (kube-apiserver-to-kubelet-ca-bundle)..."
time="2020-05-12T09:56:08Z" level=debug msg="    Reusing previously-fetched Certificate (kube-apiserver-to-kubelet-ca-bundle)"
time="2020-05-12T09:56:08Z" level=debug msg="    Fetching Certificate (kube-apiserver-to-kubelet-client)..."
time="2020-05-12T09:56:08Z" level=debug msg="      Fetching Certificate (kube-apiserver-to-kubelet-signer)..."
time="2020-05-12T09:56:08Z" level=debug msg="      Reusing previously-fetched Certificate (kube-apiserver-to-kubelet-signer)"
time="2020-05-12T09:56:08Z" level=debug msg="    Generating Certificate (kube-apiserver-to-kubelet-client)..."
time="2020-05-12T09:56:08Z" level=debug msg="    Fetching Certificate (kube-apiserver-to-kubelet-signer)..."
time="2020-05-12T09:56:08Z" level=debug msg="    Reusing previously-fetched Certificate (kube-apiserver-to-kubelet-signer)"
time="2020-05-12T09:56:08Z" level=debug msg="    Fetching Certificate (kube-control-plane-ca-bundle)..."
time="2020-05-12T09:56:08Z" level=debug msg="    Reusing previously-fetched Certificate (kube-control-plane-ca-bundle)"
time="2020-05-12T09:56:08Z" level=debug msg="    Fetching Certificate (kube-control-plane-kube-controller-manager-client)..."
time="2020-05-12T09:56:08Z" level=debug msg="      Fetching Certificate (kube-control-plane-signer)..."
time="2020-05-12T09:56:08Z" level=debug msg="      Reusing previously-fetched Certificate (kube-control-plane-signer)"
time="2020-05-12T09:56:08Z" level=debug msg="    Generating Certificate (kube-control-plane-kube-controller-manager-client)..."
time="2020-05-12T09:56:08Z" level=debug msg="    Fetching Certificate (kube-control-plane-kube-scheduler-client)..."
time="2020-05-12T09:56:08Z" level=debug msg="      Fetching Certificate (kube-control-plane-signer)..."
time="2020-05-12T09:56:08Z" level=debug msg="      Reusing previously-fetched Certificate (kube-control-plane-signer)"
time="2020-05-12T09:56:08Z" level=debug msg="    Generating Certificate (kube-control-plane-kube-scheduler-client)..."
time="2020-05-12T09:56:09Z" level=debug msg="    Fetching Certificate (kube-control-plane-signer)..."
time="2020-05-12T09:56:09Z" level=debug msg="    Reusing previously-fetched Certificate (kube-control-plane-signer)"
time="2020-05-12T09:56:09Z" level=debug msg="    Fetching Certificate (kubelet-bootstrap-kubeconfig-ca-bundle)..."
time="2020-05-12T09:56:09Z" level=debug msg="    Reusing previously-fetched Certificate (kubelet-bootstrap-kubeconfig-ca-bundle)"
time="2020-05-12T09:56:09Z" level=debug msg="    Fetching Certificate (kubelet-client-ca-bundle)..."
time="2020-05-12T09:56:09Z" level=debug msg="    Reusing previously-fetched Certificate (kubelet-client-ca-bundle)"
time="2020-05-12T09:56:09Z" level=debug msg="    Fetching Certificate (kubelet-client)..."
time="2020-05-12T09:56:09Z" level=debug msg="    Reusing previously-fetched Certificate (kubelet-client)"
time="2020-05-12T09:56:09Z" level=debug msg="    Fetching Certificate (kubelet-signer)..."
time="2020-05-12T09:56:09Z" level=debug msg="    Reusing previously-fetched Certificate (kubelet-signer)"
time="2020-05-12T09:56:09Z" level=debug msg="    Fetching Certificate (kubelet-serving-ca-bundle)..."
time="2020-05-12T09:56:09Z" level=debug msg="      Fetching Certificate (kubelet-signer)..."
time="2020-05-12T09:56:09Z" level=debug msg="      Reusing previously-fetched Certificate (kubelet-signer)"
time="2020-05-12T09:56:09Z" level=debug msg="    Generating Certificate (kubelet-serving-ca-bundle)..."
time="2020-05-12T09:56:09Z" level=debug msg="    Fetching Certificate (mcs)..."
time="2020-05-12T09:56:09Z" level=debug msg="    Reusing previously-fetched Certificate (mcs)"
time="2020-05-12T09:56:09Z" level=debug msg="    Fetching Root CA..."
time="2020-05-12T09:56:09Z" level=debug msg="    Reusing previously-fetched Root CA"
time="2020-05-12T09:56:09Z" level=debug msg="    Fetching Key Pair (service-account.pub)..."
time="2020-05-12T09:56:09Z" level=debug msg="    Generating Key Pair (service-account.pub)..."
time="2020-05-12T09:56:09Z" level=debug msg="    Fetching Release Image Pull Spec..."
time="2020-05-12T09:56:09Z" level=debug msg="    Generating Release Image Pull Spec..."
time="2020-05-12T09:56:09Z" level=warning msg="Found override for release image. Please be warned, this is not advised"
time="2020-05-12T09:56:09Z" level=debug msg="    Fetching Image..."
time="2020-05-12T09:56:09Z" level=debug msg="    Reusing previously-fetched Image"
time="2020-05-12T09:56:09Z" level=debug msg="  Generating Bootstrap Ignition Config..."
time="2020-05-12T09:56:09Z" level=debug msg="  Fetching Master Ignition Config..."
time="2020-05-12T09:56:09Z" level=debug msg="  Reusing previously-fetched Master Ignition Config"
time="2020-05-12T09:56:09Z" level=debug msg="  Fetching Master Machines..."
time="2020-05-12T09:56:09Z" level=debug msg="  Reusing previously-fetched Master Machines"
time="2020-05-12T09:56:09Z" level=debug msg="  Fetching Worker Machines..."
time="2020-05-12T09:56:09Z" level=debug msg="  Reusing previously-fetched Worker Machines"
time="2020-05-12T09:56:09Z" level=debug msg="  Fetching Root CA..."
time="2020-05-12T09:56:09Z" level=debug msg="  Reusing previously-fetched Root CA"
time="2020-05-12T09:56:09Z" level=debug msg="Generating Terraform Variables..."
time="2020-05-12T09:56:09Z" level=info msg="Obtaining RHCOS image file from 'http://192.168.122.26/rhcos-44.81.202004250133-0-qemu.x86_64.qcow2.gz?sha256=7d884b46ee54fe87bbc3893bf2aa99af3b2d31f2e19ab5529c60636fbd0f1ce7'"
time="2020-05-12T09:56:09Z" level=debug msg="Unpacking file into \"/root/.cache/openshift-installer/image_cache/d5ddd7f0ec77d5c721724b55def2192c\"..."
time="2020-05-12T09:56:09Z" level=debug msg="decompressing the image archive as gz"
time="2020-05-12T09:56:34Z" level=debug msg="Checksum validation is complete..."
time="2020-05-12T09:56:35Z" level=info msg="Consuming Common Manifests from target directory"
time="2020-05-12T09:56:35Z" level=debug msg="Purging asset \"Common Manifests\" from disk"
time="2020-05-12T09:56:35Z" level=info msg="Consuming Worker Machines from target directory"
time="2020-05-12T09:56:35Z" level=debug msg="Purging asset \"Worker Machines\" from disk"
time="2020-05-12T09:56:35Z" level=info msg="Consuming OpenShift Install (Manifests) from target directory"
time="2020-05-12T09:56:35Z" level=debug msg="Purging asset \"OpenShift Install (Manifests)\" from disk"
time="2020-05-12T09:56:35Z" level=info msg="Consuming Openshift Manifests from target directory"
time="2020-05-12T09:56:35Z" level=debug msg="Purging asset \"Openshift Manifests\" from disk"
time="2020-05-12T09:56:35Z" level=info msg="Consuming Master Machines from target directory"
time="2020-05-12T09:56:35Z" level=debug msg="Purging asset \"Master Machines\" from disk"
time="2020-05-12T09:56:35Z" level=debug msg="Fetching Kubeconfig Admin Client..."
time="2020-05-12T09:56:35Z" level=debug msg="Loading Kubeconfig Admin Client..."
time="2020-05-12T09:56:35Z" level=debug msg="  Loading Certificate (admin-kubeconfig-client)..."
time="2020-05-12T09:56:35Z" level=debug msg="  Loading Certificate (kube-apiserver-complete-server-ca-bundle)..."
time="2020-05-12T09:56:35Z" level=debug msg="  Loading Install Config..."
time="2020-05-12T09:56:35Z" level=debug msg="  Fetching Certificate (admin-kubeconfig-client)..."
time="2020-05-12T09:56:35Z" level=debug msg="  Reusing previously-fetched Certificate (admin-kubeconfig-client)"
time="2020-05-12T09:56:35Z" level=debug msg="  Fetching Certificate (kube-apiserver-complete-server-ca-bundle)..."
time="2020-05-12T09:56:35Z" level=debug msg="  Reusing previously-fetched Certificate (kube-apiserver-complete-server-ca-bundle)"
time="2020-05-12T09:56:35Z" level=debug msg="  Fetching Install Config..."
time="2020-05-12T09:56:35Z" level=debug msg="  Reusing previously-fetched Install Config"
time="2020-05-12T09:56:35Z" level=debug msg="Generating Kubeconfig Admin Client..."
time="2020-05-12T09:56:35Z" level=debug msg="Fetching Kubeadmin Password..."
time="2020-05-12T09:56:35Z" level=debug msg="Reusing previously-fetched Kubeadmin Password"
time="2020-05-12T09:56:35Z" level=debug msg="Fetching Certificate (journal-gatewayd)..."
time="2020-05-12T09:56:35Z" level=debug msg="Reusing previously-fetched Certificate (journal-gatewayd)"
time="2020-05-12T09:56:35Z" level=debug msg="Fetching Cluster..."
time="2020-05-12T09:56:35Z" level=debug msg="Loading Cluster..."
time="2020-05-12T09:56:35Z" level=debug msg="  Loading Cluster ID..."
time="2020-05-12T09:56:35Z" level=debug msg="  Loading Install Config..."
time="2020-05-12T09:56:35Z" level=debug msg="  Loading Platform Credentials Check..."
time="2020-05-12T09:56:35Z" level=debug msg="  Loading Platform Permissions Check..."
time="2020-05-12T09:56:35Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:35Z" level=debug msg="  Loading Platform Provisioning Check..."
time="2020-05-12T09:56:35Z" level=debug msg="    Loading Install Config..."
time="2020-05-12T09:56:35Z" level=debug msg="  Loading Terraform Variables..."
time="2020-05-12T09:56:35Z" level=debug msg="  Loading Kubeadmin Password..."
time="2020-05-12T09:56:35Z" level=debug msg="  Fetching Cluster ID..."
time="2020-05-12T09:56:35Z" level=debug msg="  Reusing previously-fetched Cluster ID"
time="2020-05-12T09:56:35Z" level=debug msg="  Fetching Install Config..."
time="2020-05-12T09:56:35Z" level=debug msg="  Reusing previously-fetched Install Config"
time="2020-05-12T09:56:35Z" level=debug msg="  Fetching Platform Credentials Check..."
time="2020-05-12T09:56:35Z" level=debug msg="  Reusing previously-fetched Platform Credentials Check"
time="2020-05-12T09:56:35Z" level=debug msg="  Fetching Platform Permissions Check..."
time="2020-05-12T09:56:35Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:35Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:35Z" level=debug msg="  Generating Platform Permissions Check..."
time="2020-05-12T09:56:35Z" level=debug msg="  Fetching Platform Provisioning Check..."
time="2020-05-12T09:56:35Z" level=debug msg="    Fetching Install Config..."
time="2020-05-12T09:56:35Z" level=debug msg="    Reusing previously-fetched Install Config"
time="2020-05-12T09:56:35Z" level=debug msg="  Generating Platform Provisioning Check..."
time="2020-05-12T09:56:35Z" level=debug msg="  Fetching Terraform Variables..."
time="2020-05-12T09:56:35Z" level=debug msg="  Reusing previously-fetched Terraform Variables"
time="2020-05-12T09:56:35Z" level=debug msg="  Fetching Kubeadmin Password..."
time="2020-05-12T09:56:35Z" level=debug msg="  Reusing previously-fetched Kubeadmin Password"
time="2020-05-12T09:56:35Z" level=debug msg="Generating Cluster..."
time="2020-05-12T09:56:35Z" level=info msg="Creating infrastructure resources..."
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-random src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-random\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-vsphereprivate src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-vsphereprivate\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-ignition src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-ignition\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-local src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-local\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-ovirt src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-ovirt\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-google src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-google\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-ironic src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-ironic\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-libvirt src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-libvirt\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-openstack src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-openstack\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-vsphere src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-vsphere\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-aws src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-aws\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-azurerm src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-azurerm\""
time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-azureprivatedns src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-azureprivatedns\""
time="2020-05-12T09:56:35Z" level=debug msg="Initializing modules..."
time="2020-05-12T09:56:35Z" level=debug msg="- bootstrap in ../tmp/openshift-install-407594662/bootstrap"
time="2020-05-12T09:56:35Z" level=debug msg="- masters in ../tmp/openshift-install-407594662/masters"
time="2020-05-12T09:56:35Z" level=debug
time="2020-05-12T09:56:35Z" level=debug msg="Initializing the backend..."
time="2020-05-12T09:56:35Z" level=debug
time="2020-05-12T09:56:35Z" level=debug msg="Initializing provider plugins..."
time="2020-05-12T09:56:37Z" level=debug
time="2020-05-12T09:56:37Z" level=debug msg="Terraform has been successfully initialized!"
time="2020-05-12T09:56:37Z" level=debug
time="2020-05-12T09:56:37Z" level=debug msg="You may now begin working with Terraform. Try running \"terraform plan\" to see"
time="2020-05-12T09:56:37Z" level=debug msg="any changes that are required for your infrastructure. All Terraform commands"
time="2020-05-12T09:56:37Z" level=debug msg="should now work."
time="2020-05-12T09:56:37Z" level=debug
time="2020-05-12T09:56:37Z" level=debug msg="If you ever set or change modules or backend configuration for Terraform,"
time="2020-05-12T09:56:37Z" level=debug msg="rerun this command to reinitialize your working directory. If you forget, other"
time="2020-05-12T09:56:37Z" level=debug msg="commands will detect it and remind you to do so if necessary."
time="2020-05-12T09:56:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Creating..."
time="2020-05-12T09:56:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Creating..."
time="2020-05-12T09:56:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Creating..."
time="2020-05-12T09:56:43Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Creating..."
time="2020-05-12T09:56:43Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Creating..."
time="2020-05-12T09:56:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [10s elapsed]"
time="2020-05-12T09:56:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [10s elapsed]"
time="2020-05-12T09:56:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [10s elapsed]"
time="2020-05-12T09:56:53Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [10s elapsed]"
time="2020-05-12T09:56:53Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [10s elapsed]"
time="2020-05-12T09:57:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [20s elapsed]"
time="2020-05-12T09:57:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [20s elapsed]"
time="2020-05-12T09:57:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [20s elapsed]"
time="2020-05-12T09:57:03Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [20s elapsed]"
time="2020-05-12T09:57:03Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [20s elapsed]"
time="2020-05-12T09:57:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [30s elapsed]"
time="2020-05-12T09:57:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [30s elapsed]"
time="2020-05-12T09:57:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [30s elapsed]"
time="2020-05-12T09:57:13Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [30s elapsed]"
time="2020-05-12T09:57:13Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [30s elapsed]"
time="2020-05-12T09:57:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [40s elapsed]"
time="2020-05-12T09:57:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [40s elapsed]"
time="2020-05-12T09:57:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [40s elapsed]"
time="2020-05-12T09:57:23Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [40s elapsed]"
time="2020-05-12T09:57:23Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [40s elapsed]"
time="2020-05-12T09:57:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [50s elapsed]"
time="2020-05-12T09:57:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [50s elapsed]"
time="2020-05-12T09:57:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [50s elapsed]"
time="2020-05-12T09:57:33Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [50s elapsed]"
time="2020-05-12T09:57:33Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [50s elapsed]"
time="2020-05-12T09:57:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [1m0s elapsed]"
time="2020-05-12T09:57:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [1m0s elapsed]"
time="2020-05-12T09:57:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [1m0s elapsed]"
time="2020-05-12T09:57:43Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [1m0s elapsed]"
time="2020-05-12T09:57:43Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [1m0s elapsed]"
time="2020-05-12T09:57:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [1m10s elapsed]"
time="2020-05-12T09:57:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [1m10s elapsed]"
time="2020-05-12T09:57:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [1m10s elapsed]"
time="2020-05-12T09:57:53Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [1m10s elapsed]"
time="2020-05-12T09:57:53Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [1m10s elapsed]"
time="2020-05-12T09:58:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [1m20s elapsed]"
time="2020-05-12T09:58:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [1m20s elapsed]"
time="2020-05-12T09:58:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [1m20s elapsed]"
time="2020-05-12T09:58:03Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [1m20s elapsed]"
time="2020-05-12T09:58:03Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [1m20s elapsed]"
time="2020-05-12T09:58:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [1m30s elapsed]"
time="2020-05-12T09:58:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [1m30s elapsed]"
time="2020-05-12T09:58:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [1m30s elapsed]"
time="2020-05-12T09:58:13Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [1m30s elapsed]"
time="2020-05-12T09:58:13Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [1m30s elapsed]"
time="2020-05-12T09:58:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [1m40s elapsed]"
time="2020-05-12T09:58:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [1m40s elapsed]"
time="2020-05-12T09:58:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [1m40s elapsed]"
time="2020-05-12T09:58:23Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [1m40s elapsed]"
time="2020-05-12T09:58:23Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [1m40s elapsed]"
time="2020-05-12T09:58:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [1m50s elapsed]"
time="2020-05-12T09:58:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [1m50s elapsed]"
time="2020-05-12T09:58:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [1m50s elapsed]"
time="2020-05-12T09:58:33Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [1m50s elapsed]"
time="2020-05-12T09:58:33Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [1m50s elapsed]"
time="2020-05-12T09:58:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [2m0s elapsed]"
time="2020-05-12T09:58:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [2m0s elapsed]"
time="2020-05-12T09:58:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [2m0s elapsed]"
time="2020-05-12T09:58:43Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Still creating... [2m0s elapsed]"
time="2020-05-12T09:58:43Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Still creating... [2m0s elapsed]"
time="2020-05-12T09:58:48Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Creation complete after 2m5s [id=/var/lib/libvirt/images/lab-phht8-bootstrap]"
time="2020-05-12T09:58:48Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Creation complete after 2m5s [id=/var/lib/libvirt/images/lab-phht8-bootstrap.ign;5eba7358-2d8a-834a-80a7-9d0f84ebf10d]"
time="2020-05-12T09:58:48Z" level=debug msg="module.bootstrap.libvirt_domain.bootstrap: Creating..."
time="2020-05-12T09:58:48Z" level=debug msg="module.bootstrap.libvirt_domain.bootstrap: Creation complete after 1s [id=ef681214-31b3-46bd-8550-dab6d49a0bfc]"
time="2020-05-12T09:58:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [2m10s elapsed]"
time="2020-05-12T09:58:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [2m10s elapsed]"
time="2020-05-12T09:58:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [2m10s elapsed]"
time="2020-05-12T09:59:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [2m20s elapsed]"
time="2020-05-12T09:59:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [2m20s elapsed]"
time="2020-05-12T09:59:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [2m20s elapsed]"
time="2020-05-12T09:59:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [2m30s elapsed]"
time="2020-05-12T09:59:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [2m30s elapsed]"
time="2020-05-12T09:59:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [2m30s elapsed]"
time="2020-05-12T09:59:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [2m40s elapsed]"
time="2020-05-12T09:59:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [2m40s elapsed]"
time="2020-05-12T09:59:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [2m40s elapsed]"
time="2020-05-12T09:59:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [2m50s elapsed]"
time="2020-05-12T09:59:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [2m50s elapsed]"
time="2020-05-12T09:59:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [2m50s elapsed]"
time="2020-05-12T09:59:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [3m0s elapsed]"
time="2020-05-12T09:59:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [3m0s elapsed]"
time="2020-05-12T09:59:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [3m0s elapsed]"
time="2020-05-12T09:59:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [3m10s elapsed]"
time="2020-05-12T09:59:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [3m10s elapsed]"
time="2020-05-12T09:59:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [3m10s elapsed]"
time="2020-05-12T10:00:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [3m20s elapsed]"
time="2020-05-12T10:00:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [3m20s elapsed]"
time="2020-05-12T10:00:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [3m20s elapsed]"
time="2020-05-12T10:00:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [3m30s elapsed]"
time="2020-05-12T10:00:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [3m30s elapsed]"
time="2020-05-12T10:00:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [3m30s elapsed]"
time="2020-05-12T10:00:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [3m40s elapsed]"
time="2020-05-12T10:00:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [3m40s elapsed]"
time="2020-05-12T10:00:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [3m40s elapsed]"
time="2020-05-12T10:00:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [3m50s elapsed]"
time="2020-05-12T10:00:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [3m50s elapsed]"
time="2020-05-12T10:00:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [3m50s elapsed]"
time="2020-05-12T10:00:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [4m0s elapsed]"
time="2020-05-12T10:00:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [4m0s elapsed]"
time="2020-05-12T10:00:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [4m0s elapsed]"
time="2020-05-12T10:00:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [4m10s elapsed]"
time="2020-05-12T10:00:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [4m10s elapsed]"
time="2020-05-12T10:00:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [4m10s elapsed]"
time="2020-05-12T10:01:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [4m20s elapsed]"
time="2020-05-12T10:01:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [4m20s elapsed]"
time="2020-05-12T10:01:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [4m20s elapsed]"
time="2020-05-12T10:01:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [4m30s elapsed]"
time="2020-05-12T10:01:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [4m30s elapsed]"
time="2020-05-12T10:01:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [4m30s elapsed]"
time="2020-05-12T10:01:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [4m40s elapsed]"
time="2020-05-12T10:01:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [4m40s elapsed]"
time="2020-05-12T10:01:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [4m40s elapsed]"
time="2020-05-12T10:01:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [4m50s elapsed]"
time="2020-05-12T10:01:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [4m50s elapsed]"
time="2020-05-12T10:01:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [4m50s elapsed]"
time="2020-05-12T10:01:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [5m0s elapsed]"
time="2020-05-12T10:01:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [5m0s elapsed]"
time="2020-05-12T10:01:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [5m0s elapsed]"
time="2020-05-12T10:01:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [5m10s elapsed]"
time="2020-05-12T10:01:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [5m10s elapsed]"
time="2020-05-12T10:01:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [5m10s elapsed]"
time="2020-05-12T10:02:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [5m20s elapsed]"
time="2020-05-12T10:02:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [5m20s elapsed]"
time="2020-05-12T10:02:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [5m20s elapsed]"
time="2020-05-12T10:02:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [5m30s elapsed]"
time="2020-05-12T10:02:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [5m30s elapsed]"
time="2020-05-12T10:02:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [5m30s elapsed]"
time="2020-05-12T10:02:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [5m40s elapsed]"
time="2020-05-12T10:02:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [5m40s elapsed]"
time="2020-05-12T10:02:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [5m40s elapsed]"
time="2020-05-12T10:02:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [5m50s elapsed]"
time="2020-05-12T10:02:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [5m50s elapsed]"
time="2020-05-12T10:02:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [5m50s elapsed]"
time="2020-05-12T10:02:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [6m0s elapsed]"
time="2020-05-12T10:02:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [6m0s elapsed]"
time="2020-05-12T10:02:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [6m0s elapsed]"
time="2020-05-12T10:02:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [6m10s elapsed]"
time="2020-05-12T10:02:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [6m10s elapsed]"
time="2020-05-12T10:02:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [6m10s elapsed]"
time="2020-05-12T10:03:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [6m20s elapsed]"
time="2020-05-12T10:03:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [6m20s elapsed]"
time="2020-05-12T10:03:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [6m20s elapsed]"
time="2020-05-12T10:03:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [6m30s elapsed]"
time="2020-05-12T10:03:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [6m30s elapsed]"
time="2020-05-12T10:03:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [6m30s elapsed]"
time="2020-05-12T10:03:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [6m40s elapsed]"
time="2020-05-12T10:03:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [6m40s elapsed]"
time="2020-05-12T10:03:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [6m40s elapsed]"
time="2020-05-12T10:03:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [6m50s elapsed]"
time="2020-05-12T10:03:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [6m50s elapsed]"
time="2020-05-12T10:03:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [6m50s elapsed]"
time="2020-05-12T10:03:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [7m0s elapsed]"
time="2020-05-12T10:03:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [7m0s elapsed]"
time="2020-05-12T10:03:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [7m0s elapsed]"
time="2020-05-12T10:03:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [7m10s elapsed]"
time="2020-05-12T10:03:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [7m10s elapsed]"
time="2020-05-12T10:03:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [7m10s elapsed]"
time="2020-05-12T10:04:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [7m20s elapsed]"
time="2020-05-12T10:04:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [7m20s elapsed]"
time="2020-05-12T10:04:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [7m20s elapsed]"
time="2020-05-12T10:04:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [7m30s elapsed]"
time="2020-05-12T10:04:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [7m30s elapsed]"
time="2020-05-12T10:04:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [7m30s elapsed]"
time="2020-05-12T10:04:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [7m40s elapsed]"
time="2020-05-12T10:04:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [7m40s elapsed]"
time="2020-05-12T10:04:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [7m40s elapsed]"
time="2020-05-12T10:04:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [7m50s elapsed]"
time="2020-05-12T10:04:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [7m50s elapsed]"
time="2020-05-12T10:04:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [7m50s elapsed]"
time="2020-05-12T10:04:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [8m0s elapsed]"
time="2020-05-12T10:04:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [8m0s elapsed]"
time="2020-05-12T10:04:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [8m0s elapsed]"
time="2020-05-12T10:04:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [8m10s elapsed]"
time="2020-05-12T10:04:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [8m10s elapsed]"
time="2020-05-12T10:04:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [8m10s elapsed]"
time="2020-05-12T10:05:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [8m20s elapsed]"
time="2020-05-12T10:05:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [8m20s elapsed]"
time="2020-05-12T10:05:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [8m20s elapsed]"
time="2020-05-12T10:05:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [8m30s elapsed]"
time="2020-05-12T10:05:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [8m30s elapsed]"
time="2020-05-12T10:05:12Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [8m30s elapsed]"
time="2020-05-12T10:05:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [8m40s elapsed]"
time="2020-05-12T10:05:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [8m40s elapsed]"
time="2020-05-12T10:05:22Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [8m40s elapsed]"
time="2020-05-12T10:05:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [8m50s elapsed]"
time="2020-05-12T10:05:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [8m50s elapsed]"
time="2020-05-12T10:05:32Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [8m50s elapsed]"
time="2020-05-12T10:05:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [9m0s elapsed]"
time="2020-05-12T10:05:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [9m0s elapsed]"
time="2020-05-12T10:05:42Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [9m0s elapsed]"
time="2020-05-12T10:05:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Still creating... [9m10s elapsed]"
time="2020-05-12T10:05:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Still creating... [9m10s elapsed]"
time="2020-05-12T10:05:52Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Still creating... [9m10s elapsed]"
time="2020-05-12T10:06:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[0]: Creation complete after 9m19s [id=d6a06e4e-e942-41e9-8276-807bb6a53dc6]"
time="2020-05-12T10:06:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[2]: Creation complete after 9m19s [id=0fa1fb61-443d-4a94-9cc2-cd8d2ed0447c]"
time="2020-05-12T10:06:02Z" level=debug msg="module.masters.ironic_node_v1.openshift-master-host[1]: Creation complete after 9m19s [id=77d92898-52b2-4cf4-9f91-6f49d8f2a9a9]"
time="2020-05-12T10:06:02Z" level=debug msg="module.masters.ironic_allocation_v1.openshift-master-allocation[0]: Creating..."
time="2020-05-12T10:06:02Z" level=debug msg="module.masters.ironic_allocation_v1.openshift-master-allocation[1]: Creating..."
time="2020-05-12T10:06:02Z" level=debug msg="module.masters.ironic_allocation_v1.openshift-master-allocation[2]: Creating..."
time="2020-05-12T10:06:04Z" level=debug msg="module.masters.ironic_allocation_v1.openshift-master-allocation[0]: Creation complete after 2s [id=fc55a790-4d2c-47e3-88b0-2c5de9d51688]"
time="2020-05-12T10:06:04Z" level=debug msg="module.masters.ironic_allocation_v1.openshift-master-allocation[1]: Creation complete after 2s [id=6f2b6b8a-446f-4fe5-8e73-1713c1315c1e]"
time="2020-05-12T10:06:04Z" level=debug msg="module.masters.ironic_allocation_v1.openshift-master-allocation[2]: Creation complete after 2s [id=b4d8c29d-a7ab-44b9-96c3-9b2fde3c0f00]"
time="2020-05-12T10:06:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Creating..."
time="2020-05-12T10:06:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Creating..."
time="2020-05-12T10:06:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Creating..."
time="2020-05-12T10:06:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [10s elapsed]"
time="2020-05-12T10:06:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [10s elapsed]"
time="2020-05-12T10:06:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [10s elapsed]"
time="2020-05-12T10:06:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [20s elapsed]"
time="2020-05-12T10:06:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [20s elapsed]"
time="2020-05-12T10:06:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [20s elapsed]"
time="2020-05-12T10:06:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [30s elapsed]"
time="2020-05-12T10:06:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [30s elapsed]"
time="2020-05-12T10:06:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [30s elapsed]"
time="2020-05-12T10:06:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [40s elapsed]"
time="2020-05-12T10:06:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [40s elapsed]"
time="2020-05-12T10:06:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [40s elapsed]"
time="2020-05-12T10:06:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [50s elapsed]"
time="2020-05-12T10:06:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [50s elapsed]"
time="2020-05-12T10:06:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [50s elapsed]"
time="2020-05-12T10:07:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [1m0s elapsed]"
time="2020-05-12T10:07:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [1m0s elapsed]"
time="2020-05-12T10:07:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [1m0s elapsed]"
time="2020-05-12T10:07:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [1m10s elapsed]"
time="2020-05-12T10:07:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [1m10s elapsed]"
time="2020-05-12T10:07:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [1m10s elapsed]"
time="2020-05-12T10:07:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [1m20s elapsed]"
time="2020-05-12T10:07:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [1m20s elapsed]"
time="2020-05-12T10:07:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [1m20s elapsed]"
time="2020-05-12T10:07:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [1m30s elapsed]"
time="2020-05-12T10:07:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [1m30s elapsed]"
time="2020-05-12T10:07:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [1m30s elapsed]"
time="2020-05-12T10:07:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [1m40s elapsed]"
time="2020-05-12T10:07:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [1m40s elapsed]"
time="2020-05-12T10:07:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [1m40s elapsed]"
time="2020-05-12T10:07:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [1m50s elapsed]"
time="2020-05-12T10:07:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [1m50s elapsed]"
time="2020-05-12T10:07:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [1m50s elapsed]"
time="2020-05-12T10:08:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [2m0s elapsed]"
time="2020-05-12T10:08:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [2m0s elapsed]"
time="2020-05-12T10:08:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [2m0s elapsed]"
time="2020-05-12T10:08:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [2m10s elapsed]"
time="2020-05-12T10:08:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [2m10s elapsed]"
time="2020-05-12T10:08:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [2m10s elapsed]"
time="2020-05-12T10:08:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [2m20s elapsed]"
time="2020-05-12T10:08:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [2m20s elapsed]"
time="2020-05-12T10:08:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [2m20s elapsed]"
time="2020-05-12T10:08:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [2m30s elapsed]"
time="2020-05-12T10:08:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [2m30s elapsed]"
time="2020-05-12T10:08:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [2m30s elapsed]"
time="2020-05-12T10:08:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [2m40s elapsed]"
time="2020-05-12T10:08:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [2m40s elapsed]"
time="2020-05-12T10:08:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [2m40s elapsed]"
time="2020-05-12T10:08:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [2m50s elapsed]"
time="2020-05-12T10:08:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [2m50s elapsed]"
time="2020-05-12T10:08:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [2m50s elapsed]"
time="2020-05-12T10:09:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [3m0s elapsed]"
time="2020-05-12T10:09:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [3m0s elapsed]"
time="2020-05-12T10:09:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [3m0s elapsed]"
time="2020-05-12T10:09:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [3m10s elapsed]"
time="2020-05-12T10:09:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [3m10s elapsed]"
time="2020-05-12T10:09:14Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [3m10s elapsed]"
time="2020-05-12T10:09:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [3m20s elapsed]"
time="2020-05-12T10:09:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [3m20s elapsed]"
time="2020-05-12T10:09:24Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [3m20s elapsed]"
time="2020-05-12T10:09:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [3m30s elapsed]"
time="2020-05-12T10:09:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [3m30s elapsed]"
time="2020-05-12T10:09:34Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [3m30s elapsed]"
time="2020-05-12T10:09:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [3m40s elapsed]"
time="2020-05-12T10:09:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [3m40s elapsed]"
time="2020-05-12T10:09:44Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [3m40s elapsed]"
time="2020-05-12T10:09:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [3m50s elapsed]"
time="2020-05-12T10:09:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [3m50s elapsed]"
time="2020-05-12T10:09:54Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [3m50s elapsed]"
time="2020-05-12T10:10:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Still creating... [4m0s elapsed]"
time="2020-05-12T10:10:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Still creating... [4m0s elapsed]"
time="2020-05-12T10:10:04Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Still creating... [4m0s elapsed]"
time="2020-05-12T10:10:10Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[2]: Creation complete after 4m5s [id=77d92898-52b2-4cf4-9f91-6f49d8f2a9a9]"
time="2020-05-12T10:10:10Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[0]: Creation complete after 4m5s [id=d6a06e4e-e942-41e9-8276-807bb6a53dc6]"
time="2020-05-12T10:10:10Z" level=debug msg="module.masters.ironic_deployment.openshift-master-deployment[1]: Creation complete after 4m5s [id=0fa1fb61-443d-4a94-9cc2-cd8d2ed0447c]"
time="2020-05-12T10:10:10Z" level=debug
time="2020-05-12T10:10:10Z" level=debug msg="Apply complete! Resources: 12 added, 0 changed, 0 destroyed."
time="2020-05-12T10:10:10Z" level=debug msg="OpenShift Installer 4.5.0-0.nightly-2020-05-12-065413"
time="2020-05-12T10:10:10Z" level=debug msg="Built from commit e476c483ed99c9cf2982529178e668dbcaf3ed5e"
time="2020-05-12T10:10:10Z" level=info msg="Waiting up to 20m0s for the Kubernetes API at https://api.lab.cnftigerteam.com:6443..."
time="2020-05-12T10:10:10Z" level=info msg="API v1.18.2 up"
time="2020-05-12T10:10:10Z" level=info msg="Waiting up to 40m0s for bootstrapping to complete..."
time="2020-05-12T10:17:24Z" level=debug msg="Bootstrap status: complete"
time="2020-05-12T10:17:24Z" level=info msg="Destroying the bootstrap resources..."
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-libvirt src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-libvirt\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-openstack src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-openstack\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-vsphere src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-vsphere\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-aws src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-aws\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-azurerm src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-azurerm\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-azureprivatedns src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-azureprivatedns\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-google src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-google\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-ironic src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-ironic\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-ignition src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-ignition\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-local src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-local\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-ovirt src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-ovirt\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-random src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-random\""
time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-vsphereprivate src: \"/root/bin/openshift-baremetal-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-vsphereprivate\""
time="2020-05-12T10:17:24Z" level=debug msg="Initializing modules..."
time="2020-05-12T10:17:24Z" level=debug msg="- bootstrap in ../tmp/openshift-install-678758349/bootstrap"
time="2020-05-12T10:17:24Z" level=debug msg="- masters in ../tmp/openshift-install-678758349/masters"
time="2020-05-12T10:17:24Z" level=debug
time="2020-05-12T10:17:24Z" level=debug msg="Initializing the backend..."
time="2020-05-12T10:17:24Z" level=debug
time="2020-05-12T10:17:24Z" level=debug msg="Initializing provider plugins..."
time="2020-05-12T10:17:26Z" level=debug
time="2020-05-12T10:17:26Z" level=debug msg="Terraform has been successfully initialized!"
time="2020-05-12T10:17:26Z" level=debug
time="2020-05-12T10:17:26Z" level=debug msg="You may now begin working with Terraform. Try running \"terraform plan\" to see"
time="2020-05-12T10:17:26Z" level=debug msg="any changes that are required for your infrastructure. All Terraform commands"
time="2020-05-12T10:17:26Z" level=debug msg="should now work."
time="2020-05-12T10:17:26Z" level=debug
time="2020-05-12T10:17:26Z" level=debug msg="If you ever set or change modules or backend configuration for Terraform,"
time="2020-05-12T10:17:26Z" level=debug msg="rerun this command to reinitialize your working directory. If you forget, other"
time="2020-05-12T10:17:26Z" level=debug msg="commands will detect it and remind you to do so if necessary."
time="2020-05-12T10:17:30Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Refreshing state... [id=/var/lib/libvirt/images/lab-phht8-bootstrap]"
time="2020-05-12T10:17:30Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Refreshing state... [id=/var/lib/libvirt/images/lab-phht8-bootstrap.ign;5eba7358-2d8a-834a-80a7-9d0f84ebf10d]"
time="2020-05-12T10:17:30Z" level=debug msg="module.bootstrap.libvirt_domain.bootstrap: Refreshing state... [id=ef681214-31b3-46bd-8550-dab6d49a0bfc]"
time="2020-05-12T10:17:31Z" level=debug msg="module.bootstrap.libvirt_domain.bootstrap: Destroying... [id=ef681214-31b3-46bd-8550-dab6d49a0bfc]"
time="2020-05-12T10:17:31Z" level=debug msg="module.bootstrap.libvirt_domain.bootstrap: Destruction complete after 1s"
time="2020-05-12T10:17:31Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Destroying... [id=/var/lib/libvirt/images/lab-phht8-bootstrap]"
time="2020-05-12T10:17:31Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Destroying... [id=/var/lib/libvirt/images/lab-phht8-bootstrap.ign;5eba7358-2d8a-834a-80a7-9d0f84ebf10d]"
time="2020-05-12T10:17:32Z" level=debug msg="module.bootstrap.libvirt_volume.bootstrap: Destruction complete after 1s"
time="2020-05-12T10:17:32Z" level=debug msg="module.bootstrap.libvirt_ignition.bootstrap: Destruction complete after 1s"
time="2020-05-12T10:17:32Z" level=debug
time="2020-05-12T10:17:32Z" level=debug msg="Warning: Resource targeting is in effect"
time="2020-05-12T10:17:32Z" level=debug
time="2020-05-12T10:17:32Z" level=debug msg="You are creating a plan with the -target option, which means that the result"
time="2020-05-12T10:17:32Z" level=debug msg="of this plan may not represent all of the changes requested by the current"
time="2020-05-12T10:17:32Z" level=debug msg=configuration.
time="2020-05-12T10:17:32Z" level=debug msg="\t\t"
time="2020-05-12T10:17:32Z" level=debug msg="The -target option is not for routine use, and is provided only for"
time="2020-05-12T10:17:32Z" level=debug msg="exceptional situations such as recovering from errors or mistakes, or when"
time="2020-05-12T10:17:32Z" level=debug msg="Terraform specifically suggests to use it as part of an error message."
time="2020-05-12T10:17:32Z" level=debug
time="2020-05-12T10:17:32Z" level=debug
time="2020-05-12T10:17:32Z" level=debug msg="Warning: Applied changes may be incomplete"
time="2020-05-12T10:17:32Z" level=debug
time="2020-05-12T10:17:32Z" level=debug msg="The plan was created with the -target option in effect, so some changes"
time="2020-05-12T10:17:32Z" level=debug msg="requested in the configuration may have been ignored and the output values may"
time="2020-05-12T10:17:32Z" level=debug msg="not be fully updated. Run the following command to verify that no other"
time="2020-05-12T10:17:32Z" level=debug msg="changes are pending:"
time="2020-05-12T10:17:32Z" level=debug msg="    terraform plan"
time="2020-05-12T10:17:32Z" level=debug msg="\t"
time="2020-05-12T10:17:32Z" level=debug msg="Note that the -target option is not suitable for routine use, and is provided"
time="2020-05-12T10:17:32Z" level=debug msg="only for exceptional situations such as recovering from errors or mistakes, or"
time="2020-05-12T10:17:32Z" level=debug msg="when Terraform specifically suggests to use it as part of an error message."
time="2020-05-12T10:17:32Z" level=debug
time="2020-05-12T10:17:32Z" level=debug
time="2020-05-12T10:17:32Z" level=debug msg="Destroy complete! Resources: 3 destroyed."
time="2020-05-12T10:17:32Z" level=debug msg="Fetching Install Config..."
time="2020-05-12T10:17:32Z" level=debug msg="Loading Install Config..."
time="2020-05-12T10:17:32Z" level=debug msg="  Loading SSH Key..."
time="2020-05-12T10:17:32Z" level=debug msg="  Loading Base Domain..."
time="2020-05-12T10:17:32Z" level=debug msg="    Loading Platform..."
time="2020-05-12T10:17:32Z" level=debug msg="  Loading Cluster Name..."
time="2020-05-12T10:17:32Z" level=debug msg="    Loading Base Domain..."
time="2020-05-12T10:17:32Z" level=debug msg="    Loading Platform..."
time="2020-05-12T10:17:32Z" level=debug msg="  Loading Pull Secret..."
time="2020-05-12T10:17:32Z" level=debug msg="  Loading Platform..."
time="2020-05-12T10:17:32Z" level=debug msg="Using Install Config loaded from state file"
time="2020-05-12T10:17:32Z" level=debug msg="Reusing previously-fetched Install Config"
time="2020-05-12T10:17:32Z" level=info msg="Waiting up to 1h0m0s for the cluster at https://api.lab.cnftigerteam.com:6443 to initialize..."
time="2020-05-12T10:17:32Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 13% complete"
time="2020-05-12T10:17:36Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 54% complete"
time="2020-05-12T10:17:51Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 55% complete"
time="2020-05-12T10:18:51Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 57% complete"
time="2020-05-12T10:21:51Z" level=debug msg="Still waiting for the cluster to initialize: Multiple errors are preventing progress:\n* Could not update prometheusrule \"openshift-cloud-credential-operator/cloud-credential-operator-alerts\" (177 of 574): the server does not recognize this resource, check extension API servers\n* Could not update prometheusrule \"openshift-cluster-samples-operator/samples-operator-alerts\" (294 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-authentication-operator/authentication-operator\" (489 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-cluster-machine-approver/cluster-machine-approver\" (499 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-cluster-version/cluster-version-operator\" (8 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-config-operator/config-operator\" (105 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-image-registry/image-registry\" (495 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-machine-api/cluster-autoscaler-operator\" (209 of 574): the server does not recognize this resource, check extension API servers"
time="2020-05-12T10:25:06Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 60% complete"
time="2020-05-12T10:25:22Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 60% complete"
time="2020-05-12T10:25:53Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 60% complete"
time="2020-05-12T10:26:17Z" level=debug msg="Still waiting for the cluster to initialize: Multiple errors are preventing progress:\n* Could not update console \"cluster\" (19 of 574)\n* Could not update credentialsrequest \"openshift-cloud-credential-operator/openshift-image-registry\" (234 of 574)\n* Could not update credentialsrequest \"openshift-cloud-credential-operator/openshift-machine-api-gcp\" (113 of 574)\n* Could not update oauthclient \"console\" (342 of 574)\n* Could not update prometheusrule \"openshift-cloud-credential-operator/cloud-credential-operator-alerts\" (177 of 574)\n* Could not update prometheusrule \"openshift-cluster-samples-operator/samples-operator-alerts\" (294 of 574)\n* Could not update servicemonitor \"openshift-authentication-operator/authentication-operator\" (489 of 574)\n* Could not update servicemonitor \"openshift-cluster-machine-approver/cluster-machine-approver\" (499 of 574)\n* Could not update servicemonitor \"openshift-cluster-version/cluster-version-operator\" (8 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-config-operator/config-operator\" (105 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-image-registry/image-registry\" (495 of 574)\n* Could not update servicemonitor \"openshift-machine-api/cluster-autoscaler-operator\" (209 of 574)"
time="2020-05-12T10:28:06Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 61% complete"
time="2020-05-12T10:28:21Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 62% complete"
time="2020-05-12T10:28:51Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 63% complete"
time="2020-05-12T10:29:06Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 65% complete"
time="2020-05-12T10:31:06Z" level=debug msg="Still waiting for the cluster to initialize: Multiple errors are preventing progress:\n* Could not update prometheusrule \"openshift-cloud-credential-operator/cloud-credential-operator-alerts\" (177 of 574): the server does not recognize this resource, check extension API servers\n* Could not update prometheusrule \"openshift-cluster-samples-operator/samples-operator-alerts\" (294 of 574): the server does not recognize this resource, check extension API servers\n* Could not update route \"openshift-console/downloads\" (373 of 574): the server is down or not responding\n* Could not update servicemonitor \"openshift-authentication-operator/authentication-operator\" (489 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-cluster-machine-approver/cluster-machine-approver\" (499 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-cluster-version/cluster-version-operator\" (8 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-config-operator/config-operator\" (105 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-image-registry/image-registry\" (495 of 574): the server does not recognize this resource, check extension API servers\n* Could not update servicemonitor \"openshift-machine-api/cluster-autoscaler-operator\" (209 of 574): the server does not recognize this resource, check extension API servers"
time="2020-05-12T10:33:36Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 68% complete"
time="2020-05-12T10:33:51Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 74% complete"
time="2020-05-12T10:34:06Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 75% complete"
time="2020-05-12T10:34:21Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 76% complete"
time="2020-05-12T10:34:36Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 82% complete"
time="2020-05-12T10:34:51Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 83% complete"
time="2020-05-12T10:35:21Z" level=debug msg="Still waiting for the cluster to initialize: Cluster operator kube-scheduler is reporting a failure: NodeInstallerDegraded: 1 nodes are failing on revision 3:\nNodeInstallerDegraded: static pod of revision 3 has been installed, but is not ready while new revision 4 is pending; 1 nodes are failing on revision 4:\nNodeInstallerDegraded: static pod of revision 4 has been installed, but is not ready while new revision 5 is pending; 1 nodes are failing on revision 6:\nNodeInstallerDegraded: "
time="2020-05-12T10:38:37Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 85% complete"
time="2020-05-12T10:41:21Z" level=debug msg="Still waiting for the cluster to initialize: Cluster operator console is reporting a failure: OCDownloadsSyncDegraded: ConsoleCLIDownload.console.openshift.io \"oc-cli-downloads\" is invalid: spec.links.href: Invalid value: \"\": spec.links.href in body should match '^https://'"
time="2020-05-12T10:44:51Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 86% complete"
time="2020-05-12T10:45:52Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 86% complete"
time="2020-05-12T10:47:15Z" level=debug msg="Still waiting for the cluster to initialize: Cluster operator console is reporting a failure: OCDownloadsSyncDegraded: ConsoleCLIDownload.console.openshift.io \"oc-cli-downloads\" is invalid: spec.links.href: Invalid value: \"\": spec.links.href in body should match '^https://'"
time="2020-05-12T11:08:21Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 86% complete"
time="2020-05-12T11:11:17Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413"
time="2020-05-12T11:11:17Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: downloading update"
time="2020-05-12T11:11:18Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413"
time="2020-05-12T11:11:18Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 0% complete"
time="2020-05-12T11:11:18Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 9% complete"
time="2020-05-12T11:11:18Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 13% complete"
time="2020-05-12T11:11:33Z" level=debug msg="Still waiting for the cluster to initialize: Working towards 4.5.0-0.nightly-2020-05-12-065413: 87% complete"
time="2020-05-12T11:13:03Z" level=debug msg="Cluster is initialized"
time="2020-05-12T11:13:03Z" level=info msg="Waiting up to 10m0s for the openshift-console route to be created..."
time="2020-05-12T11:13:03Z" level=debug msg="Route found in openshift-console namespace: console"
time="2020-05-12T11:13:03Z" level=debug msg="Route found in openshift-console namespace: downloads"
time="2020-05-12T11:13:03Z" level=debug msg="OpenShift console route is created"
time="2020-05-12T11:13:03Z" level=info msg="Install complete!"
time="2020-05-12T11:13:03Z" level=info msg="To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/root/ocp/auth/kubeconfig'"
time="2020-05-12T11:13:03Z" level=info msg="Access the OpenShift web-console here: https://console-openshift-console.apps.lab.cnftigerteam.com"
time="2020-05-12T11:13:03Z" level=info msg="Login to the console with user: \"kubeadmin\", and password: \"XXX\""
time="2020-05-12T11:13:03Z" level=debug msg="Time elapsed per stage:"
time="2020-05-12T11:13:03Z" level=debug msg="    Infrastructure: 13m35s"
time="2020-05-12T11:13:03Z" level=debug msg="Bootstrap Complete: 7m14s"
time="2020-05-12T11:13:03Z" level=debug msg=" Bootstrap Destroy: 9s"
time="2020-05-12T11:13:03Z" level=debug msg=" Cluster Operators: 55m30s"
time="2020-05-12T11:13:03Z" level=info msg="Time elapsed: 1h16m58s"
time="2020-05-12T11:13:03Z" level=debug msg="OpenShift Installer 4.5.0-0.nightly-2020-05-12-065413"
time="2020-05-12T11:13:03Z" level=debug msg="Built from commit e476c483ed99c9cf2982529178e668dbcaf3ed5e"
time="2020-05-12T11:13:03Z" level=debug msg="Fetching Install Config..."
time="2020-05-12T11:13:03Z" level=debug msg="Loading Install Config..."
time="2020-05-12T11:13:03Z" level=debug msg="  Loading SSH Key..."
time="2020-05-12T11:13:03Z" level=debug msg="  Loading Base Domain..."
time="2020-05-12T11:13:03Z" level=debug msg="    Loading Platform..."
time="2020-05-12T11:13:03Z" level=debug msg="  Loading Cluster Name..."
time="2020-05-12T11:13:03Z" level=debug msg="    Loading Base Domain..."
time="2020-05-12T11:13:03Z" level=debug msg="    Loading Platform..."
time="2020-05-12T11:13:03Z" level=debug msg="  Loading Pull Secret..."
time="2020-05-12T11:13:03Z" level=debug msg="  Loading Platform..."
time="2020-05-12T11:13:03Z" level=debug msg="Using Install Config loaded from state file"
time="2020-05-12T11:13:03Z" level=debug msg="Reusing previously-fetched Install Config"
time="2020-05-12T11:13:03Z" level=info msg="Waiting up to 1h0m0s for the cluster at https://api.lab.cnftigerteam.com:6443 to initialize..."
time="2020-05-12T11:13:03Z" level=debug msg="Cluster is initialized"
time="2020-05-12T11:13:03Z" level=info msg="Waiting up to 10m0s for the openshift-console route to be created..."
time="2020-05-12T11:13:03Z" level=debug msg="Route found in openshift-console namespace: console"
time="2020-05-12T11:13:03Z" level=debug msg="Route found in openshift-console namespace: downloads"
time="2020-05-12T11:13:03Z" level=debug msg="OpenShift console route is created"
time="2020-05-12T11:13:03Z" level=info msg="Install complete!"
time="2020-05-12T11:13:03Z" level=info msg="To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/root/ocp/auth/kubeconfig'"
time="2020-05-12T11:13:03Z" level=info msg="Access the OpenShift web-console here: https://console-openshift-console.apps.lab.cnftigerteam.com"
time="2020-05-12T11:13:03Z" level=info msg="Login to the console with user: \"kubeadmin\", and password: \"XXXX\""
time="2020-05-12T11:13:03Z" level=info msg="Time elapsed: 0s"

```

This script does the following things:

- Calls the script clean.sh located in /root/bin which removes bootstrap vms which would be left around from a previous failed deployment.
- Calls the previously mentioned helper script ipmi.py so that it actually stops through IPMI all the nodes declared in our install-config.yaml.
- Creates ocp directory where install-config.yaml gets copied.
- Copies any yaml files from the manifests directory into the ocp/openshift one so that one can customize the installation (Generally unsupported/to be used at one own's risk).
- Launches the install retrying several time to account for timeouts.
- Waits for all workers defined in the *install-config.yaml* to show up.

## Troubleshooting the deployment

During the deployment, you can use typical openshift troubleshooting:

1. Connect to the bootstrap vm with `virsh list` and `virsh console $BOOTSTRAP_VM`
2. Connect to it using `ssh core@172.22.0.2` (Wait for the ironic containers to start for this to work).
3. Review bootstrap logs using the command showed upon connecting to the bootstrap vm.

Once ironic has started on the bootstrap vm, you can also check with the following command the progress of the provisioning of the masters with the following (which makes use of the definition found in */root/clouds.yaml*)

```
export OS_CLOUD=metal3-bootstrap
openstack baremetal node list
```

# Review

This concludes the lab !

In this lab, you have accomplished the following activities.

1. Properly prepare a successful Baremetal ipi deployment.
2. Deploy Openshift!
3. Understand internal aspects of the workflow and how to troubleshoot issues.

# Additional resources

- [https://github.com/openshift/installer/blob/master/docs/user/metal/install_ipi.md](https://github.com/openshift/installer/blob/master/docs/user/metal/install_ipi.md)
- [https://openshift-kni.github.io/baremetal-deploy](https://openshift-kni.github.io/baremetal-deploy)
