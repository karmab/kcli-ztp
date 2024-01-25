Introduction and Prerequisites
==============================

This hands on lab will provide you instructions so you can deploy Openshift using Baremetal IPI. The goal is to make you understand Baremetal IPI internals and workflow so that you can easily make use of it with real Baremetal and troubleshoot issues.

We emulate baremetal by using 3 empty virtual machines used as ctlplane nodes.

An additional vm is used to drive the installation, using dedicated bash scripts for each part of the workflow.

General Prerequisites
---------------------

The following items are needed in order to be able to complete the lab from beginning to end:

-  A powerful enough libvirt hypervisor with ssh access running a rhel-based OS
-  a valid Pull secret from `here <https://console.redhat.com/openshift/install/pull-secret>`__ to keep in a file named ‘openshift_pull.json’
-  git tool (for cloning the repo only)

**NOTE:** You will need around 50Gb of RAM in order for openshift to successfully deploy. If you don’t meet those requirements, you can still run through the lab but be warned that the final openshift deployment might not succeed.

Preparing the lab
=================

**NOTE:** This section can be skipped if lab has been prepared for you.

Prepare the hypervisor
----------------------

We install and launch libvirt, as needed for the bootstrap vm

::

   sudo dnf -y install libvirt libvirt-daemon-driver-qemu qemu-kvm
   systemctl enable --now libvirtd

Get kcli
--------

We will leverage `kcli <https://kcli.readthedocs.io/en/latest>`__ to easily create the assets needed for the lab.

Install it with the following instructions

::

   sudo dnf -y copr enable karmab/kcli 
   sudo dnf -y install kcli

Deploy The lab plan
-------------------

-  Launch the following command:

::

   git clone https://github.com/karmab/kcli-openshift4-baremetal
   cd kcli-openshift4-baremetal
   kcli create plan -f kcli_plan.yml --paramfile paramfiles/lab.yml lab

Expected Output

::

   Running kcli_pre.sh
   Deploying Images...
   Image centos8stream skipped!
   Deploying Vms...
   Skipping kcli_pre.sh as requested
   Deploying Networks...
   Network lab-baremetal skipped!
   Deploying Dns Entries...
   Creating dns entry for api in network lab-baremetal
   Skipping existing entry for ip 192.168.129.253 and name api
   Creating dns entry for apps in network lab-baremetal
   Skipping existing entry for ip 192.168.129.252 and name apps
   Deploying Vms...
   Adding a reserved ip entry for ip 192.168.129.20 and mac aa:aa:aa:aa:bb:01
   lab-ctlplane-0 deployed on local
   Adding a reserved ip entry for ip 192.168.129.21 and mac aa:aa:aa:aa:bb:02
   lab-ctlplane-1 deployed on local
   Adding a reserved ip entry for ip 192.168.129.22 and mac aa:aa:aa:aa:bb:03
   lab-ctlplane-2 deployed on local
   Injecting private key for lab-installer
   Creating dns entry for lab-installer.karmalabs.corp in network lab-baremetal
   Waiting 5 seconds to grab ip...
   Waiting 5 seconds to grab ip...
   Waiting 5 seconds to grab ip...
   lab-installer deployed on local

This will deploy 3 empty ctlplanes to emulate baremetal along with a Centos8stream installer vm where the lab will be run.

-  Check the created vms

::

   kcli list vm

Expected Output

::

   +-----------------+--------+-----------------+--------------------------------------------------------+------------------+---------------+
   |      Name       | Status |       Ips       |                         Source                         |       Plan       |   Profile     |
   +-----------------+--------+-----------------+--------------------------------------------------------+------------------+---------------+
   |  lab-installer  |   up   |  192.168.129.46 | CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2 |       lab        | local_centos8 |
   |  lab-ctlplane-0 |  down  |  192.168.129.20 |                                                        |       lab        |    kvirt      |
   |  lab-ctlplane-1 |  down  |  192.168.129.21 |                                                        |       lab        |    kvirt      |
   |  lab-ctlplane-2 |  down  |  192.168.129.22 |                                                        |       lab        |    kvirt      |
   +-----------------+--------+-----------------+--------------------------------------------------------+------------------+---------------+

-  Check the created networks

::

   kcli list networks

Expected Output

::

   +------------------+---------+------------------+-------+------------------+------+
   | Network          |   Type  |       Cidr       |  Dhcp |      Domain      | Mode |
   +------------------+---------+------------------+-------+------------------+------+
   | default          |  routed | 192.168.122.0/24 |  True |     default      | nat  |
   | lab-baremetal    |  routed | 192.168.129.0/24 |  True |  lab-baremetal   | nat  |
   +------------------+---------+------------------+-------+------------------+------+

-  Connect to the installer vm

::

   kcli ssh root@lab-installer

**NOTE:** In the remainder of the lab, the user is assumed to be connected (through ssh) to the installer vm and located in the /root directory.

**NOTE:** In each section, we recommend to read the corresponding script to get a better understanding of what’s beeing achieved.

Explore the environment
=======================

In the installer vm, Let’s look at the following elements:

-  There are several numbered scripts in ``/root/scripts`` that we will execute in the next sections.
-  The pull secret was copied in /root/openshift_pull.json\* .
-  Check */root/install-config.yaml* which is the main asset to be used when deploying Openshift:

   -  It contains initial information but we will make it evolve with each section until deploying.
   -  Check the section containing credential information for your ctlplanes and the replicas attribute. We would define information from workers using the same pattern( and specifying worker as *role*)
   -  Revisit this file at the end of each section to see the modifications done.

Virtual Masters preparation
===========================

In this section, we install and configure ksushy, which is part of kcli and allows to use redfish calls when interacting with virtual machines.

Launch the following command:

::

   /root/scripts/00_virtual.sh

Expected Output

::

   0 files removed
   determining the fastest mirror (10 hosts).. done.
   CentOS Stream 8 - AppStream                      19 MB/s |  26 MB     00:01
   determining the fastest mirror (9 hosts).. done.
   CentOS Stream 8 - BaseOS                         17 MB/s |  26 MB     00:01
   determining the fastest mirror (9 hosts).. done.
   CentOS Stream 8 - Extras                         16 kB/s |  18 kB     00:01
   Dependencies resolved.
   =========================================================================================
    Package                  Arch    Version                                Repo        Size
   =========================================================================================
   Installing:
    gcc                      x86_64  8.5.0-17.el8                           baseos      23 M
    git                      x86_64  2.31.1-2.el8                           appstream  161 k
    libvirt-devel            x86_64  8.0.0-10.module_el8.7.0+1218+f626c2ff  appstream  248 k
    pkgconf-pkg-config       x86_64  1.4.2-1.el8                            baseos      15 k
    python3-libvirt          x86_64  8.0.0-2.module_el8.7.0+1218+f626c2ff   appstream  332 k
    python3-netifaces        x86_64  0.10.6-4.el8                           appstream   25 k
    python36                 x86_64  3.6.8-38.module_el8.5.0+895+a459eca8   appstream   19 k
   Upgrading:
    chkconfig                x86_64  1.19.1-1.el8                           baseos     198 k
    libgcc                   x86_64  8.5.0-17.el8                           baseos      81 k
    libgomp                  x86_64  8.5.0-17.el8                           baseos     207 k
   Installing dependencies:
    binutils                 x86_64  2.30-119.el8                           baseos     5.8 M
    cpp                      x86_64  8.5.0-17.el8                           baseos      10 M
    cyrus-sasl               x86_64  2.1.27-5.el8                           baseos      96 k
    cyrus-sasl-gssapi        x86_64  2.1.27-5.el8                           baseos      50 k
    emacs-filesystem         noarch  1:26.1-7.el8                           baseos      70 k
    git-core                 x86_64  2.31.1-2.el8                           appstream  4.7 M
    git-core-doc             noarch  2.31.1-2.el8                           appstream  2.6 M
    glibc-devel              x86_64  2.28-158.el8                           baseos     1.0 M
    glibc-headers            x86_64  2.28-158.el8                           baseos     479 k
    isl                      x86_64  0.16.1-6.el8                           appstream  841 k
    kernel-headers           x86_64  4.18.0-408.el8                         baseos     9.8 M
    libmpc                   x86_64  1.1.0-9.1.el8                          appstream   61 k
    libpkgconf               x86_64  1.4.2-1.el8                            baseos      35 k
    libvirt-libs             x86_64  8.0.0-10.module_el8.7.0+1218+f626c2ff  appstream  4.7 M
    libxcrypt-devel          x86_64  4.1.1-6.el8                            baseos      25 k
    perl-Carp                noarch  1.42-396.el8                           baseos      30 k
    perl-Data-Dumper         x86_64  2.167-399.el8                          baseos      58 k
    perl-Digest              noarch  1.17-395.el8                           appstream   27 k
    perl-Digest-MD5          x86_64  2.55-396.el8                           appstream   37 k
    perl-Encode              x86_64  4:2.97-3.el8                           baseos     1.5 M
    perl-Errno               x86_64  1.28-421.el8                           baseos      76 k
    perl-Error               noarch  1:0.17025-2.el8                        appstream   46 k
    perl-Exporter            noarch  5.72-396.el8                           baseos      34 k
    perl-File-Path           noarch  2.15-2.el8                             baseos      38 k
    perl-File-Temp           noarch  0.230.600-1.el8                        baseos      63 k
    perl-Getopt-Long         noarch  1:2.50-4.el8                           baseos      63 k
    perl-Git                 noarch  2.31.1-2.el8                           appstream   78 k
    perl-HTTP-Tiny           noarch  0.074-1.el8                            baseos      58 k
    perl-IO                  x86_64  1.38-421.el8                           baseos     142 k
    perl-MIME-Base64         x86_64  3.15-396.el8                           baseos      31 k
    perl-Net-SSLeay          x86_64  1.88-1.module_el8.4.0+517+be1595ff     appstream  379 k
    perl-PathTools           x86_64  3.74-1.el8                             baseos      90 k
    perl-Pod-Escapes         noarch  1:1.07-395.el8                         baseos      20 k
    perl-Pod-Perldoc         noarch  3.28-396.el8                           baseos      86 k
    perl-Pod-Simple          noarch  1:3.35-395.el8                         baseos     213 k
    perl-Pod-Usage           noarch  4:1.69-395.el8                         baseos      34 k
    perl-Scalar-List-Utils   x86_64  3:1.49-2.el8                           baseos      68 k
    perl-Socket              x86_64  4:2.027-3.el8                          baseos      59 k
    perl-Storable            x86_64  1:3.11-3.el8                           baseos      98 k
    perl-Term-ANSIColor      noarch  4.06-396.el8                           baseos      46 k
    perl-Term-Cap            noarch  1.17-395.el8                           baseos      23 k
    perl-TermReadKey         x86_64  2.37-7.el8                             appstream   40 k
    perl-Text-ParseWords     noarch  3.30-395.el8                           baseos      18 k
    perl-Text-Tabs+Wrap      noarch  2013.0523-395.el8                      baseos      24 k
    perl-Time-Local          noarch  1:1.280-1.el8                          baseos      34 k
    perl-URI                 noarch  1.73-3.el8                             appstream  116 k
    perl-Unicode-Normalize   x86_64  1.25-396.el8                           baseos      82 k
    perl-constant            noarch  1.33-396.el8                           baseos      25 k
    perl-interpreter         x86_64  4:5.26.3-421.el8                       baseos     6.3 M
    perl-libnet              noarch  3.11-3.el8                             appstream  121 k
    perl-libs                x86_64  4:5.26.3-421.el8                       baseos     1.6 M
    perl-macros              x86_64  4:5.26.3-421.el8                       baseos      72 k
    perl-parent              noarch  1:0.237-1.el8                          baseos      20 k
    perl-podlators           noarch  4.11-1.el8                             baseos     118 k
    perl-threads             x86_64  1:2.21-2.el8                           baseos      61 k
    perl-threads-shared      x86_64  1.58-2.el8                             baseos      48 k
    pkgconf                  x86_64  1.4.2-1.el8                            baseos      38 k
    pkgconf-m4               noarch  1.4.2-1.el8                            baseos      17 k
    python3-pip              noarch  9.0.3-19.el8                           appstream   20 k
    python3-setuptools       noarch  39.2.0-6.el8                           baseos     163 k
    yajl                     x86_64  2.1.0-11.el8                           appstream   41 k
   Installing weak dependencies:
    perl-IO-Socket-IP        noarch  0.39-5.el8                             appstream   47 k
    perl-IO-Socket-SSL       noarch  2.066-4.module_el8.4.0+517+be1595ff    appstream  298 k
    perl-Mozilla-CA          noarch  20160104-7.module_el8.3.0+416+dee7bcef appstream   15 k
   Enabling module streams:
    perl                             5.26
    perl-IO-Socket-SSL               2.066
    perl-libwww-perl                 6.34
    python36                         3.6

   Transaction Summary
   =========================================================================================
   Install  71 Packages
   Upgrade   3 Packages

   Total download size: 78 M
   Downloading Packages:
   done.
   (1/74): git-2.31.1-2.el8.x86_64.rpm             832 kB/s | 161 kB     00:00
   (2/74): isl-0.16.1-6.el8.x86_64.rpm             6.4 MB/s | 841 kB     00:00
   (3/74): git-core-doc-2.31.1-2.el8.noarch.rpm    7.7 MB/s | 2.6 MB     00:00
   (4/74): libmpc-1.1.0-9.1.el8.x86_64.rpm         1.5 MB/s |  61 kB     00:00
   (5/74): git-core-2.31.1-2.el8.x86_64.rpm         12 MB/s | 4.7 MB     00:00
   (6/74): libvirt-devel-8.0.0-10.module_el8.7.0+1 4.1 MB/s | 248 kB     00:00
   (7/74): perl-Digest-1.17-395.el8.noarch.rpm     686 kB/s |  27 kB     00:00
   (8/74): perl-Digest-MD5-2.55-396.el8.x86_64.rpm 985 kB/s |  37 kB     00:00
   (9/74): perl-Error-0.17025-2.el8.noarch.rpm     1.1 MB/s |  46 kB     00:00
   (10/74): perl-Git-2.31.1-2.el8.noarch.rpm       1.9 MB/s |  78 kB     00:00
   (11/74): libvirt-libs-8.0.0-10.module_el8.7.0+1  30 MB/s | 4.7 MB     00:00
   (12/74): perl-IO-Socket-IP-0.39-5.el8.noarch.rp 940 kB/s |  47 kB     00:00
   (13/74): perl-IO-Socket-SSL-2.066-4.module_el8. 5.8 MB/s | 298 kB     00:00
   (14/74): perl-Mozilla-CA-20160104-7.module_el8. 403 kB/s |  15 kB     00:00
   (15/74): perl-TermReadKey-2.37-7.el8.x86_64.rpm 1.0 MB/s |  40 kB     00:00
   (16/74): perl-Net-SSLeay-1.88-1.module_el8.4.0+ 7.4 MB/s | 379 kB     00:00
   (17/74): perl-URI-1.73-3.el8.noarch.rpm         2.6 MB/s | 116 kB     00:00
   (18/74): perl-libnet-3.11-3.el8.noarch.rpm      3.0 MB/s | 121 kB     00:00
   (19/74): python3-libvirt-8.0.0-2.module_el8.7.0 7.1 MB/s | 332 kB     00:00
   (20/74): python3-netifaces-0.10.6-4.el8.x86_64. 644 kB/s |  25 kB     00:00
   (21/74): python3-pip-9.0.3-19.el8.noarch.rpm    530 kB/s |  20 kB     00:00
   (22/74): python36-3.6.8-38.module_el8.5.0+895+a 514 kB/s |  19 kB     00:00
   (23/74): yajl-2.1.0-11.el8.x86_64.rpm           1.0 MB/s |  41 kB     00:00
   (24/74): cyrus-sasl-2.1.27-5.el8.x86_64.rpm     2.2 MB/s |  96 kB     00:00
   (25/74): binutils-2.30-119.el8.x86_64.rpm        39 MB/s | 5.8 MB     00:00
   (26/74): cyrus-sasl-gssapi-2.1.27-5.el8.x86_64. 677 kB/s |  50 kB     00:00
   (27/74): emacs-filesystem-26.1-7.el8.noarch.rpm 1.7 MB/s |  70 kB     00:00
   (28/74): cpp-8.5.0-17.el8.x86_64.rpm             40 MB/s |  10 MB     00:00
   (29/74): glibc-devel-2.28-158.el8.x86_64.rpm     11 MB/s | 1.0 MB     00:00
   (30/74): glibc-headers-2.28-158.el8.x86_64.rpm  9.7 MB/s | 479 kB     00:00
   (31/74): libpkgconf-1.4.2-1.el8.x86_64.rpm      846 kB/s |  35 kB     00:00
   (32/74): libxcrypt-devel-4.1.1-6.el8.x86_64.rpm 646 kB/s |  25 kB     00:00
   (33/74): perl-Carp-1.42-396.el8.noarch.rpm      744 kB/s |  30 kB     00:00
   (34/74): kernel-headers-4.18.0-408.el8.x86_64.r  45 MB/s | 9.8 MB     00:00
   (35/74): perl-Data-Dumper-2.167-399.el8.x86_64. 952 kB/s |  58 kB     00:00
   (36/74): perl-Errno-1.28-421.el8.x86_64.rpm     1.8 MB/s |  76 kB     00:00
   (37/74): perl-Encode-2.97-3.el8.x86_64.rpm       23 MB/s | 1.5 MB     00:00
   (38/74): perl-Exporter-5.72-396.el8.noarch.rpm  836 kB/s |  34 kB     00:00
   (39/74): gcc-8.5.0-17.el8.x86_64.rpm             41 MB/s |  23 MB     00:00
   (40/74): perl-File-Path-2.15-2.el8.noarch.rpm   236 kB/s |  38 kB     00:00
   (41/74): perl-File-Temp-0.230.600-1.el8.noarch. 435 kB/s |  63 kB     00:00
   (42/74): perl-Getopt-Long-2.50-4.el8.noarch.rpm 1.5 MB/s |  63 kB     00:00
   (43/74): perl-HTTP-Tiny-0.074-1.el8.noarch.rpm  1.3 MB/s |  58 kB     00:00
   (44/74): perl-IO-1.38-421.el8.x86_64.rpm        3.2 MB/s | 142 kB     00:00
   (45/74): perl-MIME-Base64-3.15-396.el8.x86_64.r 782 kB/s |  31 kB     00:00
   (46/74): perl-PathTools-3.74-1.el8.x86_64.rpm   2.1 MB/s |  90 kB     00:00
   (47/74): perl-Pod-Escapes-1.07-395.el8.noarch.r 533 kB/s |  20 kB     00:00
   (48/74): perl-Pod-Perldoc-3.28-396.el8.noarch.r 2.0 MB/s |  86 kB     00:00
   (49/74): perl-Pod-Usage-1.69-395.el8.noarch.rpm 888 kB/s |  34 kB     00:00
   (50/74): perl-Pod-Simple-3.35-395.el8.noarch.rp 4.7 MB/s | 213 kB     00:00
   (51/74): perl-Scalar-List-Utils-1.49-2.el8.x86_ 1.6 MB/s |  68 kB     00:00
   (52/74): perl-Socket-2.027-3.el8.x86_64.rpm     1.4 MB/s |  59 kB     00:00
   (53/74): perl-Storable-3.11-3.el8.x86_64.rpm    2.4 MB/s |  98 kB     00:00
   (54/74): perl-Term-ANSIColor-4.06-396.el8.noarc 1.0 MB/s |  46 kB     00:00
   (55/74): perl-Term-Cap-1.17-395.el8.noarch.rpm  560 kB/s |  23 kB     00:00
   (56/74): perl-Text-ParseWords-3.30-395.el8.noar 454 kB/s |  18 kB     00:00
   (57/74): perl-Time-Local-1.280-1.el8.noarch.rpm 868 kB/s |  34 kB     00:00
   (58/74): perl-Text-Tabs+Wrap-2013.0523-395.el8. 602 kB/s |  24 kB     00:00
   (59/74): perl-Unicode-Normalize-1.25-396.el8.x8 1.9 MB/s |  82 kB     00:00
   (60/74): perl-constant-1.33-396.el8.noarch.rpm  663 kB/s |  25 kB     00:00
   (61/74): perl-libs-5.26.3-421.el8.x86_64.rpm     24 MB/s | 1.6 MB     00:00
   (62/74): perl-macros-5.26.3-421.el8.x86_64.rpm  1.7 MB/s |  72 kB     00:00
   (63/74): perl-parent-0.237-1.el8.noarch.rpm     521 kB/s |  20 kB     00:00
   (64/74): perl-podlators-4.11-1.el8.noarch.rpm   2.8 MB/s | 118 kB     00:00
   (65/74): perl-interpreter-5.26.3-421.el8.x86_64  40 MB/s | 6.3 MB     00:00
   (66/74): perl-threads-shared-1.58-2.el8.x86_64. 1.1 MB/s |  48 kB     00:00
   (67/74): perl-threads-2.21-2.el8.x86_64.rpm     1.1 MB/s |  61 kB     00:00
   (68/74): pkgconf-1.4.2-1.el8.x86_64.rpm         1.0 MB/s |  38 kB     00:00
   (69/74): pkgconf-m4-1.4.2-1.el8.noarch.rpm      435 kB/s |  17 kB     00:00
   (70/74): pkgconf-pkg-config-1.4.2-1.el8.x86_64. 407 kB/s |  15 kB     00:00
   (71/74): python3-setuptools-39.2.0-6.el8.noarch 3.7 MB/s | 163 kB     00:00
   (72/74): libgcc-8.5.0-17.el8.x86_64.rpm         1.9 MB/s |  81 kB     00:00
   (73/74): chkconfig-1.19.1-1.el8.x86_64.rpm      3.9 MB/s | 198 kB     00:00
   (74/74): libgomp-8.5.0-17.el8.x86_64.rpm        4.4 MB/s | 207 kB     00:00
   --------------------------------------------------------------------------------
   Total                                            34 MB/s |  78 MB     00:02
   warning: /var/cache/dnf/appstream-670736f27949a722/packages/git-2.31.1-2.el8.x86_64.rpm: Header V3 RSA/SHA256 Signature, key ID 8483c65d: NOKEY
   CentOS Stream 8 - AppStream                     1.6 MB/s | 1.6 kB     00:00
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
     Preparing        :                                                        1/1
     Upgrading        : libgcc-8.5.0-17.el8.x86_64                            1/77
     Running scriptlet: libgcc-8.5.0-17.el8.x86_64                            1/77
     Upgrading        : chkconfig-1.19.1-1.el8.x86_64                         2/77
     Installing       : libmpc-1.1.0-9.1.el8.x86_64                           3/77
     Installing       : git-core-2.31.1-2.el8.x86_64                          4/77
     Installing       : git-core-doc-2.31.1-2.el8.noarch                      5/77
     Installing       : cpp-8.5.0-17.el8.x86_64                               6/77
     Running scriptlet: cpp-8.5.0-17.el8.x86_64                               6/77
     Installing       : binutils-2.30-119.el8.x86_64                          7/77
     Running scriptlet: binutils-2.30-119.el8.x86_64                          7/77
     Running scriptlet: cyrus-sasl-2.1.27-5.el8.x86_64                        8/77
     Installing       : cyrus-sasl-2.1.27-5.el8.x86_64                        8/77
     Running scriptlet: cyrus-sasl-2.1.27-5.el8.x86_64                        8/77
     Installing       : perl-Digest-1.17-395.el8.noarch                       9/77
     Installing       : perl-Digest-MD5-2.55-396.el8.x86_64                  10/77
     Installing       : perl-Data-Dumper-2.167-399.el8.x86_64                11/77
     Installing       : perl-libnet-3.11-3.el8.noarch                        12/77
     Installing       : perl-Net-SSLeay-1.88-1.module_el8.4.0+517+be1595ff   13/77
     Installing       : perl-URI-1.73-3.el8.noarch                           14/77
     Installing       : perl-Pod-Escapes-1:1.07-395.el8.noarch               15/77
     Installing       : perl-Mozilla-CA-20160104-7.module_el8.3.0+416+dee7   16/77
     Installing       : perl-IO-Socket-IP-0.39-5.el8.noarch                  17/77
     Installing       : perl-Time-Local-1:1.280-1.el8.noarch                 18/77
     Installing       : perl-IO-Socket-SSL-2.066-4.module_el8.4.0+517+be15   19/77
     Installing       : perl-Term-ANSIColor-4.06-396.el8.noarch              20/77
     Installing       : perl-Term-Cap-1.17-395.el8.noarch                    21/77
     Installing       : perl-File-Temp-0.230.600-1.el8.noarch                22/77
     Installing       : perl-Pod-Simple-1:3.35-395.el8.noarch                23/77
     Installing       : perl-HTTP-Tiny-0.074-1.el8.noarch                    24/77
     Installing       : perl-podlators-4.11-1.el8.noarch                     25/77
     Installing       : perl-Pod-Perldoc-3.28-396.el8.noarch                 26/77
     Installing       : perl-Text-ParseWords-3.30-395.el8.noarch             27/77
     Installing       : perl-Pod-Usage-4:1.69-395.el8.noarch                 28/77
     Installing       : perl-MIME-Base64-3.15-396.el8.x86_64                 29/77
     Installing       : perl-Storable-1:3.11-3.el8.x86_64                    30/77
     Installing       : perl-Getopt-Long-1:2.50-4.el8.noarch                 31/77
     Installing       : perl-Errno-1.28-421.el8.x86_64                       32/77
     Installing       : perl-Socket-4:2.027-3.el8.x86_64                     33/77
     Installing       : perl-Encode-4:2.97-3.el8.x86_64                      34/77
     Installing       : perl-Carp-1.42-396.el8.noarch                        35/77
     Installing       : perl-Exporter-5.72-396.el8.noarch                    36/77
     Installing       : perl-libs-4:5.26.3-421.el8.x86_64                    37/77
     Installing       : perl-Scalar-List-Utils-3:1.49-2.el8.x86_64           38/77
     Installing       : perl-parent-1:0.237-1.el8.noarch                     39/77
     Installing       : perl-macros-4:5.26.3-421.el8.x86_64                  40/77
     Installing       : perl-Text-Tabs+Wrap-2013.0523-395.el8.noarch         41/77
     Installing       : perl-Unicode-Normalize-1.25-396.el8.x86_64           42/77
     Installing       : perl-File-Path-2.15-2.el8.noarch                     43/77
     Installing       : perl-IO-1.38-421.el8.x86_64                          44/77
     Installing       : perl-PathTools-3.74-1.el8.x86_64                     45/77
     Installing       : perl-constant-1.33-396.el8.noarch                    46/77
     Installing       : perl-threads-1:2.21-2.el8.x86_64                     47/77
     Installing       : perl-threads-shared-1.58-2.el8.x86_64                48/77
     Installing       : perl-interpreter-4:5.26.3-421.el8.x86_64             49/77
     Installing       : perl-Error-1:0.17025-2.el8.noarch                    50/77
     Installing       : perl-TermReadKey-2.37-7.el8.x86_64                   51/77
     Upgrading        : libgomp-8.5.0-17.el8.x86_64                          52/77
     Running scriptlet: libgomp-8.5.0-17.el8.x86_64                          52/77
     Installing       : python3-setuptools-39.2.0-6.el8.noarch               53/77
     Installing       : python36-3.6.8-38.module_el8.5.0+895+a459eca8.x86_   54/77
     Running scriptlet: python36-3.6.8-38.module_el8.5.0+895+a459eca8.x86_   54/77
     Installing       : python3-pip-9.0.3-19.el8.noarch                      55/77
     Installing       : pkgconf-m4-1.4.2-1.el8.noarch                        56/77
     Installing       : libpkgconf-1.4.2-1.el8.x86_64                        57/77
     Installing       : pkgconf-1.4.2-1.el8.x86_64                           58/77
     Installing       : pkgconf-pkg-config-1.4.2-1.el8.x86_64                59/77
     Installing       : kernel-headers-4.18.0-408.el8.x86_64                 60/77
     Running scriptlet: glibc-headers-2.28-158.el8.x86_64                    61/77
     Installing       : glibc-headers-2.28-158.el8.x86_64                    61/77
     Installing       : libxcrypt-devel-4.1.1-6.el8.x86_64                   62/77
     Installing       : glibc-devel-2.28-158.el8.x86_64                      63/77
     Running scriptlet: glibc-devel-2.28-158.el8.x86_64                      63/77
     Installing       : emacs-filesystem-1:26.1-7.el8.noarch                 64/77
     Installing       : perl-Git-2.31.1-2.el8.noarch                         65/77
     Installing       : git-2.31.1-2.el8.x86_64                              66/77
     Installing       : cyrus-sasl-gssapi-2.1.27-5.el8.x86_64                67/77
     Installing       : yajl-2.1.0-11.el8.x86_64                             68/77
     Installing       : libvirt-libs-8.0.0-10.module_el8.7.0+1218+f626c2ff   69/77
     Installing       : isl-0.16.1-6.el8.x86_64                              70/77
     Running scriptlet: isl-0.16.1-6.el8.x86_64                              70/77
     Installing       : gcc-8.5.0-17.el8.x86_64                              71/77
     Running scriptlet: gcc-8.5.0-17.el8.x86_64                              71/77
     Installing       : libvirt-devel-8.0.0-10.module_el8.7.0+1218+f626c2f   72/77
     Installing       : python3-libvirt-8.0.0-2.module_el8.7.0+1218+f626c2   73/77
     Installing       : python3-netifaces-0.10.6-4.el8.x86_64                74/77
     Running scriptlet: libgomp-8.5.0-1.el8.x86_64                           75/77
     Cleanup          : libgomp-8.5.0-1.el8.x86_64                           75/77
     Running scriptlet: libgomp-8.5.0-1.el8.x86_64                           75/77
     Cleanup          : libgcc-8.5.0-1.el8.x86_64                            76/77
     Running scriptlet: libgcc-8.5.0-1.el8.x86_64                            76/77
     Cleanup          : chkconfig-1.13-2.el8.x86_64                          77/77
     Running scriptlet: chkconfig-1.13-2.el8.x86_64                          77/77
     Verifying        : git-2.31.1-2.el8.x86_64                               1/77
     Verifying        : git-core-2.31.1-2.el8.x86_64                          2/77
     Verifying        : git-core-doc-2.31.1-2.el8.noarch                      3/77
     Verifying        : isl-0.16.1-6.el8.x86_64                               4/77
     Verifying        : libmpc-1.1.0-9.1.el8.x86_64                           5/77
     Verifying        : libvirt-devel-8.0.0-10.module_el8.7.0+1218+f626c2f    6/77
     Verifying        : libvirt-libs-8.0.0-10.module_el8.7.0+1218+f626c2ff    7/77
     Verifying        : perl-Digest-1.17-395.el8.noarch                       8/77
     Verifying        : perl-Digest-MD5-2.55-396.el8.x86_64                   9/77
     Verifying        : perl-Error-1:0.17025-2.el8.noarch                    10/77
     Verifying        : perl-Git-2.31.1-2.el8.noarch                         11/77
     Verifying        : perl-IO-Socket-IP-0.39-5.el8.noarch                  12/77
     Verifying        : perl-IO-Socket-SSL-2.066-4.module_el8.4.0+517+be15   13/77
     Verifying        : perl-Mozilla-CA-20160104-7.module_el8.3.0+416+dee7   14/77
     Verifying        : perl-Net-SSLeay-1.88-1.module_el8.4.0+517+be1595ff   15/77
     Verifying        : perl-TermReadKey-2.37-7.el8.x86_64                   16/77
     Verifying        : perl-URI-1.73-3.el8.noarch                           17/77
     Verifying        : perl-libnet-3.11-3.el8.noarch                        18/77
     Verifying        : python3-libvirt-8.0.0-2.module_el8.7.0+1218+f626c2   19/77
     Verifying        : python3-netifaces-0.10.6-4.el8.x86_64                20/77
     Verifying        : python3-pip-9.0.3-19.el8.noarch                      21/77
     Verifying        : python36-3.6.8-38.module_el8.5.0+895+a459eca8.x86_   22/77
     Verifying        : yajl-2.1.0-11.el8.x86_64                             23/77
     Verifying        : binutils-2.30-119.el8.x86_64                         24/77
     Verifying        : cpp-8.5.0-17.el8.x86_64                              25/77
     Verifying        : cyrus-sasl-2.1.27-5.el8.x86_64                       26/77
     Verifying        : cyrus-sasl-gssapi-2.1.27-5.el8.x86_64                27/77
     Verifying        : emacs-filesystem-1:26.1-7.el8.noarch                 28/77
     Verifying        : gcc-8.5.0-17.el8.x86_64                              29/77
     Verifying        : glibc-devel-2.28-158.el8.x86_64                      30/77
     Verifying        : glibc-headers-2.28-158.el8.x86_64                    31/77
     Verifying        : kernel-headers-4.18.0-408.el8.x86_64                 32/77
     Verifying        : libpkgconf-1.4.2-1.el8.x86_64                        33/77
     Verifying        : libxcrypt-devel-4.1.1-6.el8.x86_64                   34/77
     Verifying        : perl-Carp-1.42-396.el8.noarch                        35/77
     Verifying        : perl-Data-Dumper-2.167-399.el8.x86_64                36/77
     Verifying        : perl-Encode-4:2.97-3.el8.x86_64                      37/77
     Verifying        : perl-Errno-1.28-421.el8.x86_64                       38/77
     Verifying        : perl-Exporter-5.72-396.el8.noarch                    39/77
     Verifying        : perl-File-Path-2.15-2.el8.noarch                     40/77
     Verifying        : perl-File-Temp-0.230.600-1.el8.noarch                41/77
     Verifying        : perl-Getopt-Long-1:2.50-4.el8.noarch                 42/77
     Verifying        : perl-HTTP-Tiny-0.074-1.el8.noarch                    43/77
     Verifying        : perl-IO-1.38-421.el8.x86_64                          44/77
     Verifying        : perl-MIME-Base64-3.15-396.el8.x86_64                 45/77
     Verifying        : perl-PathTools-3.74-1.el8.x86_64                     46/77
     Verifying        : perl-Pod-Escapes-1:1.07-395.el8.noarch               47/77
     Verifying        : perl-Pod-Perldoc-3.28-396.el8.noarch                 48/77
     Verifying        : perl-Pod-Simple-1:3.35-395.el8.noarch                49/77
     Verifying        : perl-Pod-Usage-4:1.69-395.el8.noarch                 50/77
     Verifying        : perl-Scalar-List-Utils-3:1.49-2.el8.x86_64           51/77
     Verifying        : perl-Socket-4:2.027-3.el8.x86_64                     52/77
     Verifying        : perl-Storable-1:3.11-3.el8.x86_64                    53/77
     Verifying        : perl-Term-ANSIColor-4.06-396.el8.noarch              54/77
     Verifying        : perl-Term-Cap-1.17-395.el8.noarch                    55/77
     Verifying        : perl-Text-ParseWords-3.30-395.el8.noarch             56/77
     Verifying        : perl-Text-Tabs+Wrap-2013.0523-395.el8.noarch         57/77
     Verifying        : perl-Time-Local-1:1.280-1.el8.noarch                 58/77
     Verifying        : perl-Unicode-Normalize-1.25-396.el8.x86_64           59/77
     Verifying        : perl-constant-1.33-396.el8.noarch                    60/77
     Verifying        : perl-interpreter-4:5.26.3-421.el8.x86_64             61/77
     Verifying        : perl-libs-4:5.26.3-421.el8.x86_64                    62/77
     Verifying        : perl-macros-4:5.26.3-421.el8.x86_64                  63/77
     Verifying        : perl-parent-1:0.237-1.el8.noarch                     64/77
     Verifying        : perl-podlators-4.11-1.el8.noarch                     65/77
     Verifying        : perl-threads-1:2.21-2.el8.x86_64                     66/77
     Verifying        : perl-threads-shared-1.58-2.el8.x86_64                67/77
     Verifying        : pkgconf-1.4.2-1.el8.x86_64                           68/77
     Verifying        : pkgconf-m4-1.4.2-1.el8.noarch                        69/77
     Verifying        : pkgconf-pkg-config-1.4.2-1.el8.x86_64                70/77
     Verifying        : python3-setuptools-39.2.0-6.el8.noarch               71/77
     Verifying        : chkconfig-1.19.1-1.el8.x86_64                        72/77
     Verifying        : chkconfig-1.13-2.el8.x86_64                          73/77
     Verifying        : libgcc-8.5.0-17.el8.x86_64                           74/77
     Verifying        : libgcc-8.5.0-1.el8.x86_64                            75/77
     Verifying        : libgomp-8.5.0-17.el8.x86_64                          76/77
     Verifying        : libgomp-8.5.0-1.el8.x86_64                           77/77

   Upgraded:
     chkconfig-1.19.1-1.el8.x86_64            libgcc-8.5.0-17.el8.x86_64
     libgomp-8.5.0-17.el8.x86_64
   Installed:
     binutils-2.30-119.el8.x86_64
     cpp-8.5.0-17.el8.x86_64
     cyrus-sasl-2.1.27-5.el8.x86_64
     cyrus-sasl-gssapi-2.1.27-5.el8.x86_64
     emacs-filesystem-1:26.1-7.el8.noarch
     gcc-8.5.0-17.el8.x86_64
     git-2.31.1-2.el8.x86_64
     git-core-2.31.1-2.el8.x86_64
     git-core-doc-2.31.1-2.el8.noarch
     glibc-devel-2.28-158.el8.x86_64
     glibc-headers-2.28-158.el8.x86_64
     isl-0.16.1-6.el8.x86_64
     kernel-headers-4.18.0-408.el8.x86_64
     libmpc-1.1.0-9.1.el8.x86_64
     libpkgconf-1.4.2-1.el8.x86_64
     libvirt-devel-8.0.0-10.module_el8.7.0+1218+f626c2ff.x86_64
     libvirt-libs-8.0.0-10.module_el8.7.0+1218+f626c2ff.x86_64
     libxcrypt-devel-4.1.1-6.el8.x86_64
     perl-Carp-1.42-396.el8.noarch
     perl-Data-Dumper-2.167-399.el8.x86_64
     perl-Digest-1.17-395.el8.noarch
     perl-Digest-MD5-2.55-396.el8.x86_64
     perl-Encode-4:2.97-3.el8.x86_64
     perl-Errno-1.28-421.el8.x86_64
     perl-Error-1:0.17025-2.el8.noarch
     perl-Exporter-5.72-396.el8.noarch
     perl-File-Path-2.15-2.el8.noarch
     perl-File-Temp-0.230.600-1.el8.noarch
     perl-Getopt-Long-1:2.50-4.el8.noarch
     perl-Git-2.31.1-2.el8.noarch
     perl-HTTP-Tiny-0.074-1.el8.noarch
     perl-IO-1.38-421.el8.x86_64
     perl-IO-Socket-IP-0.39-5.el8.noarch
     perl-IO-Socket-SSL-2.066-4.module_el8.4.0+517+be1595ff.noarch
     perl-MIME-Base64-3.15-396.el8.x86_64
     perl-Mozilla-CA-20160104-7.module_el8.3.0+416+dee7bcef.noarch
     perl-Net-SSLeay-1.88-1.module_el8.4.0+517+be1595ff.x86_64
     perl-PathTools-3.74-1.el8.x86_64
     perl-Pod-Escapes-1:1.07-395.el8.noarch
     perl-Pod-Perldoc-3.28-396.el8.noarch
     perl-Pod-Simple-1:3.35-395.el8.noarch
     perl-Pod-Usage-4:1.69-395.el8.noarch
     perl-Scalar-List-Utils-3:1.49-2.el8.x86_64
     perl-Socket-4:2.027-3.el8.x86_64
     perl-Storable-1:3.11-3.el8.x86_64
     perl-Term-ANSIColor-4.06-396.el8.noarch
     perl-Term-Cap-1.17-395.el8.noarch
     perl-TermReadKey-2.37-7.el8.x86_64
     perl-Text-ParseWords-3.30-395.el8.noarch
     perl-Text-Tabs+Wrap-2013.0523-395.el8.noarch
     perl-Time-Local-1:1.280-1.el8.noarch
     perl-URI-1.73-3.el8.noarch
     perl-Unicode-Normalize-1.25-396.el8.x86_64
     perl-constant-1.33-396.el8.noarch
     perl-interpreter-4:5.26.3-421.el8.x86_64
     perl-libnet-3.11-3.el8.noarch
     perl-libs-4:5.26.3-421.el8.x86_64
     perl-macros-4:5.26.3-421.el8.x86_64
     perl-parent-1:0.237-1.el8.noarch
     perl-podlators-4.11-1.el8.noarch
     perl-threads-1:2.21-2.el8.x86_64
     perl-threads-shared-1.58-2.el8.x86_64
     pkgconf-1.4.2-1.el8.x86_64
     pkgconf-m4-1.4.2-1.el8.noarch
     pkgconf-pkg-config-1.4.2-1.el8.x86_64
     python3-libvirt-8.0.0-2.module_el8.7.0+1218+f626c2ff.x86_64
     python3-netifaces-0.10.6-4.el8.x86_64
     python3-pip-9.0.3-19.el8.noarch
     python3-setuptools-39.2.0-6.el8.noarch
     python36-3.6.8-38.module_el8.5.0+895+a459eca8.x86_64
     yajl-2.1.0-11.el8.x86_64

   Complete!
   Repository successfully enabled.
   Enabling a Copr repository. Please note that this repository is not part
   of the main distribution, and quality may vary.

   The Fedora Project does not exercise any power over the contents of
   this repository beyond the rules outlined in the Copr FAQ at
   <https://docs.pagure.org/copr.copr/user_documentation.html#what-i-can-build-in-copr>,
   and packages are not held to any quality or security level.

   Please do not file bug reports about these packages in Fedora
   Bugzilla. In case of problems, contact the owner of this repository.
   Copr repo for kcli owned by karmab              650 kB/s | 460 kB     00:00
   Dependencies resolved.
   ======================================================================================================================
    Package               Arch    Version                               Repository                                   Size
   ======================================================================================================================
   Installing:
    kcli                  x86_64  99.0.0.git.202212221141.5db1259-0.el8 copr:copr.fedorainfracloud.org:karmab:kcli  1.5 M
   Installing dependencies:
    genisoimage           x86_64  1.1.11-39.el8                         appstream                                   316 k
    libusal               x86_64  1.1.11-39.el8                         appstream                                   145 k
    nmap-ncat             x86_64  2:7.70-8.el8                          appstream                                   237 k
    python3-argcomplete   noarch  1.9.3-6.el8                           appstream                                    60 k

   Transaction Summary
   ======================================================================================================================
   Install  5 Packages

   Total download size: 2.2 M
   Installed size: 7.9 M
   Downloading Packages:
   (1/5): libusal-1.1.11-39.el8.x86_64.rpm         719 kB/s | 145 kB     00:00
   (2/5): nmap-ncat-7.70-8.el8.x86_64.rpm          1.1 MB/s | 237 kB     00:00
   (3/5): genisoimage-1.1.11-39.el8.x86_64.rpm     1.4 MB/s | 316 kB     00:00
   (4/5): python3-argcomplete-1.9.3-6.el8.noarch.r 1.3 MB/s |  60 kB     00:00
   (5/5): kcli-99.0.0.git.202212221141.5db1259-0.e 3.1 MB/s | 1.5 MB     00:00
   --------------------------------------------------------------------------------
   Total                                           2.3 MB/s | 2.2 MB     00:00
   warning: /var/cache/dnf/copr:copr.fedorainfracloud.org:karmab:kcli-6ab16b9905451db5/packages/kcli-99.0.0.git.202212221141.5db1259-0.el8.x86_64.rpm: Header V4 RSA/SHA256 Signature, key ID b99058cd: NOKEY
   Copr repo for kcli owned by karmab              3.3 kB/s | 989  B     00:00
   Importing GPG key 0xB99058CD:
    Userid     : "karmab_kcli (None) <karmab#kcli@copr.fedorahosted.org>"
    Fingerprint: E6AD 39AD 8660 3916 68EB 0AC2 D8C8 4386 B990 58CD
    From       : https://download.copr.fedorainfracloud.org/results/karmab/kcli/pubkey.gpg
   Key imported successfully
   Running transaction check
   Transaction check succeeded.
   Running transaction test
   Transaction test succeeded.
   Running transaction
     Preparing        :                                                        1/1
     Installing       : python3-argcomplete-1.9.3-6.el8.noarch                 1/5
     Installing       : nmap-ncat-2:7.70-8.el8.x86_64                          2/5
     Running scriptlet: nmap-ncat-2:7.70-8.el8.x86_64                          2/5
     Installing       : libusal-1.1.11-39.el8.x86_64                           3/5
     Running scriptlet: libusal-1.1.11-39.el8.x86_64                           3/5
     Installing       : genisoimage-1.1.11-39.el8.x86_64                       4/5
     Running scriptlet: genisoimage-1.1.11-39.el8.x86_64                       4/5
     Installing       : kcli-99.0.0.git.202212221141.5db1259-0.el8.x86_64      5/5
     Running scriptlet: kcli-99.0.0.git.202212221141.5db1259-0.el8.x86_64      5/5
     Verifying        : genisoimage-1.1.11-39.el8.x86_64                       1/5
     Verifying        : libusal-1.1.11-39.el8.x86_64                           2/5
     Verifying        : nmap-ncat-2:7.70-8.el8.x86_64                          3/5
     Verifying        : python3-argcomplete-1.9.3-6.el8.noarch                 4/5
     Verifying        : kcli-99.0.0.git.202212221141.5db1259-0.el8.x86_64      5/5

   Installed:
     genisoimage-1.1.11-39.el8.x86_64
     kcli-99.0.0.git.202212221141.5db1259-0.el8.x86_64
     libusal-1.1.11-39.el8.x86_64
     nmap-ncat-2:7.70-8.el8.x86_64
     python3-argcomplete-1.9.3-6.el8.noarch

   Complete!
   The unit files have no installation config (WantedBy, RequiredBy, Also, Alias
   settings in the [Install] section, and DefaultInstance for template units).
   This means they are not meant to be enabled using systemctl.
   Possible reasons for having this kind of units are:
   1) A unit may be statically enabled by being symlinked from another unit's
      .wants/ or .requires/ directory.
   2) A unit's purpose may be to act as a helper for some other unit which has
      a requirement dependency on it.
   3) A unit may be started when needed via activation (socket, path, timer,
      D-Bus, udev, scripted systemctl call, ...).
   4) In case of template units, the unit is meant to be enabled with some
      instance name specified.
   # 192.168.129.20:22 SSH-2.0-OpenSSH_8.0
   # 192.168.129.21:22 SSH-2.0-OpenSSH_8.0
   # 192.168.129.22:22 SSH-2.0-OpenSSH_8.0

This script performs the following tasks:

-  Install libvirt requirements as needed by the installer.
-  Installl kcli so that ksushy gets installed and enable the corresponding service
-  Patch the install-config.yaml so that the ip of the installer is used to reach said service

Ksushy allows us to manage those virtual nodes as if they were physical through Redfish protocol.

It’s similar to sushy-emulator but uses more user friendly URLS and have support for additional hypervisors (Vsphere and Kubevirt in particular)

For instance, we can check all the redfish information of our first ctlplane:

::

   REDFISH_ADDRESS=$(grep -m 1 redfish-virtualmedia /root/install-config.yaml | sed 's/address: redfish-virtualmedia+//')
   echo $REDFISH_ADDRESS
   curl $REDFISH_ADDRESS

Expected Output

::

   {
       "@odata.type": "#ComputerSystem.v1_1_0.ComputerSystem",
       "Id": "1",
       "Name": "lab-ctlplane-0",
       "UUID": "1",
       "Manufacturer": "kvm",
       "Status": {
           "State": "Enabled",
           "Health": "OK",
           "HealthRollUp": "OK"
       },
       "PowerState": "On",
       "Boot": {
           "BootSourceOverrideEnabled": "Continuous",
           "BootSourceOverrideTarget": "Hdd",
           "BootSourceOverrideTarget@Redfish.AllowableValues": [
               "Pxe",
               "Cd",
               "Hdd"
           ],
           "BootSourceOverrideMode": "UEFI",
           "UefiTargetBootSourceOverride": "/0x31/0x33/0x01/0x01"
       },
       "ProcessorSummary": {
           "Count": 8,
           "Status": {
               "State": "Enabled",
               "Health": "OK",
               "HealthRollUp": "OK"
           }
       },
       "MemorySummary": {
           "TotalSystemMemoryGiB": 16384,
           "Status": {
               "State": "Enabled",
               "Health": "OK",
               "HealthRollUp": "OK"
           }
       },
       "Bios": {
           "@odata.id": "/redfish/v1/Systems/kcli/lab-ctlplane-0/BIOS"
       },
       "Processors": {
           "@odata.id": "/redfish/v1/Systems/kcli/lab-ctlplane-0/Processors"
       },
       "Memory": {
           "@odata.id": "/redfish/v1/Systems/kcli/lab-ctlplane-0/Memory"
       },
       "EthernetInterfaces": {
           "@odata.id": "/redfish/v1/Systems/kcli/lab-ctlplane-0/EthernetInterfaces"
       },
       "SimpleStorage": {
           "@odata.id": "/redfish/v1/Systems/kcli/lab-ctlplane-0/SimpleStorage"
       },
       "Storage": {
           "@odata.id": "/redfish/v1/Systems/kcli/lab-ctlplane-0/Storage"
       },
       "IndicatorLED": "Lit",
       "Links": {
           "Chassis": [
               {
                   "@odata.id": "/redfish/v1/Chassis/fake-chassis"
               }
               ],
           "ManagedBy": [
               {
                   "@odata.id": "/redfish/v1/Managers/kcli/lab-ctlplane-0"
               }
               ]
       },
       "Actions": {
           "#ComputerSystem.Reset": {
               "target": "/redfish/v1/Systems/kcli/lab-ctlplane-0/Actions/ComputerSystem.Reset",
               "ResetType@Redfish.AllowableValues": [
                   "On",
                   "ForceOff",
                   "GracefulShutdown",
                   "GracefulRestart",
                   "ForceRestart",
                   "Nmi",
                   "ForceOn"
               ]
           }
       },
       "@odata.context": "/redfish/v1/$metadata#ComputerSystem.ComputerSystem",
       "@odata.id": "/redfish/v1/Systems/kcli/lab-ctlplane-0",
       "@Redfish.Copyright": "Copyright 2014-2016 Distributed Management Task Force, Inc. (DMTF). For the full DMTF copyright policy, see http://www.dmtf.org/about/policies/copyright."
   }

Futhermore, the helper script ``redfish.py`` can be used to report power status of all the nodes defined in *install-config.yaml*

::

   redfish.py status

Expected Output

::

   lab-ctlplane-0: Off
   lab-ctlplane-1: Off
   lab-ctlplane-2: Off

We will use this same script when deploying Openshift to make sure all the nodes are powered off prior to launching deployment.

In a full baremetal setup, ksushy wouldn’t be used but only access through Redfish to the nodes of the install. The helper script is still usable in this context.

Initial installconfig modifications
===================================

In this section, we do a basic patching of install-config.yaml to add mandatory elements to it:

::

   /root/scripts/01_patch_installconfig.sh

Expected Output

::

   # 192.168.129.20:22 SSH-2.0-OpenSSH_8.0
   # 192.168.129:21:22 SSH-2.0-OpenSSH_8.0
   # 192.168.129.22:22 SSH-2.0-OpenSSH_8.0

This script adds pull secret and public key to *install-config.yaml*.

Package requisites
==================

In this section, we add some required packages:

::

   /root/scripts/02_packages.sh

Expected Output

::

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

Beyond typical packages, we also install openstack ironic client.

openstack client is not strictly needed, since ironic is to be seen as an implementation detail for the installer, but this is still helpful to troubleshoot progress of the ctlplanes or workers deployment.

Binaries retrieval
==================

In this section, we fetch binaries required for the install:

::

   /root/scripts/02_packages.sh

Expected Output

::

   real    0m5.304s
   user    0m0.240s
   sys 0m0.285s
     % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                    Dload  Upload   Total   Spent    Left  Speed
   100 44.7M  100 44.7M    0     0  56.7M      0 --:--:-- --:--:-- --:--:-- 56.7M
   LICENSE
   kubectl-neat

The script downloads the following objects:

-  oc
-  kubectl.
-  openshift-install using oc and by specifying which OPENSHIFT_RELEASE_IMAGE to use.
-  neat which is a k8s plugin to clear managedfields from output
-  bmo-log-parser which is a tool for parsing metal3 baremetal-operator logs

Images caching
==============

In this section, we gather rhcos images needed for the install to speed up deployment time:

::

   /root/scripts/03_cache.sh

Expected Output

::

   Last metadata expiration check: 0:11:53 ago on Fri 26 Nov 2021 09:00:26 AM UTC.
   Dependencies resolved.
   ====================================================================================================================================================================================================================
    Package                                            Architecture                           Version                                                                  Repository                                 Size
   ====================================================================================================================================================================================================================
   Installing:
    httpd                                              x86_64                                 2.4.37-43.module_el8.5.0+1022+b541f3b1                                   appstream                                 1.4 M
   Installing dependencies:
    apr                                                x86_64                                 1.6.3-12.el8                                                             appstream                                 129 k
    apr-util                                           x86_64                                 1.6.1-6.el8                                                              appstream                                 105 k
    centos-logos-httpd                                 noarch                                 85.8-2.el8                                                               baseos                                     75 k
    httpd-filesystem                                   noarch                                 2.4.37-43.module_el8.5.0+1022+b541f3b1                                   appstream                                  39 k
    httpd-tools                                        x86_64                                 2.4.37-43.module_el8.5.0+1022+b541f3b1                                   appstream                                 107 k
    mailcap                                            noarch                                 2.1.48-3.el8                                                             baseos                                     39 k
    mod_http2                                          x86_64                                 1.15.7-3.module_el8.4.0+778+c970deab                                     appstream                                 154 k
   Installing weak dependencies:
    apr-util-bdb                                       x86_64                                 1.6.1-6.el8                                                              appstream                                  25 k
    apr-util-openssl                                   x86_64                                 1.6.1-6.el8                                                              appstream                                  27 k
   Enabling module streams:
    httpd                                                                                     2.4

   Transaction Summary
   ====================================================================================================================================================================================================================
   Install  10 Packages

   Total download size: 2.1 M
   Installed size: 5.6 M
   Downloading Packages:
   (1/10): apr-1.6.3-12.el8.x86_64.rpm                                                                                                                                                 1.1 MB/s | 129 kB     00:00
   (2/10): apr-util-bdb-1.6.1-6.el8.x86_64.rpm                                                                                                                                         196 kB/s |  25 kB     00:00
   (3/10): apr-util-1.6.1-6.el8.x86_64.rpm                                                                                                                                             587 kB/s | 105 kB     00:00
   (4/10): httpd-filesystem-2.4.37-43.module_el8.5.0+1022+b541f3b1.noarch.rpm                                                                                                          2.5 MB/s |  39 kB     00:00
   (5/10): httpd-tools-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64.rpm                                                                                                               1.4 MB/s | 107 kB     00:00
   (6/10): apr-util-openssl-1.6.1-6.el8.x86_64.rpm                                                                                                                                     155 kB/s |  27 kB     00:00
   (7/10): centos-logos-httpd-85.8-2.el8.noarch.rpm                                                                                                                                    5.1 MB/s |  75 kB     00:00
   (8/10): mailcap-2.1.48-3.el8.noarch.rpm                                                                                                                                             7.2 MB/s |  39 kB     00:00
   (9/10): httpd-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64.rpm                                                                                                                     6.9 MB/s | 1.4 MB     00:00
   (10/10): mod_http2-1.15.7-3.module_el8.4.0+778+c970deab.x86_64.rpm                                                                                                                  1.7 MB/s | 154 kB     00:00
   --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Total                                                                                                                                                                               3.3 MB/s | 2.1 MB     00:00
   Running transaction check
   Transaction check succeeded.
   Running transaction test
   Transaction test succeeded.
   Running transaction
     Preparing        :                                                                                                                                                                                            1/1
     Installing       : apr-1.6.3-12.el8.x86_64                                                                                                                                                                   1/10
     Running scriptlet: apr-1.6.3-12.el8.x86_64                                                                                                                                                                   1/10
     Installing       : apr-util-bdb-1.6.1-6.el8.x86_64                                                                                                                                                           2/10
     Installing       : apr-util-openssl-1.6.1-6.el8.x86_64                                                                                                                                                       3/10
     Installing       : apr-util-1.6.1-6.el8.x86_64                                                                                                                                                               4/10
     Running scriptlet: apr-util-1.6.1-6.el8.x86_64                                                                                                                                                               4/10
     Installing       : httpd-tools-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64                                                                                                                                 5/10
     Installing       : mailcap-2.1.48-3.el8.noarch                                                                                                                                                               6/10
     Installing       : centos-logos-httpd-85.8-2.el8.noarch                                                                                                                                                      7/10
     Running scriptlet: httpd-filesystem-2.4.37-43.module_el8.5.0+1022+b541f3b1.noarch                                                                                                                            8/10
     Installing       : httpd-filesystem-2.4.37-43.module_el8.5.0+1022+b541f3b1.noarch                                                                                                                            8/10
     Installing       : mod_http2-1.15.7-3.module_el8.4.0+778+c970deab.x86_64                                                                                                                                     9/10
     Installing       : httpd-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64                                                                                                                                      10/10
     Running scriptlet: httpd-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64                                                                                                                                      10/10
     Verifying        : apr-1.6.3-12.el8.x86_64                                                                                                                                                                   1/10
     Verifying        : apr-util-1.6.1-6.el8.x86_64                                                                                                                                                               2/10
     Verifying        : apr-util-bdb-1.6.1-6.el8.x86_64                                                                                                                                                           3/10
     Verifying        : apr-util-openssl-1.6.1-6.el8.x86_64                                                                                                                                                       4/10
     Verifying        : httpd-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64                                                                                                                                       5/10
     Verifying        : httpd-filesystem-2.4.37-43.module_el8.5.0+1022+b541f3b1.noarch                                                                                                                            6/10
     Verifying        : httpd-tools-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64                                                                                                                                 7/10
     Verifying        : mod_http2-1.15.7-3.module_el8.4.0+778+c970deab.x86_64                                                                                                                                     8/10
     Verifying        : centos-logos-httpd-85.8-2.el8.noarch                                                                                                                                                      9/10
     Verifying        : mailcap-2.1.48-3.el8.noarch                                                                                                                                                              10/10

   Installed:
     apr-1.6.3-12.el8.x86_64                                                    apr-util-1.6.1-6.el8.x86_64                                           apr-util-bdb-1.6.1-6.el8.x86_64
     apr-util-openssl-1.6.1-6.el8.x86_64                                        centos-logos-httpd-85.8-2.el8.noarch                                  httpd-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64
     httpd-filesystem-2.4.37-43.module_el8.5.0+1022+b541f3b1.noarch             httpd-tools-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64             mailcap-2.1.48-3.el8.noarch
     mod_http2-1.15.7-3.module_el8.4.0+778+c970deab.x86_64

   Complete!
   Last metadata expiration check: 0:11:59 ago on Fri 26 Nov 2021 09:00:26 AM UTC.
   Dependencies resolved.
   ====================================================================================================================================================================================================================
    Package                                             Architecture                                     Version                                                Repository                                        Size
   ====================================================================================================================================================================================================================
   Upgrading:
    libgcrypt                                           x86_64                                           1.8.5-6.el8                                            baseos                                           463 k

   Transaction Summary
   ====================================================================================================================================================================================================================
   Upgrade  1 Package

   Total download size: 463 k
   Downloading Packages:
   libgcrypt-1.8.5-6.el8.x86_64.rpm                                                                                                                                                    9.4 MB/s | 463 kB     00:00
   --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Total                                                                                                                                                                               1.6 MB/s | 463 kB     00:00
   Running transaction check
   Transaction check succeeded.
   Running transaction test
   Transaction test succeeded.
   Running transaction
     Preparing        :                                                                                                                                                                                            1/1
     Upgrading        : libgcrypt-1.8.5-6.el8.x86_64                                                                                                                                                               1/2
     Running scriptlet: libgcrypt-1.8.5-6.el8.x86_64                                                                                                                                                               1/2
     Cleanup          : libgcrypt-1.8.5-4.el8.x86_64                                                                                                                                                               2/2
     Running scriptlet: libgcrypt-1.8.5-4.el8.x86_64                                                                                                                                                               2/2
     Verifying        : libgcrypt-1.8.5-6.el8.x86_64                                                                                                                                                               1/2
     Verifying        : libgcrypt-1.8.5-4.el8.x86_64                                                                                                                                                               2/2

   Upgraded:
     libgcrypt-1.8.5-6.el8.x86_64

   Complete!
   Created symlink /etc/systemd/system/multi-user.target.wants/httpd.service → /usr/lib/systemd/system/httpd.service.
     % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                    Dload  Upload   Total   Spent    Left  Speed
   100   145  100   145    0     0    378      0 --:--:-- --:--:-- --:--:--   378
   100  970M  100  970M    0     0  20.1M      0  0:00:48  0:00:48 --:--:-- 26.4M

   real    0m48.293s
   user    0m4.449s
   sys 0m6.636s
     % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                    Dload  Upload   Total   Spent    Left  Speed
   100   145  100   145    0     0    434      0 --:--:-- --:--:-- --:--:--   434
   100  969M  100  969M    0     0  23.5M      0  0:00:41  0:00:41 --:--:-- 33.1M

   real    0m41.140s
   user    0m4.359s
   sys 0m6.380s

This script does the following things:

-  Installs and enables httpd.
-  Evaluates rhcos qemu url by leveraging ``openshift-install coreos print-stream-json``
-  Fetches this image
-  Patches *install-config.yaml* to point to local image.

Disconnected environment (Optional)
===================================

In this section, we enable a registry and sync content so we can deploy Openshift in a disconnected environment:

**NOTE:** In order to make use of this during a Baremetal install, proper DNS entries are needed to provide resolution for the fqdn of this local registry.

::

   /root/scripts/04_disconnected_registry.sh
   /root/scripts/04_disconnected_mirror.sh

Expected Output

::

   Last metadata expiration check: 0:13:25 ago on Fri 26 Nov 2021 09:30:24 AM UTC.
   Package httpd-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64 is already installed.
   Package httpd-tools-2.4.37-43.module_el8.5.0+1022+b541f3b1.x86_64 is already installed.
   Dependencies resolved.
   ====================================================================================================================================================================================================================
    Package                                                   Architecture                         Version                                                               Repository                               Size
   ====================================================================================================================================================================================================================
   Installing:
    bind-utils                                                x86_64                               32:9.11.26-6.el8                                                      appstream                               451 k
    jq                                                        x86_64                               1.5-12.el8                                                            appstream                               161 k
    podman                                                    x86_64                               3.3.1-9.module_el8.5.0+988+b1f0b741                                   appstream                                12 M
   Upgrading:
    iptables-libs                                             x86_64                               1.8.4-20.el8                                                          baseos                                  107 k
   Installing dependencies:
    bind-libs                                                 x86_64                               32:9.11.26-6.el8                                                      appstream                               174 k
    bind-libs-lite                                            x86_64                               32:9.11.26-6.el8                                                      appstream                               1.2 M
    bind-license                                              noarch                               32:9.11.26-6.el8                                                      appstream                               102 k
    conmon                                                    x86_64                               2:2.0.29-1.module_el8.5.0+890+6b136101                                appstream                                52 k
    container-selinux                                         noarch                               2:2.167.0-1.module_el8.5.0+911+f19012f9                               appstream                                54 k
    containernetworking-plugins                               x86_64                               1.0.0-1.module_el8.5.0+890+6b136101                                   appstream                                19 M
    containers-common                                         noarch                               2:1-2.module_el8.5.0+890+6b136101                                     appstream                                79 k
    criu                                                      x86_64                               3.15-3.module_el8.5.0+890+6b136101                                    appstream                               518 k
    fstrm                                                     x86_64                               0.6.1-2.el8                                                           appstream                                29 k
    fuse-common                                               x86_64                               3.2.1-12.el8                                                          baseos                                   21 k
    fuse-overlayfs                                            x86_64                               1.7.1-1.module_el8.5.0+890+6b136101                                   appstream                                73 k
    fuse3                                                     x86_64                               3.2.1-12.el8                                                          baseos                                   50 k
    fuse3-libs                                                x86_64                               3.2.1-12.el8                                                          baseos                                   94 k
    iptables                                                  x86_64                               1.8.4-20.el8                                                          baseos                                  585 k
    libnet                                                    x86_64                               1.1.6-15.el8                                                          appstream                                67 k
    libnetfilter_conntrack                                    x86_64                               1.0.6-5.el8                                                           baseos                                   65 k
    libnfnetlink                                              x86_64                               1.0.1-13.el8                                                          baseos                                   33 k
    libnftnl                                                  x86_64                               1.1.5-4.el8                                                           baseos                                   83 k
    libslirp                                                  x86_64                               4.4.0-1.module_el8.5.0+890+6b136101                                   appstream                                70 k
    nftables                                                  x86_64                               1:0.9.3-21.el8                                                        baseos                                  321 k
    oniguruma                                                 x86_64                               6.8.2-2.el8                                                           appstream                               187 k
    podman-catatonit                                          x86_64                               3.3.1-9.module_el8.5.0+988+b1f0b741                                   appstream                               340 k
    protobuf-c                                                x86_64                               1.3.0-6.el8                                                           appstream                                37 k
    python3-bind                                              noarch                               32:9.11.26-6.el8                                                      appstream                               150 k
    runc                                                      x86_64                               1.0.2-1.module_el8.5.0+911+f19012f9                                   appstream                               3.1 M
    slirp4netns                                               x86_64                               1.1.8-1.module_el8.5.0+890+6b136101                                   appstream                                51 k
   Enabling module streams:
    container-tools                                                                                rhel8

   Transaction Summary
   ====================================================================================================================================================================================================================
   Install  29 Packages
   Upgrade   1 Package

   Total download size: 39 M
   Downloading Packages:
   (1/30): bind-libs-9.11.26-6.el8.x86_64.rpm                                                                                                                                          1.8 MB/s | 174 kB     00:00
   (2/30): bind-license-9.11.26-6.el8.noarch.rpm                                                                                                                                       1.1 MB/s | 102 kB     00:00
   (3/30): conmon-2.0.29-1.module_el8.5.0+890+6b136101.x86_64.rpm                                                                                                                      495 kB/s |  52 kB     00:00
   (4/30): bind-utils-9.11.26-6.el8.x86_64.rpm                                                                                                                                         3.2 MB/s | 451 kB     00:00
   (5/30): container-selinux-2.167.0-1.module_el8.5.0+911+f19012f9.noarch.rpm                                                                                                          1.2 MB/s |  54 kB     00:00
   (6/30): containers-common-1-2.module_el8.5.0+890+6b136101.noarch.rpm                                                                                                                1.3 MB/s |  79 kB     00:00
   (7/30): bind-libs-lite-9.11.26-6.el8.x86_64.rpm                                                                                                                                     2.8 MB/s | 1.2 MB     00:00
   (8/30): fstrm-0.6.1-2.el8.x86_64.rpm                                                                                                                                                238 kB/s |  29 kB     00:00
   (9/30): fuse-overlayfs-1.7.1-1.module_el8.5.0+890+6b136101.x86_64.rpm                                                                                                               394 kB/s |  73 kB     00:00
   (10/30): criu-3.15-3.module_el8.5.0+890+6b136101.x86_64.rpm                                                                                                                         1.2 MB/s | 518 kB     00:00
   (11/30): libnet-1.1.6-15.el8.x86_64.rpm                                                                                                                                             422 kB/s |  67 kB     00:00
   (12/30): jq-1.5-12.el8.x86_64.rpm                                                                                                                                                   893 kB/s | 161 kB     00:00
   (13/30): containernetworking-plugins-1.0.0-1.module_el8.5.0+890+6b136101.x86_64.rpm                                                                                                  20 MB/s |  19 MB     00:00
   (14/30): libslirp-4.4.0-1.module_el8.5.0+890+6b136101.x86_64.rpm                                                                                                                    257 kB/s |  70 kB     00:00
   (15/30): oniguruma-6.8.2-2.el8.x86_64.rpm                                                                                                                                           707 kB/s | 187 kB     00:00
   (16/30): podman-catatonit-3.3.1-9.module_el8.5.0+988+b1f0b741.x86_64.rpm                                                                                                            1.8 MB/s | 340 kB     00:00
   (17/30): protobuf-c-1.3.0-6.el8.x86_64.rpm                                                                                                                                          194 kB/s |  37 kB     00:00
   (18/30): python3-bind-9.11.26-6.el8.noarch.rpm                                                                                                                                      1.9 MB/s | 150 kB     00:00
   (19/30): slirp4netns-1.1.8-1.module_el8.5.0+890+6b136101.x86_64.rpm                                                                                                                 1.2 MB/s |  51 kB     00:00
   (20/30): fuse-common-3.2.1-12.el8.x86_64.rpm                                                                                                                                        1.4 MB/s |  21 kB     00:00
   (21/30): fuse3-3.2.1-12.el8.x86_64.rpm                                                                                                                                              6.0 MB/s |  50 kB     00:00
   (22/30): fuse3-libs-3.2.1-12.el8.x86_64.rpm                                                                                                                                         7.7 MB/s |  94 kB     00:00
   (23/30): runc-1.0.2-1.module_el8.5.0+911+f19012f9.x86_64.rpm                                                                                                                         15 MB/s | 3.1 MB     00:00
   (24/30): libnetfilter_conntrack-1.0.6-5.el8.x86_64.rpm                                                                                                                              5.1 MB/s |  65 kB     00:00
   (25/30): libnfnetlink-1.0.1-13.el8.x86_64.rpm                                                                                                                                       8.4 MB/s |  33 kB     00:00
   (26/30): iptables-1.8.4-20.el8.x86_64.rpm                                                                                                                                           7.8 MB/s | 585 kB     00:00
   (27/30): libnftnl-1.1.5-4.el8.x86_64.rpm                                                                                                                                            9.3 MB/s |  83 kB     00:00
   (28/30): iptables-libs-1.8.4-20.el8.x86_64.rpm                                                                                                                                       13 MB/s | 107 kB     00:00
   (29/30): nftables-0.9.3-21.el8.x86_64.rpm                                                                                                                                            15 MB/s | 321 kB     00:00
   (30/30): podman-3.3.1-9.module_el8.5.0+988+b1f0b741.x86_64.rpm                                                                                                                       16 MB/s |  12 MB     00:00
   --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Total                                                                                                                                                                                18 MB/s |  39 MB     00:02
   Running transaction check
   Transaction check succeeded.
   Running transaction test
   Transaction test succeeded.
   Running transaction
     Preparing        :                                                                                                                                                                                            1/1
     Installing       : protobuf-c-1.3.0-6.el8.x86_64                                                                                                                                                             1/31
     Installing       : fstrm-0.6.1-2.el8.x86_64                                                                                                                                                                  2/31
     Installing       : bind-license-32:9.11.26-6.el8.noarch                                                                                                                                                      3/31
     Installing       : bind-libs-lite-32:9.11.26-6.el8.x86_64                                                                                                                                                    4/31
     Upgrading        : iptables-libs-1.8.4-20.el8.x86_64                                                                                                                                                         5/31
     Installing       : libnftnl-1.1.5-4.el8.x86_64                                                                                                                                                               6/31
     Running scriptlet: libnftnl-1.1.5-4.el8.x86_64                                                                                                                                                               6/31
     Installing       : nftables-1:0.9.3-21.el8.x86_64                                                                                                                                                            7/31
     Running scriptlet: nftables-1:0.9.3-21.el8.x86_64                                                                                                                                                            7/31
     Installing       : libnfnetlink-1.0.1-13.el8.x86_64                                                                                                                                                          8/31
     Running scriptlet: libnfnetlink-1.0.1-13.el8.x86_64                                                                                                                                                          8/31
     Running scriptlet: container-selinux-2:2.167.0-1.module_el8.5.0+911+f19012f9.noarch                                                                                                                          9/31
     Installing       : container-selinux-2:2.167.0-1.module_el8.5.0+911+f19012f9.noarch                                                                                                                          9/31
     Running scriptlet: container-selinux-2:2.167.0-1.module_el8.5.0+911+f19012f9.noarch                                                                                                                          9/31
     Installing       : libnetfilter_conntrack-1.0.6-5.el8.x86_64                                                                                                                                                10/31
     Running scriptlet: libnetfilter_conntrack-1.0.6-5.el8.x86_64                                                                                                                                                10/31
     Running scriptlet: iptables-1.8.4-20.el8.x86_64                                                                                                                                                             11/31
     Installing       : iptables-1.8.4-20.el8.x86_64                                                                                                                                                             11/31
     Running scriptlet: iptables-1.8.4-20.el8.x86_64                                                                                                                                                             11/31
     Installing       : bind-libs-32:9.11.26-6.el8.x86_64                                                                                                                                                        12/31
     Installing       : python3-bind-32:9.11.26-6.el8.noarch                                                                                                                                                     13/31
     Installing       : fuse3-libs-3.2.1-12.el8.x86_64                                                                                                                                                           14/31
     Running scriptlet: fuse3-libs-3.2.1-12.el8.x86_64                                                                                                                                                           14/31
     Installing       : fuse-common-3.2.1-12.el8.x86_64                                                                                                                                                          15/31
     Installing       : fuse3-3.2.1-12.el8.x86_64                                                                                                                                                                16/31
     Installing       : fuse-overlayfs-1.7.1-1.module_el8.5.0+890+6b136101.x86_64                                                                                                                                17/31
     Running scriptlet: fuse-overlayfs-1.7.1-1.module_el8.5.0+890+6b136101.x86_64                                                                                                                                17/31
     Installing       : oniguruma-6.8.2-2.el8.x86_64                                                                                                                                                             18/31
     Running scriptlet: oniguruma-6.8.2-2.el8.x86_64                                                                                                                                                             18/31
     Installing       : libslirp-4.4.0-1.module_el8.5.0+890+6b136101.x86_64                                                                                                                                      19/31
     Installing       : slirp4netns-1.1.8-1.module_el8.5.0+890+6b136101.x86_64                                                                                                                                   20/31
     Installing       : libnet-1.1.6-15.el8.x86_64                                                                                                                                                               21/31
     Running scriptlet: libnet-1.1.6-15.el8.x86_64                                                                                                                                                               21/31
     Installing       : criu-3.15-3.module_el8.5.0+890+6b136101.x86_64                                                                                                                                           22/31
     Installing       : runc-1.0.2-1.module_el8.5.0+911+f19012f9.x86_64                                                                                                                                          23/31
     Installing       : containers-common-2:1-2.module_el8.5.0+890+6b136101.noarch                                                                                                                               24/31
     Installing       : containernetworking-plugins-1.0.0-1.module_el8.5.0+890+6b136101.x86_64                                                                                                                   25/31
     Installing       : conmon-2:2.0.29-1.module_el8.5.0+890+6b136101.x86_64                                                                                                                                     26/31
     Installing       : podman-catatonit-3.3.1-9.module_el8.5.0+988+b1f0b741.x86_64                                                                                                                              27/31
     Installing       : podman-3.3.1-9.module_el8.5.0+988+b1f0b741.x86_64                                                                                                                                        28/31
     Installing       : jq-1.5-12.el8.x86_64                                                                                                                                                                     29/31
     Installing       : bind-utils-32:9.11.26-6.el8.x86_64                                                                                                                                                       30/31
     Cleanup          : iptables-libs-1.8.4-17.el8.x86_64                                                                                                                                                        31/31
     Running scriptlet: container-selinux-2:2.167.0-1.module_el8.5.0+911+f19012f9.noarch                                                                                                                         31/31
     Running scriptlet: iptables-libs-1.8.4-17.el8.x86_64                                                                                                                                                        31/31
     Verifying        : bind-libs-32:9.11.26-6.el8.x86_64                                                                                                                                                         1/31
     Verifying        : bind-libs-lite-32:9.11.26-6.el8.x86_64                                                                                                                                                    2/31
     Verifying        : bind-license-32:9.11.26-6.el8.noarch                                                                                                                                                      3/31
     Verifying        : bind-utils-32:9.11.26-6.el8.x86_64                                                                                                                                                        4/31
     Verifying        : conmon-2:2.0.29-1.module_el8.5.0+890+6b136101.x86_64                                                                                                                                      5/31
     Verifying        : container-selinux-2:2.167.0-1.module_el8.5.0+911+f19012f9.noarch                                                                                                                          6/31
     Verifying        : containernetworking-plugins-1.0.0-1.module_el8.5.0+890+6b136101.x86_64                                                                                                                    7/31
     Verifying        : containers-common-2:1-2.module_el8.5.0+890+6b136101.noarch                                                                                                                                8/31
     Verifying        : criu-3.15-3.module_el8.5.0+890+6b136101.x86_64                                                                                                                                            9/31
     Verifying        : fstrm-0.6.1-2.el8.x86_64                                                                                                                                                                 10/31
     Verifying        : fuse-overlayfs-1.7.1-1.module_el8.5.0+890+6b136101.x86_64                                                                                                                                11/31
     Verifying        : jq-1.5-12.el8.x86_64                                                                                                                                                                     12/31
     Verifying        : libnet-1.1.6-15.el8.x86_64                                                                                                                                                               13/31
     Verifying        : libslirp-4.4.0-1.module_el8.5.0+890+6b136101.x86_64                                                                                                                                      14/31
     Verifying        : oniguruma-6.8.2-2.el8.x86_64                                                                                                                                                             15/31
     Verifying        : podman-3.3.1-9.module_el8.5.0+988+b1f0b741.x86_64                                                                                                                                        16/31
     Verifying        : podman-catatonit-3.3.1-9.module_el8.5.0+988+b1f0b741.x86_64                                                                                                                              17/31
     Verifying        : protobuf-c-1.3.0-6.el8.x86_64                                                                                                                                                            18/31
     Verifying        : python3-bind-32:9.11.26-6.el8.noarch                                                                                                                                                     19/31
     Verifying        : runc-1.0.2-1.module_el8.5.0+911+f19012f9.x86_64                                                                                                                                          20/31
     Verifying        : slirp4netns-1.1.8-1.module_el8.5.0+890+6b136101.x86_64                                                                                                                                   21/31
     Verifying        : fuse-common-3.2.1-12.el8.x86_64                                                                                                                                                          22/31
     Verifying        : fuse3-3.2.1-12.el8.x86_64                                                                                                                                                                23/31
     Verifying        : fuse3-libs-3.2.1-12.el8.x86_64                                                                                                                                                           24/31
     Verifying        : iptables-1.8.4-20.el8.x86_64                                                                                                                                                             25/31
     Verifying        : libnetfilter_conntrack-1.0.6-5.el8.x86_64                                                                                                                                                26/31
     Verifying        : libnfnetlink-1.0.1-13.el8.x86_64                                                                                                                                                         27/31
     Verifying        : libnftnl-1.1.5-4.el8.x86_64                                                                                                                                                              28/31
     Verifying        : nftables-1:0.9.3-21.el8.x86_64                                                                                                                                                           29/31
     Verifying        : iptables-libs-1.8.4-20.el8.x86_64                                                                                                                                                        30/31
     Verifying        : iptables-libs-1.8.4-17.el8.x86_64                                                                                                                                                        31/31

   Upgraded:
     iptables-libs-1.8.4-20.el8.x86_64
   Installed:
     bind-libs-32:9.11.26-6.el8.x86_64                                           bind-libs-lite-32:9.11.26-6.el8.x86_64                          bind-license-32:9.11.26-6.el8.noarch
     bind-utils-32:9.11.26-6.el8.x86_64                                          conmon-2:2.0.29-1.module_el8.5.0+890+6b136101.x86_64            container-selinux-2:2.167.0-1.module_el8.5.0+911+f19012f9.noarch
     containernetworking-plugins-1.0.0-1.module_el8.5.0+890+6b136101.x86_64      containers-common-2:1-2.module_el8.5.0+890+6b136101.noarch      criu-3.15-3.module_el8.5.0+890+6b136101.x86_64
     fstrm-0.6.1-2.el8.x86_64                                                    fuse-common-3.2.1-12.el8.x86_64                                 fuse-overlayfs-1.7.1-1.module_el8.5.0+890+6b136101.x86_64
     fuse3-3.2.1-12.el8.x86_64                                                   fuse3-libs-3.2.1-12.el8.x86_64                                  iptables-1.8.4-20.el8.x86_64
     jq-1.5-12.el8.x86_64                                                        libnet-1.1.6-15.el8.x86_64                                      libnetfilter_conntrack-1.0.6-5.el8.x86_64
     libnfnetlink-1.0.1-13.el8.x86_64                                            libnftnl-1.1.5-4.el8.x86_64                                     libslirp-4.4.0-1.module_el8.5.0+890+6b136101.x86_64
     nftables-1:0.9.3-21.el8.x86_64                                              oniguruma-6.8.2-2.el8.x86_64                                    podman-3.3.1-9.module_el8.5.0+988+b1f0b741.x86_64
     podman-catatonit-3.3.1-9.module_el8.5.0+988+b1f0b741.x86_64                 protobuf-c-1.3.0-6.el8.x86_64                                   python3-bind-32:9.11.26-6.el8.noarch
     runc-1.0.2-1.module_el8.5.0+911+f19012f9.x86_64                             slirp4netns-1.1.8-1.module_el8.5.0+890+6b136101.x86_64

   Complete!
   Generating a RSA private key
   ................................................................................................................................++++
   ........................................................................++++
   writing new private key to '/opt/registry/certs/domain.key'
   -----
   Adding password for user dummy
   Trying to pull quay.io/saledort/registry:2...
   Getting image source signatures
   Copying blob c1cc712bcecd done
   Copying blob 46bcb632e506 done
   Copying blob cbdbe7a5bc2a done
   Copying blob 3db6272dcbfa done
   Copying blob 47112e65547d done
   Copying config 2d4f4b5309 done
   Writing manifest to image destination
   Storing signatures
   2687fd3571fa37e22399f3584ca8bc6ec0e11f9a3d8f2a81e75858a0fa4c367b
   Created symlink /etc/systemd/system/multi-user.target.wants/registry.service → /etc/systemd/system/registry.service.
   info: Mirroring 141 images to lab-installer.karmalabs.corp:5000/ocp4 ...
   lab-installer.karmalabs.corp:5000/
     ocp4
       blobs:
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:47aa3ed2034c4f27622b989b26c06087de17067268a19a1b3642a7e2686cd1a3 1.747KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ea1cb83b86c4b14b0f542af61ba7fe996922c03d4f713b28c8d2eedced3acbbd 1.788KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:614980cc4ef1d75cf820db04a28b9d25250e86a2c6f72541d1fac7d28361ef5d 1.826KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b07d9a2db2079cb5cba7dad7363a75abf9d0780c179b54c8c91677482feeed85 3.161KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:744476aae44cff5da6de60cb152132bd30507a0be58c6b8b08cf5645806e93d5 4.656KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:84d351d4f95f2caab6d1a3cf64a3515e00c2acd7f29445363039ef5682b4f60a 5.548KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:dda0623563ab781ecbaa9ff722b193417a5fea62b9fc2f836208a711c9ba3995 5.671KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:01894fc77a296234051087d6c1bda35ec7b3142c9645b4ee0cc89390b8998d26 5.682KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5e2c623acc29944651153a7331f33cbbab730746c5778f56ecd560add3e7adc9 5.69KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:462da1ca72ae0ed2b2ff85231e1fbdeb9913fac5f068d14b8b51240e9799ffef 5.693KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6d3d4f31f95e0abdec4f1f50591fe0efa774fa3fcb26cf67e564f68a8ac071dd 5.705KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:76480f65f161898287c1667b750e876b408d2e7287664a25f0a80f103b7b99ae 5.732KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:664899c9f85192dd0d6a6eea14d58d079c0cc2e80024bfd6900ec17724922724 5.737KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:eb7ebe4a914d07cadcb49acab327fd8d211de6b21d1da02d56c8ed5d045330af 5.74KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:df9aeb0e102c1fe46b551c8e3905335bf95a894b43d6163a585b28b49179de80 5.742KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4a15e955c5948264c40f0e5769f840a1169e295570a80889693dcb8074031304 5.745KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2876a7cbb2964552a69d8180452cbf0cf0a94331b7b55d29c5a624998597300e 5.746KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:dc42af2dbcaf9102b22963b9ab8ecb815f47def24a4fddd2d8d176e18563fb03 5.752KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b13d1c87371a456d7f6e46827287c5ca25e7b4be1c5e4a6279dddf285f7d88b1 5.753KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:bd321ba5fe2efdc9ec0bac35be5a2183bdd8ab1924983e887155a715aff624ea 5.768KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:eb2b84791c3f48fb2fc1d5d262dd5ea3b253c9d21cf5462c00985ab42a1a513a 5.768KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:66a964068df8afcb020a2d83a3e989adc5006017a6ef0df145b04368f822a52f 5.774KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:aacc406148c3848835260cf388607a21c16ca3c485866dccba17419c760d4b93 5.785KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:844d8e6edb8620e7f3d89f2ec1d91098347195b23e284030208c8be8119cfc48 5.804KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7661f2f3d00ed3dbba9fe6f9a4f9509ca5e65ae1d01fc73e8bb7f5d92b41f4a6 5.806KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ec788e3bde232f4ae5a062ceddc6063f1b969a1fecf21d689c58e35eccd83ff4 5.806KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:46a1273f08ee551a02e3949c44a50dfeab00b02d01c74edadc375c1cb48ede8f 5.807KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:065929ab55128e9910fa7ad1f429724ff0856f263e09f388d008211f5666f925 5.81KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:eaf276bc41d04deea5914b44c28375cb3a9bd88ddb1e4f663e4df7756ce22b1b 5.81KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f39f455854450781b6e4636bd8ae92cde2a60f08b332fb7cdae4dff2a2ff6fc1 5.81KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e49025ccafa971abf935dad3640e8f4d513bf2572e4a5bab2efc89b2b6fb17f2 5.811KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f3d76e08cc92789880ff1c41467c3e95bd0e2cefb15af5d740206e876fc26c0e 5.822KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:de4e82c9e8f063da86969c99bc882ca9443d8546f0a3cc384eec24e58442e00c 5.825KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0bd5e4fa85173d8df2ae9492a106760fdc320189c637e6386515674b335f9ba0 5.829KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:41a4924f1525adf27f78e567bea72568c1fb266e01372b5b8087265916a3e80e 5.835KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e79d0abb8ef8d3b9008f317a8945af198aff8f49f3556d70cd9384ca35257a52 5.837KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b2956d61df335d02cea837f91da511501826a28b975251af54ecd6eb7a0ce467 5.839KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ccf1af779ca4c2d9f6633a267aa7864f79a0f6399e0bf6e84ca14c0161669128 5.842KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f480fa8735ffac6836ebee7cf425824323e56d4d71f5f7a246bad167618a5ed1 5.842KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a92a466de2e773a731d5f2667ace8648c19adbb4500d07540c26e7cce6cf2e41 5.843KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e722ed7113a02d47dd1064e5a2502cd1814bd7b90b60b42b3591eee5c6c41b34 5.843KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e852c16bc4873e3d6b57d1f303f9921c98f074ec62b061a8bf72196eb4ef1edd 5.843KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:cdb7c23c9d7d946948889db59872db58d6c4a67f7f6c04a4e4d35ce56b83c34c 5.848KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5d77703142db144b4056519904da88bafc94c8c2dd3f1dabb6f482d6a426100a 5.854KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6c831a68605b47eebaa627aeee270a6d9b0f528e2fd203b66c64ea4694b36813 5.854KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b41f176b8227e2f87722cfc54246a7bdf36a2ff182837f265f8bec8b613811d6 5.854KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:852d5b504aac6908994b41197276b6c024b6799916f88dc8772be76b925f1214 5.854KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7fde18bef6c54ca30b6ba0c9e4ec5827d904e86eb4521c88b2b84fb771e7ac87 5.859KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:44341ea1716f1d7f6ff813bad16d427996df2a02b6aa65dc7f4b7a88d0ab3d42 5.863KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:75b7f4fe76691d3d1e070cb9f1892cac250216cb4e942aacc5c11e12ff8915d5 5.866KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6940df594b045e6deeaa8a518e73437a7f3c58ce58d37331bc4d68c9017ef3e9 5.869KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6659f4ffac552918f4d03d9958c020e7542981695ba1a5f236f967c84637d75e 5.87KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e798309f82d1186a2cbd52c25e0af5bfcc1ecef52badd22b22f14b87b842f6a5 5.871KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3c36dae8abbe82fe871a7c1b544c71686a4b95635544d4c6f98dcf07079f20c5 5.872KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7bf94b7dafd1eaf4cc23e69594e00b92c55ec74ce8733306c01fa2b279ffd55d 5.872KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:91317d5678b536f7aaba64811c8d267b5544a301aa3a2b192a9bcf22706b37e5 5.874KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:805a2e23fc2daecad626163fd5fd5a29069f968eade94ad1a5e145639263dbee 5.88KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:998f51ab8997a42b850ad08d86789ed2afcb0afbdff12f7ca85a62883950010b 5.88KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b9f19a09fcd0b13e70795d15ea10c54c1d0148bf26ab04325dfda0bbc71a4668 5.883KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:cc11b96c2acca4a2300813acd6fdd8284d285988a9bc9aff0f2e10806a07c133 5.884KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:625d09cd8912208a8a3391a389599d9843f6315ad5672a52dd12da2b6652eb52 5.886KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:bb0c8c5bf9270a650cdc1706df9c4734d7dc15d48e080dc43f4ea0ed2f8f8e8c 5.888KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9a174e72faf2ed22f9c92d48f390e7d5b54326bbdc48bb6ef6bea7be25e13018 5.891KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:56bdbb63e36088da611b1f68407193c440131329ebb744710d92d726810f8f68 5.893KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1a81e15604fda0d8acb268405abe02e2cf03c40d319a10791e064dafc90c4a87 5.896KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4f7087a7171e56978dd271ebab135abfe35e52a91d72a5276dbfe72d13afd8b1 5.897KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:51d7f3532646c8a6c374f3014f5ef351fdcff62988e2a77fe33c83497125e1a1 5.899KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:99f697c43ef1dc4629af6517fdc04bb4ed15e5325971c4e63d0690e20106db5e 5.899KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f72d983706edc45442aee4dfe65d28231c85735f9ed3eca5e83328167b642666 5.899KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0a6a25e7c0185f5a7d733715d1a61276fe60c512211afbdc90b068bfcc6e91b4 5.903KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:905d30591bdefbd97263ba8149670463e6ef9b0ae2c666e895d083a05b87687c 5.905KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a1e269f956d76bb2abc6e5fa2947021964645cf52dc84ce576866e68bc096fd6 5.906KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:86232ef5880d09e11d3e1bd8b5b4f702070c61d98d803f93353cd8f66322b05c 5.907KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8672c55c93eccea1a129c14b56d9870fd79642e44e547eff10c3daa23f5a88e8 5.907KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f9cbdda63a1b2502731ca002c375c7c12aba9b1c1b90a1279845f680ad86730c 5.907KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:83bf11a1d53f944fba5ed318ad2895e236ea6f5190c7dc32835b25ca5d6da27b 5.908KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:37ebe517fa3ed0def8bac76255c0f3d3930e3c88fbabd7722df19a5aad49b7a6 5.911KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3e268b549bc7b710d6046a6f7cec45324ca6996ec137768c1f205a04ac7acbd4 5.913KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5bd4937a777f776feb3ae00fd09dfa8df9eae02d5f40c1340d1ff431218db36a 5.915KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:bd95bf38a5b6926a60510e82cd84be36b78c8753d8e339bd8df008fe8bf712f3 5.916KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:d7e343a695bed699caeccde00c3b3d2648458fd9860f715807e22022aa5d5572 5.918KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:32f65ebfaf16902946864747f03691ef9a605b48cdba420c53a3d565cfc90044 5.92KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5ddca0b5fbb916b012d20d7bd27d7c84af6831be9737952179ed643ef3194afb 5.922KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7489a5a995ff71802eb2016e113609ace7d9ce90803572de2b42a9fd78d9c479 5.922KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:72feff4fd251fceb9b001a1e3127cd0d9a332d0364fe64ebe4a06ed07e3f9f62 5.925KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9ef00a168876ffd8190a4d23b8ba48a214e1b0057ad0cdd321ebbcc803df7bd9 5.928KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:fda7b81a2ac31c57120295f6062e2295aa660bd44b5932df3b18b1f55a97a600 5.932KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:273564a892f3a3e8686c3cecf7d818c032a842846d6b15ca571e4677ac871a6a 5.935KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a5e0cac2a6a4ebcfbb1dacee3fabb7ee3727b888207b2954b6c405c49fc9c96c 5.937KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ad44d39577f95a16e7337912697e8cced763f9f68c7eb14a94bbaa0806e86d7e 5.938KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1ba2642807db05e70de7ecde10dddf519b48891ef334948049b1bb742855fb1b 5.938KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:83d50208a3bee1ef2c2307fa3e0b7be268158350ccf6867b7bf19f7af5febc06 5.944KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5ef4937870eab76fc5abb7202ed9031fc535c385417497af00b1e2c697d01b24 5.949KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8f144678ad3244eba4e515033b4ff616eef1b5ea57e1ccd27a2ff68c4afd6ce2 5.954KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:92d42422c5a53ee62195355657f531057eefb90e2eec5a3becb97b0395962d94 5.959KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:42d79f237180cd72795c8c52a120ff048ae6e9f882daccc0d127955405574b28 5.964KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ea62183e62c65aa45839f445d7bca166626e5a0358196bd4c3283d9156b0a6eb 5.965KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:d44e64e00009329702eeeda354ed2eb1aade7d33a6de5f7cc3a626ac106618c1 5.97KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:fb9f224f0c5760f7c45342d0acd4ac466a76ed509fb73a8eab68e63686a62ce8 5.97KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b656088b61f293f17cc4ee347cf25c16e5b8030d28cefacdde910646a5ef0601 5.975KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5cd42a041db2597c4be1c498fb212baa762dae435838f08394dca68fc2517f8f 5.977KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3b21472ef07e9e158995a08972e5cb65d2bcefa45eb3ee51af29ae2200844a32 5.978KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1b79fd20d6eff6548534511b51c1309d7b4fa0a68de42335477d6ccc2a52388e 5.982KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e9bf7534abb42b2344921fd2fe7cf206d71529116e7622faf1ddd78850ce1512 5.983KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e871bfa07c467fb61550ddac67cb14788af8371c9c3b0e2ba630ed50890b2717 5.987KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:11d31d5799c3bf2775fdb9fa7eb342cd736c0548239f0bd7a3fba2f1c66cad30 5.989KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:d35445c6261824c1da0c3b211ccd1175184592911a6606aa5d650c0a98d10348 5.989KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3c79c72aa0dfdcd385e4b1e140b854bc9a8f6dc8e3f1303f4093da9894a6d2fe 5.996KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e78d99a6ed92c539484aecd28884a6ef5a63f38887ada86aed82670187ec74d0 5.997KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f934f19f6becaee86e6acbede3dd9bb2091ac4a15770f335012c97704515cfec 6.003KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:336eebd92a39649d9913cf5443d56c9b1b8715b8cfae788cb837d420dbee0cb0 6.006KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4979c5b3aac0bbfb6748ca1fc6e3b7c56389d00862e094bb7f1141ce024bf763 6.006KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1c3650ff99cc803a1dcf6e8d2195167cc06163c99ff3da3be223e4628f04096a 6.011KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:16537305b6f76db9ffe046214f7eb390f524386d1d544820acd22fb48e89f2ea 6.012KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:52c8b31effff7efb056aa76bb4bf94e1c88319ad4704a757e7b0cd2fcbebf356 6.012KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f500805664515862f2e9bb6423da598f69659f08eaa88b3cab4074242adc643f 6.017KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:926fbbc8ce04e40af80f5b0f8f9890c45999553660f1f039308639400823ef4f 6.018KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8c69506cfa2b39c33391ec021c6bc828b7f9b9d7c628fd68c169c5a0971fc003 6.024KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c6f23d41309ec23ee2ea3f04b715a619b4b9c5139ce258b1022eba384359b768 6.034KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c7b9b70bee54376181fc4cb758294dcadac9925927a2567899573d70152db060 6.066KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:276abbef9ad5f932ef2dadb166f28373b9979ed06a45314d09d355edf191bf31 6.073KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1e423384e033efb23a446149b6a0ef5e5b66972a25e43e15dd7a64dbd8890385 6.119KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:d12ee19477ec42805445b4c75cb0923a12cab900735e6bba0e39d2133cf26d13 6.125KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:94292da361377a7c1e9131376e96dc1abb022bd78ed9600a1d49c45d5150dbe8 6.128KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:dfbb70be75f2499f2ed41d314fea3fa56463aa4652c4ba3917e9ebc4312efb52 6.129KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:273a67f15fd05c830405a4c0efc9f08553aa272799f72a5738208525fef9a1d9 6.146KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:02d60f0060610337bdd7e38b51a6e9840b50335b807f5c19eaefad10e13056c3 6.147KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0fc8192c104c0bdfbf3e0e7d1f3e283a57dd14f880982eab072223a9cd7f1891 6.15KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:421227e339de6898209dbba193ea901e0c7577abd2631472bb3730d96f6831f8 6.171KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:96785185725d4a439ea0a954785d7b1156dae28f53d28e8f63a1378905241888 6.179KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0b911b3b8c102f38edc21a0258cec0d5617c6bb8a5b3f5078cace870d0ae4b5e 6.215KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c554102d0cd523a63e043137deaa276729c006073f759c824fe25faf80bcd33a 6.233KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:939943177bc971bbb656a49f197f124af9f67631f844bc3805b21999e912c5c7 6.398KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8524e8daa604d7925f69020be4860610675d7e30ae36734a183062fc0beac698 6.438KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:07c7d675ede9dc548700006ef0a6bd28052974208201d3638113574c75856a00 6.532KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3d9d2dfbac881cb03460f175ec6a200bb6c0679808b8ea2fa2d60b4009a81bf9 6.568KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6749c2ded45fe3a84de0d82434c677e2f5054abd9e4483b6dad5f117f7ec7261 6.586KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4285bde2b7115315dc5496c39acb65400328be646feb8b3f59b912cdc93950a7 6.59KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:89dfa2369fe8a5fc8c9da706f2952cd904e9b95f739505c18f6c9c0015fca6ad 6.604KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9742fa13f3ca5637115e3e87545cd37a8034d05c006ede3d3a8c587420499ac0 6.625KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2df20456b64cdd96c5b09450a521350ac1ae50cef2b5a0b345ec3121ddf7a806 6.665KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a84416cfe7cde7ea857095156124a5d151d339a46b191af5895e34965a7e9f01 6.719KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2026c5bae89b3941978ee30076f728e78525f6879bb8ed5bee73539c8e51a78d 7.041KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:24d98825e17fbb9ba0aa88b802275d849b8653fc7e1b47481078ffda068355fa 7.124KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:95f77a94c6b6b0747ec98413be49eda2142540df8af5f6804a657c6b7c5b1946 12.31KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:53de18eed10c0b7e53ab8be2750768cfdcc1df9e320c06bc697ff19aa5603908 374.5KiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:16de42bf1c6e1f05cb0109c3f6fa2d42c7ce63f45afa3c92b7904160cd6ded3e 2.716MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:84bc3dab2efafa1f2bd8157a15ef9dd4a23557fdd7358151a50ac7dbf51209d3 3.44MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0749408b74331c62d4ee9ac898d4ac15790e0dfefca6698f0edd46019fd2dc3f 4.802MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:101e49f360bb05fbf3951e7d748dbf63faa50a07aed7c92115b194974f3437a3 5.034MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8e1f8299ae48cdb1a6ab42dfb48d2e5f5769b91dff9fbde4d87a7b4802acc234 5.335MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7492892b5e7853eb6234a57f4ab3b2a00208ac0b5318c6925a77b08024151b52 6.042MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:450c1856cde291bbe8de8e7eff490e70c10d4bc6f3f51c1f4f6170bd529ca925 6.133MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a72d0b8729ec3eb4367676c92680df04228e6971323d143b7d067c4d58dae198 6.993MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:33a119f5e566aa590281b2842b9f03d7c405b4988f626e5107878da8c3f9a7c4 7.585MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:95a7976d52f959cad92d750e5b0c4dbf5d689f2a81159b48f459b5b04f276e1e 8.801MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a3c8f12d44d6493423ad9e28fef942b73e66d005143faed486226a96ff3f37e3 8.9MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7a02c97f53bb3e4b7ff01c7f682e55639cb6103b94fd40ba987b25805aa8c0c2 9.219MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e54107e78c6408f1da8f297c9257acce8c12342fc9081b73cb64f6f191ef97c0 9.386MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7a9eee3b7981073f117952604a5cd2b32814bfb7ac37047c2cedc5426791a785 9.476MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4068a75a5665067da383d3472fb15010c6ede8296673f468cddf31372e1a7431 9.534MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:930a24a335705c0b20fe79b020f568f998354e975373e27ce42982fd3aa323fd 10.68MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4b2bfed57f6412e6513a60e0491be8721592df856726494e79c8553118f77897 11.45MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:048edbb18d9b1752c92ae662c195bdcdd515a6a4333c9a5c014ec34868467114 11.85MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:809e9fdf6fc5aa3940ff883cceab0da5bc7ef663b68b7eb96b52d2f70b6668eb 12.14MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f5c7b4fa93b9d218e99110ad3eddaf04784ab55077ad1dc574266d8e5f5ad04b 13.44MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:626138ddd8a2d28e3ab511730cfd6937406470b96f1b5825ace55ac2dfb49b01 13.57MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:72428c44ac70b800d0d7027b9a782c57ea1c49a1006490a0375d8bc7b77642e6 14.15MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ddef0b8dafbbdd741e049e7b68cc43e2f34cf823d865315ad83869948896afb9 14.61MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:367f4b46a5fe7586aaec3634167371eaf51987196ea7a6cc95afe601d9955c8e 14.86MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:56764cdf702c98b30386be602cea63931b75f54d57cfd4a307db510a7c07a2bf 16.12MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e5719d450d133998894141a5f56fa3ca62d9bba8c3a4c14a0f23d2dd04aa8bac 16.92MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:626b321f688cb48ef17e00764ff950943e6f776ad0d42d229dedeb4d6a1db3d6 17.16MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c8c0554931286354ee41452f49b63ef27b72b0b92c3d44f84a870597fdc94761 17.44MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:09dd8cae3e466952936c3d0dffac28a96ca88bb87311b008b54384e38b6e401e 17.87MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2dfee98672778d02d57f49b329aae6a7eff485a62112646c1e53937e7d07e425 18.02MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e22321c63f0f6ec35f29133f0f59f9f1ef96675cd9bce699e08dea53e7464613 18.1MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f314371d464bc25b8d9e1875b9060fd63ed60df06d819413948d955eb5d35d04 18.18MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:f0aa6c37b45ae68681e019b571b957fc5e9c9ebbd66c4299458bde9ae12aceb4 18.63MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:d657b2cdecaf6f68f08f7038b5f01136a92ca82ba6afd4c1304b47da58b0ba6d 18.92MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:445e5ef5e706881c789bc938c70c6bbbf90dd06f1afc113710da68e654152fd2 19.7MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b43c2735ff2f94df00a1504731f3eda0e330d1ac65fd3d6ba6701bdac95e6c10 19.89MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b61c3074dd7067516154ad2141f3995340bd19122be5a32dc41e3cc06d9ee7c1 19.99MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:eeca239718c8acf5c0f075f72f3942f6d83cd9f391f2816cdd3ead992b4d4c77 20.09MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b5781c57cffa8e6c5e3ae1618a498b23ae4e57bc0862abe0d46ac0c27a69b370 20.76MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:d857582bea95499dd10bda291d820dce6c4fda7c33810406ec2cea2dfaf462a1 21.11MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b1090b12aaaef17b6379025090b47edceb857b424e7c6b6658d42ab0856833a7 21.32MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e293256dc1ab2a9495dd7204625cd9f8a273d0d3da3f18526bcb150496f7a1a3 21.33MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0bc56e8679aa66db98d6434e315fa2d0ef36993b4b5a0a131aa9640bce25df74 21.59MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:fb44c74f36a9cb2285bbc4ed2d28832b97cd31a003caa655b660b1cfa267e40f 22.67MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:247117ceab4073d061c36bfd7702ba20e02b2cdcea47fbc2da6fad6af325e095 24.45MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:15ecbe9e118c3bc0e4e585da1539383435d8f2f4aeecf4ad0ce5ea5797e5adff 24.64MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:64408119965c952b5c82666873dafd71ab13d3ed2c9c31f8f4ebe22d7db9d504 24.78MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5333f505fbcd4c446f9067a09d98652f6b7441f4918b678cb6700ef1f375c628 24.93MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c980ac22ce4874cda4dbb6e07ffd5f5174e76f26141e053492ec186d4f7a39ac 25.04MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:157537e57374f03ddd085c000ddbfd311133c1577d2af661bc9cef58eebd9ee8 25.2MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:005e519404108145e27c6b62a0317b423b3ed312500f4f799cbdece832d8a9d6 25.29MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:52e1e0b0ae9ca461e6878abc19455a9e912cf76c5375c182bd69de34ab6e1fd5 25.35MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:1c243b082d6332976400a9f2bd280e43d255b0b076ba9918041f277db7fffacf 25.42MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9fa7e6e181436a42f71ad38303d0bd0f360e3256b3635ceb2ef620dd5cc60377 25.78MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8fe48571d13bcd4928aad13cacc72caf04116c089d964c37c53b5138d20d0e05 25.9MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b679ce34f2e79abb75e66c6d0b8d8eea9b78fcd948a4973e7bda10fccc98e094 25.98MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:44c835b889889938274a454feb4e98b2cc6d533690095b604a28a0cd9360dce5 27.21MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:720275e24950d9fb54b7ad5a62a21505c3a666f050d8d0a7deb78b8062bbe3b1 27.25MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0b3793e01f41d947f8bce3b51f6b419a5526431686f5fb8be092d66a288bdc17 28.25MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:802e95f73fb87648a0b168369a6b8b2d8cd86b25a08317ece4bbf418b3737053 28.26MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e50ca0bc0533a68185ae4d6886dac4d54656369bd4324f06ec78d51e9cabfed1 28.41MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a0453b87f28599bd146de4333b3bb6bda5a24c550308a9c8d18c5c50f84e4824 28.83MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8a41da6cec2398e936fb11fbe66344278f9bccb4552667d16c9cf7bd2a3d44a7 29.01MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:0b0334e3d50db81777ea74adad1b2fa7d348bc386122144e76589161ba0da6d2 29.15MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8272348703e5a7d43b0cc8a548ed1cd1e1dcbecf472c2c52764404c02050d130 29.36MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:42cd9d27ea411d91c1c2e1b2ebd02531172046e602ec238fe2f5e7d3b2ea5819 29.56MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:66a04b080e544dc2332946c38052c5c7d2e2eb017ccde5b574099e5bc0cc8065 29.56MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:3dafb7ce990955c865f81239572064b14585f7678e94d920166cfd9c3f5df5af 29.59MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:241f8b429e01c0a1a18abd44fd7d9bb47ffd35900d6dae4f787d4e01a2fbbf2d 29.61MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:934b5acae9ef7926edb61751407e0adb478746c714d98ef7b96957850cdd4eb4 29.63MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:de0315f77908b36bded7ff7871773a103329d230a490d071642123afed992a69 29.64MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:cccf212cf4cc833a114e03ad1185251bfc3d908f1bcc7b5153c0d551e1cc8ed4 29.68MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2afb2eb1e42baa07bd1c5c5d4aacb7a4af054a7154270cbba7c82476761ce240 29.71MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:72885a81707deb1d8543ce2134d13691341a7c4fe7a9b3a48f94ad4c9fd1642f 29.78MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:fba19f7f6910ac263c029e59db5969f9213d480ee51e3be9674ec1290a65e879 29.84MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:352d8584ca4cc2e44c565ae1fd0e5ed7d2ce6cad5a35813b71ade3121914f3c0 29.97MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e3b537021da4df14a5624bdfcd493cfe8c99da1aa4d5cd4591ad0ed2b477b0ec 30.19MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ce1cacfe1d27de0711e4d3ea12ae84541160e2beceb2ad7d965e21642ef277aa 30.21MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6a044de06db0f61120dd2aa3224fd223bb0700f5adfdf2b3d98d9bdfb7baac0d 30.25MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a741a1c21aeb6b19d73364947077ad95b9f03bd6a9b62e606b5efc22c87404df 30.53MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:372b2bb393e07c59050476939a5a21876707c4e0ea130a60eae75a4d7f564841 31.12MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:de2a09a071f980349b3761090b374c0d31a44c49673bd976db9830dc38b6840d 31.33MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e0a10bba1818f07243214762dbebfd11c4a6d7175f22a410b7838628a5933600 31.82MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:313e40d8306fc9a7f4a0e479a6f3be58809245890a4bcb00e999a9b1417e912c 31.87MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e1d96d74a2b42252d3fe3840dd179ec9d4e53efc368006f3c5ce69c4b09506c4 32.52MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7356b81aa7304d516ee8a8a279804e90bad57d13296c60fc35bfc93313d1dcd7 32.76MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9481cb1c61f71b18c54294f7ab30b196fdaa0060e3a156a6ce77b5e553fa5536 33.48MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ac029f5f6f561a5255318871a92509074840937aa14908d4fe305a9d43fc067d 34.6MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:72bab76b5562a8d638c9754e23116065700f0bf5465c1aa785423454931595f9 34.89MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:68864141dcd073e3e4379bcaf7bacb1b19fa0c293da25f8835dda9c1660fa8fb 37.69MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:81936105471f5aef77794f125cae27e1e9672b969a0d6d34a173c048a5d37a04 38.36MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:45f8f1755cfb625379b2668e50a87a129abc0bdf96b86954b7b96ef9897eef99 38.55MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:19ff28ff547bb885e50a88bb29be78e8b1e7bdf268b025e7052cf2fc5ce02e47 38.72MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2d88ebc27e93b2648b4368808d0682d6b86fb27e9a8c9117d7591c1e1a3ef407 39.09MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:fa56458364ac2a56f0051268f5e8249e7b9c9d5333b3458d0d7b6d50ecd30bc6 39.35MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2d678de5f6af21c1f812b0ebe17bdea75503f0c5026143429702a791cd1dc70e 40.88MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:54b18f0c1870b759dbdfb6c5132402209d9729c46068ed5115904994153ae3f2 41.01MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9efbeff868ca47aadbbbdb5c9949337505735b38fad00ff82305645bb3b89a0c 41.51MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:983aa85fb9628adb1adc62f8e3869c6f9df87e0874ea92199fedfc6514647e3c 43.34MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:88e435ac65bd0addb7210665e220c2508b54a48678d0e47e199c8f961631c816 44.97MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:57586190fcb74276d1b61cb824e02aae141b6c98b7e2a3d77bffb5e88bee5d8a 45MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7804f363532eba76317364c7c548ddaef6a3f93ebb5edd1e4483e646f7e28f7d 45.86MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:38f2d1843c57344091241ea9fdce07caff856b9fc32fe4a91741a57688eff1bf 47.28MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8dc6794054405e67417c0582d3dfff6e836d46d08acc912ba5bb18153ea4224b 49.1MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6df6866f6fdfdba183f680ad854ec2e81a446c9f8723f35feb81a25ec410f242 50.28MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8affa7ba3e4abed2e987e77f289b4578edb4ee21bc11466945faa97813478dfc 55.47MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6b0b505bf4d22df29cef3cedfdb8bb1947608c70dfde4352e3105c13b7325b6b 60.97MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7b4b6cb225abe0a6d65a4d68f0ccf0f613f259368f4857f2285e0d97a50b1388 62.35MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:b2cb52b1ed8a6c29925130683485ca0ddf26135c902973b59e3b85538e04c4f4 68.26MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:eac1b95df832dc9f172fd1f07e7cb50c1929b118a4249ddd02c6318a677b506a 79.44MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ccedeed05e4207050ef44dd5773c948a2b4f7d85b7cf0ea6f18984518f03d947 83.55MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:01bb209932cb471d1ef1e24722ddcd75ac82426fe74da41338ef3f36893e4d98 86.26MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:74eb221a1190858dea5273c6367499b7047c9aac3d10cdd73898fb7cebc20149 86.38MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ad99100dced0d2119d428a3319f521801e8fc69f5a122d5efb2d6f1acb05399e 90.52MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c71b5003366876faa2cb02eb097f5a5fbf138544e5ea375c1e35bbf77e2a81a7 91.14MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9ec044578bb6db72f1970786cc028eab409debb85ec26c854ff35e63370445a6 91.55MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:6f3b01383337a298930884ef8961ed0e3a7aae2d591fa02adf60212a0ca70e3e 92.83MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:833937e86288cf0810fe2f3f3f091e8f21a23db7572794a8a78f5f1ebec9003c 94.31MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:7e99997cc9b770ec909a5c8098a8fab839337b43013c075505c93b3c3c21a6b3 98.65MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c6bef045b656245e16e8c6e13be1b337652a6289482039d1d033675e9db8eaf1 103.6MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2e6e85f13ac41c7b6440c9ba2ecf21dbe0dda394136f17dd79fd380926da32d9 105.2MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c8177f2abd74bfa004be57007b83db653b91bce59d9087c7d78bf3a5cae206ec 108.1MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5e10dec8216473c24c7e7af88c5366f8ff823d190afd370f953c15dcebe887db 112.4MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e57b924e71694998a52fe5fcd6dd82f27ff3a38e458c2306a59dca8fbc9fb61d 118.1MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:5389bb779808f52baf44033972e885e670994bb9a04b33a210f34ec4859408f4 120.8MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:2302304d5598f1bf063ee89cd5edc404c760dc617f117c2e0aaa6b6e7ca3e5c3 124.4MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:02fe70cbb796b47c80a3982ff567d9af5731c36e693e3020556d8f17c8ff92e1 129.6MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9d0c1d71973a179f98db25d0f5dbfe43ca6f5f3e4a1c25e403203a3370497bd1 130MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:72c8c2eb9a1af31b42cbb99cac5af66fe34ed1bc615f604548c53ca9008347b0 131.9MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:93aec587377458c393edef72be660cd67c8934923dd2efe3f0b2361e2eb14060 137.8MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ad3dfe687ff1b4eac6f7feecbc801071a3823a212ab8a8c0dde1783600f22b53 150.9MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:9bd621fd25b3f6af722a9927011e2c52ada9eda0553adfb03361031c60e09257 152.7MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:a9431271827ba69daa92d11245bb50e7e05c041b89b4090b862860283f57574a 186.4MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:8b9a0c1273777e2405d56f6c32a8719dda4dd7eb426b42933fa6181cbe2798be 254.3MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:ab91fda21693d6bea099bdff18c74abbe85c31dea5f23daf226adef3a7660ab2 275.1MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:e45e03a1e673b1352ef34df7c6204429b08de25e1c3b99667534e1f9981f563b 401.9MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:cf8acd280d29161aab647117ba03bedf28eb769ccda11b727edc1ae9e4676830 412.2MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:c9aca95b77ccaf9dc5a6e7b0092a5c93bea35b44f3e4bc914c62768581d07148 421.2MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:95bb11286ffa4629626361161846b587eaebf7e6fc5be9b59120388d459a1aea 433.3MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:47ee8eb7287d509cfcae37ba8303369a92d248e0205255d1e2625a466044b54f 434.3MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:4620514455f3b1051f0f4460ed9dba2cc6e72edde663c96648facf59f3f03a76 435.8MiB
         quay.io/openshift-release-dev/ocp-v4.0-art-dev sha256:16726b8f329ac3282e9b197e9567fa906fa4b67dd74ada5583eedde1acef4cd3 1.029GiB
       blobs:
         quay.io/openshift-release-dev/ocp-release sha256:6ffd19ad5e066b803c98f9304bf99e821de79e726f62bd96f2196c84b0feadc4 1.731KiB
         quay.io/openshift-release-dev/ocp-release sha256:47aa3ed2034c4f27622b989b26c06087de17067268a19a1b3642a7e2686cd1a3 1.747KiB
         quay.io/openshift-release-dev/ocp-release sha256:3fb8184e9de5f386c7421a08dbddd2217af4496f6f13ec448bbaeb0d87edbfcd 537.8KiB
         quay.io/openshift-release-dev/ocp-release sha256:450c1856cde291bbe8de8e7eff490e70c10d4bc6f3f51c1f4f6170bd529ca925 6.133MiB
         quay.io/openshift-release-dev/ocp-release sha256:930a24a335705c0b20fe79b020f568f998354e975373e27ce42982fd3aa323fd 10.68MiB
         quay.io/openshift-release-dev/ocp-release sha256:b1090b12aaaef17b6379025090b47edceb857b424e7c6b6658d42ab0856833a7 21.32MiB
         quay.io/openshift-release-dev/ocp-release sha256:eac1b95df832dc9f172fd1f07e7cb50c1929b118a4249ddd02c6318a677b506a 79.44MiB
       manifests:
         sha256:01ecfa030ee5975d85afa62ca4df4560748ffb263c1aa52494929951c02a4f11 -> 4.9.7-x86_64-cluster-etcd-operator
         sha256:033ddc1e24008c6183722e6a0583ac050f0fa157485508e165874d43f2bae6ab -> 4.9.7-x86_64-openshift-state-metrics
         sha256:03b88f06eb9727fdcc3e393bed85203ab3ba9d585ba2b9f69fbddc2f4d872c47 -> 4.9.7-x86_64-ovirt-csi-driver
         sha256:04c9df04f725722cc4ff6799ca928c86c91f1bb0ec342d6251fc58940466c88b -> 4.9.7-x86_64-operator-marketplace
         sha256:053ce06d7890d34a628c71db07f06e3a4de6e652dad444a63727e4d0fce1441e -> 4.9.7-x86_64-openstack-cinder-csi-driver
         sha256:0af4ea37b14033cf6bfbce81a20dbb60ee04dc7e28f9aa890e151834e8400a88 -> 4.9.7-x86_64-openshift-apiserver
         sha256:0ccaeb1a468008b32fc9cce0ac5c486648f8622dfacce5814c4dac82feee5daa -> 4.9.7-x86_64-multus-admission-controller
         sha256:12fca9bd40b0ffe218ba7e469b321b46c14ef6e90afb4a82101139a7e91d7d7c -> 4.9.7-x86_64-aws-machine-controllers
         sha256:130c0f1053706666907afb64900df1dd627893d8979cdb56d7ed9da2f01f9db1 -> 4.9.7-x86_64-cluster-dns-operator
         sha256:13201e0adde9ac709d5588b9e59de0dbc313dd1c095ffd4bf535369ccf4e934c -> 4.9.7-x86_64-ironic-static-ip-manager
         sha256:1410141d4cbedd0d98af5376d0f0ce7764f1a84f0657034b5f958a94c345fe8d -> 4.9.7-x86_64-deployer
         sha256:14af1530eb9ec2f1caf13990b4356c0f1b35fa2ff2519b0e08a9752190e8c773 -> 4.9.7-x86_64-csi-external-provisioner
         sha256:16033ec3aed9bbf059909a0afb3d5a98a09129c8d51c1ad6cf75566a3808f54a -> 4.9.7-x86_64-cluster-version-operator
         sha256:17bfe558a9b7201bd2e58bfc4fc73230a530ffc423fe082f9b7fdc870dd01271 -> 4.9.7-x86_64-jenkins-agent-base
         sha256:17e245626b90fd1e73936c3840d3f27dabb7100cdd07d8945c5c3d408dc55dc3 -> 4.9.7-x86_64-cloud-credential-operator
         sha256:199b3a8fe3a5a64583afd1263d753de504dc9c60d31df443bd764fb2f39bdb43 -> 4.9.7-x86_64-oauth-apiserver
         sha256:1a530a0d0dbbec578ea6b0cbd901d78f4a395a9896fae1df05c3c940337ccb3e -> 4.9.7-x86_64-sdn
         sha256:1a56399b5c2fe169156cd5e410abb021e3714d1ee08db6927932a989273e053e -> 4.9.7-x86_64-cluster-kube-controller-manager-operator
         sha256:1f583ea8fb1035753979e3adaec1f7668e920e8d8a94cddf0646b723b16b6d9e -> 4.9.7-x86_64-network-metrics-daemon
         sha256:238194aeaf2f240e800e99195103a75b3c27ad57cb3b31ceb34b187850d78946 -> 4.9.7-x86_64-multus-cni
         sha256:2451bc005859a0987ef74382c4b839e900d7e903c77663840ff0ed0207a47635 -> 4.9.7-x86_64-csi-snapshot-validation-webhook
         sha256:27fb78cf79e0ece439b68c361591e94d425c4c5ae2737f868aec095f14ab2786 -> 4.9.7-x86_64-container-networking-plugins
         sha256:2ad7eab3629a7475f9f809a9df22ad0eea5f172a5c151c8143f1f18ac73ade37 -> 4.9.7-x86_64-vsphere-csi-driver-operator
         sha256:2ce9667775acdefcff0a90199c2b87b001b98d7ea5b5e7ed18453ba47b318235 -> 4.9.7-x86_64-baremetal-runtimecfg
         sha256:2ceee2ebe189d8c18a1899f9f2cb0af0dca58d14c415777f26caa689d1339b1f -> 4.9.7-x86_64-network-tools
         sha256:2d4d74c0bf35a4d08c619d9f58b21cc1a888338702ccee982cf89b0479f78893 -> 4.9.7-x86_64-cluster-node-tuning-operator
         sha256:2dec93a89cbefc7c50d867fe420647f27c602d2643419bf41015bb51177d19cb -> 4.9.7-x86_64-egress-router-cni
         sha256:2f51eba9bed3db47a06578298b8e06db68e0f88c6be66d7120829495ea4458a1 -> 4.9.7-x86_64-service-ca-operator
         sha256:306883a3908244448769eacd7dbfcf209ec56dd03021823a2941799be1be676b -> 4.9.7-x86_64-prometheus-node-exporter
         sha256:308b56720ca4bc317b4edacc6c5f266c9ce86f7ec6fde15aca24776a47127c31 -> 4.9.7-x86_64-docker-registry
         sha256:32a461d8ea341926133857f586dd602f7fe85c608ad93e46d07be7298fb5a6cb -> 4.9.7-x86_64-coredns
         sha256:365a6e46b15a074f268417c1472c6d79ff85d6062b6af59628d094cf53b4e7aa -> 4.9.7-x86_64-jenkins
         sha256:38c1ef9d44f4a90bf83f3dc75f2aacc6478356c7fa2708c881e914af4df5c8e8 -> 4.9.7-x86_64-hyperkube
         sha256:38c835034f6c3f509771217a6236379b90897d8e041a4bfe780b7c23630b021a -> 4.9.7-x86_64-grafana
         sha256:3b2d37c7858d2cd9366be804b63173467cc34815aa2d5e389158972006857f30 -> 4.9.7-x86_64-vsphere-problem-detector
         sha256:3b965dbf1f0f5b173ef961d71a04d36c41831b8086ee8b33607ebfe1cc7ac158 -> 4.9.7-x86_64-cluster-ingress-operator
         sha256:3ba48e83d25460644a26005374596dff2b39bebc305d1e2d6d07c3eb55bbbbf2 -> 4.9.7-x86_64-csi-driver-nfs
         sha256:3d0b4e7c95824f18fd9d6cc00fe12e13516a170d55f9c4d0ebd51f5074ccb688 -> 4.9.7-x86_64-operator-registry
         sha256:3d3323102b9c0076c08018789b4865058d280842e97a36fae1afea13b00a6cee -> 4.9.7-x86_64-cluster-authentication-operator
         sha256:3de4983cddbf5a2c92f71ceaf087434c50e8d5e193ffb9cf6f21c69d662d3933 -> 4.9.7-x86_64-cluster-kube-apiserver-operator
         sha256:3fa748cf130e1d5100b029a6c6e357b143242e246b7114fd5f288a08e009797e -> 4.9.7-x86_64-cluster-update-keys
         sha256:4491e2aa17088ba7461019aacedd713cbc70becfa60962123b65290308f449e9 -> 4.9.7-x86_64-azure-cloud-controller-manager
         sha256:45c72c864086f0cfa47c69b57a3d8dd753be4069ea3f0f6850e1c89c5ab2501f -> 4.9.7-x86_64-ironic-machine-os-downloader
         sha256:49dfda0a23064a8b82acc977b4e5554108a7c55b1e0259bf23f82f579267d1ce -> 4.9.7-x86_64-csi-external-snapshotter
         sha256:4d76d15cd9636109bc60931e4b85143852d2dd8d24d42e66785256ff4dfbc3f5 -> 4.9.7-x86_64-operator-lifecycle-manager
         sha256:52042dbf174836944f9a03271499504f3a0d7a745a56693db0a386eea02afbc9 -> 4.9.7-x86_64-multus-networkpolicy
         sha256:53de0ae3fb21fa7e617a20862b7824707d201306ca639132a9a94cc234435ed1 -> 4.9.7-x86_64-azure-disk-csi-driver-operator
         sha256:53eaae5fadd9f9585797a0978a1a39ef46a064d2f46810aa59e5f4a8577d2444 -> 4.9.7-x86_64-cluster-cloud-controller-manager-operator
         sha256:54a933585eea48ba4ebd8ce3fa61687d05d0dd38ce4b03cde8d4006e081d22a9 -> 4.9.7-x86_64-cluster-kube-storage-version-migrator-operator
         sha256:55672d1859385409273a984375b226bb29b49c3130237be3bd5241684c01aa9e -> 4.9.7-x86_64-ironic-ipa-downloader
         sha256:58cf3f6650938559b316a8487562c32086bab77adec7cf1fce8022825882c687 -> 4.9.7-x86_64-insights-operator
         sha256:5b0db3d158efadae362e068a796920a2c9184b2a3ae2188063904a90547394c1 -> 4.9.7-x86_64-baremetal-machine-controllers
         sha256:5b12e15bdb08e5b6d47f3ffc5ef59321eee3f994779235bc19a78080b3cc63b0 -> 4.9.7-x86_64-aws-pod-identity-webhook
         sha256:5b82201b95d2d6ad49a0acf957bd96cc266b06c5066dc4ac07f7ed90edf507c7 -> 4.9.7-x86_64-aws-ebs-csi-driver
         sha256:5c55be02e32e688ec5a404858a08cf533ba15b50b6f0e028089635b47db5866e -> 4.9.7-x86_64
         sha256:5c6e763d01ed9eecbfb02dbe47b0b66abd9943126f3fb3cc6de9041007af8a36 -> 4.9.7-x86_64-cli-artifacts
         sha256:5e620f670b78ae31e9f01b5439cd9223c65d5a722c2742f0f73dcbe8c31237b8 -> 4.9.7-x86_64-cluster-baremetal-operator
         sha256:5efb96bd375d8248bd891743b46385329f1b211c0bd4b0dde58bea2a63b99486 -> 4.9.7-x86_64-haproxy-router
         sha256:628d2d1e8898aab03e0a0248dc53cd1bba8ce76a2b23201ea6ee0a9e4343db01 -> 4.9.7-x86_64-csi-external-attacher
         sha256:63eb87db627320e0134b538daf63566d3d19749491ed4a266a4088aa03e8fdb9 -> 4.9.7-x86_64-cluster-autoscaler-operator
         sha256:650d86ec3b60e373e0db0214e4fc3dd424d67f589d6dab8de9c250e54ae62af4 -> 4.9.7-x86_64-multus-whereabouts-ipam-cni
         sha256:65369b6ccff0f3dcdaa8685ce4d765b8eba0438a506dad5d4221770a6ac1960a -> 4.9.7-x86_64-driver-toolkit
         sha256:67efca98ca6f362bf75eb12e8722245bb1264d64d94cbcfb0f66365b84cbec4d -> 4.9.7-x86_64-must-gather
         sha256:6949da0886e5c938aa308dc49bf45431538e554d958a730c8ee2555cfb5d4b37 -> 4.9.7-x86_64-cli
         sha256:6dbd05798bfcb09c072e9ab974133cb5d415f13d1dc3831fca4a33c529a6fa3a -> 4.9.7-x86_64-docker-builder
         sha256:6f076502c8ddf922eb238a941f76fdadf8ddbb83a3e6d07f99def1a4bfde1d77 -> 4.9.7-x86_64-openshift-controller-manager
         sha256:701ffd1c51a84b9b712fed1a2681bb917b28b2170939252871701c0ab3b5b1fc -> 4.9.7-x86_64-openstack-cinder-csi-driver-operator
         sha256:708cc4c2a19a52fdabb4f2f5ddf575c1c896c981ee15b678b93b5cd1072937c7 -> 4.9.7-x86_64-vsphere-csi-driver
         sha256:717fcc233a77be33872984fbe37ccaff2ecce0da5de11df59b1a3bed55d71fb1 -> 4.9.7-x86_64-cluster-openshift-controller-manager-operator
         sha256:718902f807c8269d5ada075dc258df209b0cc309eb58600aa55a63234f787273 -> 4.9.7-x86_64-installer
         sha256:738b21ab3a9af2f3dbc2e0be5a598d9b10f27afcb6c3504c4a9b0c62f02724a6 -> 4.9.7-x86_64-console-operator
         sha256:74f37c929e78bb96bc07a0870fdbd52741e82b429a0794440651c408f5160795 -> 4.9.7-x86_64-baremetal-installer
         sha256:7680102adb86388a3ae7399d25e14fbfd0f8bbf3c6377653f88b7104ef0509db -> 4.9.7-x86_64-telemeter
         sha256:7ca795f6897e5057ca7c1c2bfb2e80fba1ba479be72ade1d81c7fbadfe9eb10f -> 4.9.7-x86_64-multus-route-override-cni
         sha256:800172d60861c4d7018e23cbac3c802c59fccda92848818b072f929a343b2889 -> 4.9.7-x86_64-gcp-pd-csi-driver
         sha256:80ac8e87d79736479565f9e780fe18ee0d6b9c95d1029b6e3b488326dad4ea80 -> 4.9.7-x86_64-kube-storage-version-migrator
         sha256:821f460b926444b9edd0bc04289050009e9ea3d5ca0d722451b76467a166f0c6 -> 4.9.7-x86_64-cluster-bootstrap
         sha256:823f071c623306435b53fe42db79a663a62c435b7284be0fe2befa2553af3752 -> 4.9.7-x86_64-kube-state-metrics
         sha256:825ef5eb718e3757ef1a4df1b40917ec50a3f78d79b34273ad460515ffdc020d -> 4.9.7-x86_64-console
         sha256:8277f5f94b0e4db67f490d8e01cb524c3890c404738db0118f647936d75f5abb -> 4.9.7-x86_64-pod
         sha256:84be0fe13eb20a33ef01d0c31809b84a97fa754d5d17791e43b4f477608ffe76 -> 4.9.7-x86_64-ovirt-csi-driver-operator
         sha256:852fced3a8cdfe1ac8edc4a8c1f022e33ced4c080e09c2ea4a9fe7dc92d4ec0f -> 4.9.7-x86_64-oauth-server
         sha256:868279f5315c4582c971a7b2d20b951773544ea280a161ae389eb5b0fd715424 -> 4.9.7-x86_64-cluster-machine-approver
         sha256:87f042dca494bf46dd5604e84c1a5b965fd53375093fe7006dee004bcab188d3 -> 4.9.7-x86_64-azure-cloud-node-manager
         sha256:881c259179500e163e0f8f4e6f2b425408daacc26c2cde4a7095e90776d8060b -> 4.9.7-x86_64-tests
         sha256:8b1af36bf0985b6a2bb486b02553a89091ad71a067959d9840391ae5f9e8ceda -> 4.9.7-x86_64-jenkins-agent-maven
         sha256:8de8d8a3289b2e477d279bc1f3ea03fe7785c219a426814e9ae14b891f635855 -> 4.9.7-x86_64-thanos
         sha256:905ad7df7e6900619c73f144ccbc1b5e60a8b0dcec73c099470ef43a7ee1bbe8 -> 4.9.7-x86_64-cluster-autoscaler
         sha256:9065acf7561d962955488b476b3f24af3b8b72b2fde1690cb35d3245c53c6390 -> 4.9.7-x86_64-vsphere-csi-driver-syncer
         sha256:91d524f71d0e7acb7c89eea38eafda21af342d668c26ed538bb1d4697137ec17 -> 4.9.7-x86_64-oauth-proxy
         sha256:92e975189cb58919e8a2811edd414f5be5b759dcd61762a6e9ab1bee50200cbb -> 4.9.7-x86_64-etcd
         sha256:9665c5b4996ad961fffd2672f7bf61654b9700e3ab9cc954e6892c8f8d2f635d -> 4.9.7-x86_64-ironic-hardware-inventory-recorder
         sha256:99754e32729f454eb82af5e3a29c35ec41f17418a6c83a0bacbc666f00c52695 -> 4.9.7-x86_64-ironic
         sha256:a2d509765b7f3a23cf3d780878bc8f1fb0e908b5c2c98aea55964d4ee9f44791 -> 4.9.7-x86_64-aws-ebs-csi-driver-operator
         sha256:a3e1acdad51d67db44badac6ab046e1aa2b2a40bb530a2c7ac184d86195817ab -> 4.9.7-x86_64-baremetal-operator
         sha256:a68a352a5e835daa99352c73bf13032436a148b02af8cee4d555bba969cca24b -> 4.9.7-x86_64-machine-api-operator
         sha256:a6f6387a01f0275c777b4dee489967227a84d1cbea504d972a394c4ea48437df -> 4.9.7-x86_64-tools
         sha256:a9532f0636367a6776915e79332e6acfbc1cf6875f9477236e651f20435c70c3 -> 4.9.7-x86_64-prometheus-config-reloader
         sha256:aaea2c8986613d921d83db5cc346f3ec7ecc6335b5fa09d74907a9cec4aa8fdb -> 4.9.7-x86_64-kuryr-cni
         sha256:ab9d9256d43783a061c613d78abd8eabb2323798098fb5dbe63c4ca13318b0c4 -> 4.9.7-x86_64-mdns-publisher
         sha256:ac2ad5b01eed7b0222dabbfb5c6d4b19ddc85bdaab66738f7ff620e4acffb6ac -> 4.9.7-x86_64-machine-os-content
         sha256:aca06b6adba4da8e4087cbbc1cf585e37b237bce377bc4918fa9991c7e79942f -> 4.9.7-x86_64-prometheus
         sha256:b20b1ce89582ee300a88e3de5226c09b31ae2b6e05de74b5e1c89b2bb56800c7 -> 4.9.7-x86_64-azure-disk-csi-driver
         sha256:b42499bdb227da2d2d4f81def7271598e3d3a4386e71f95c6c1c06210cba4bcf -> 4.9.7-x86_64-aws-cloud-controller-manager
         sha256:b426482b2bb57fb6a93611fa7e6a77200d8312458c2383a37ae743732114a322 -> 4.9.7-x86_64-ovirt-machine-controllers
         sha256:b47101401214acae9f8b92ef4b6ee38564206a9cd5215a087a12ce63c7f485d3 -> 4.9.7-x86_64-cluster-policy-controller
         sha256:b7aa0776dad20a024ed5df80ae8590ad973376aca1af4cb7dfb60a7af9e69415 -> 4.9.7-x86_64-csi-driver-manila
         sha256:b7deb0532f3c38759685e5bbece97417e99d9bc26b4b2a8414cb4963ec38ff3b -> 4.9.7-x86_64-kuryr-controller
         sha256:b84ba4ecf6d5682d66d198aface7884ce5adf51f341f1ea47b741e6018854dca -> 4.9.7-x86_64-libvirt-machine-controllers
         sha256:b8be5c3293d4f4096132a4a436a6d6cf14c91711a3566aea2fe4728436f997a5 -> 4.9.7-x86_64-cluster-image-registry-operator
         sha256:ba56e5195741e54e654face4997c5c40be083f5302e5903983415e86a17a0e86 -> 4.9.7-x86_64-ironic-inspector
         sha256:bb6c09cf7cc43e3a7ab8a0ee068db87552e203d351321fcaa3a1840d59c444ed -> 4.9.7-x86_64-cluster-config-operator
         sha256:bd6ad5c429fb7e31e6045e7927f76210c22e7573f387bc61168520ff4453e2c0 -> 4.9.7-x86_64-configmap-reloader
         sha256:be638091383eadef518fcdad50493bfde851f8010d6d2c57e0f9cecc0f70f48e -> 4.9.7-x86_64-keepalived-ipfailover
         sha256:bf8ab195054fa186a310f5534806e47178c3354daada970f3545e7d0a7dcbb07 -> 4.9.7-x86_64-kube-proxy
         sha256:bfa5e4216d205199490cd7358da492e060be4fe6c654a8713a41218d4047ce46 -> 4.9.7-x86_64-azure-machine-controllers
         sha256:c0e1e8b8bf3b6cbbed2fb00aa21dbd3235ee20f66fa0d82860dd216098fbf2cd -> 4.9.7-x86_64-openstack-cloud-controller-manager
         sha256:c45687f4b08bb8d1e69342fa29da14298f58c755054954777261eb9f3976243c -> 4.9.7-x86_64-openstack-machine-controllers
         sha256:c66f7404d5cc5d3203c941290b4fc5433154dfca4f9900fda27eb40ff1b460cf -> 4.9.7-x86_64-csi-driver-manila-operator
         sha256:c84ffc50d0ca44b7aef6e4d9b8c791affc5404a047ce7e9b73208b5c96ae0e21 -> 4.9.7-x86_64-gcp-pd-csi-driver-operator
         sha256:c8d625f6d7fe4bddfd9e7ff1801bd0d608153057b2eaac61790bd78a939ba53e -> 4.9.7-x86_64-cluster-csi-snapshot-controller-operator
         sha256:c98a79fd2cd933603ec567aabce007d1ccee24cc8e5bf12f8ead9507c5cd67e3 -> 4.9.7-x86_64-ovn-kubernetes
         sha256:cf349629029e936efe55b99176fc7b30834b49778330b67b7de89205bb98dfe7 -> 4.9.7-x86_64-csi-snapshot-controller
         sha256:d2ae96692553d6c08218aaa883c147172039bbfae2dc719579f193e116a19e18 -> 4.9.7-x86_64-cluster-samples-operator
         sha256:d70923a803680c2221ca58c35fc296bb01797c7a4c2c8feeffe8e55f350a7139 -> 4.9.7-x86_64-prom-label-proxy
         sha256:d89c6d40803507c97d2e82995d712c70040edca64fe627c47bab03d28d1e3068 -> 4.9.7-x86_64-k8s-prometheus-adapter
         sha256:da3185ad005ba094e86c4d7484c591ed6e81bfae7a8760bd33e0772bcfda53db -> 4.9.7-x86_64-cluster-monitoring-operator
         sha256:da71bad01f548cbc81e271eff00c810a19f3bfbf717f221124a846c89f0d9ed1 -> 4.9.7-x86_64-prometheus-operator
         sha256:daee78847a7b8a9f000129270decd4751e0cd2694bcab6e81cf1b98b0b592d2b -> 4.9.7-x86_64-csi-node-driver-registrar
         sha256:dd7bee3938a03ca4adf7e463bae2edb257ac2788aa7d81881b257cde9bb977dd -> 4.9.7-x86_64-gcp-machine-controllers
         sha256:de21b72c912e534a2e1713c870963ade63710bb684ec5a9e3c994b421adf7926 -> 4.9.7-x86_64-prometheus-alertmanager
         sha256:df0c66fa32624c2f286629fe88be9e602f756698317e73c258eb4dd7319d5e3a -> 4.9.7-x86_64-cluster-storage-operator
         sha256:e182d8ac108fe6943f3d1187f8b8825de3b87ce19084514e841d7e351bec93ee -> 4.9.7-x86_64-installer-artifacts
         sha256:e6f50c7ffabcc0b6ccae73c3a3dc5ad20a94137f9d8c98473eaaf437b8c2da93 -> 4.9.7-x86_64-cluster-kube-scheduler-operator
         sha256:e9c11afc09113059eb64208da91e1f81bde9acda6e2ee11425c440622be21663 -> 4.9.7-x86_64-cluster-openshift-apiserver-operator
         sha256:ea30e26dfd31644c94ea2e470211116f1b85dd8f5e828365be577d439db0dd43 -> 4.9.7-x86_64-jenkins-agent-nodejs
         sha256:eaf8eb2df8bf32e3d44f86e8eff0437937ba1b3ac9dad72e53dba5a447b3d886 -> 4.9.7-x86_64-cluster-network-operator
         sha256:f4ddae7f0218896f038c812e5becef748648a552080474fedf89cbbc677b939c -> 4.9.7-x86_64-csi-livenessprobe
         sha256:f72aa34decd784392a5784e93ffd8616445c3f749d932e4f9502f29523493e4e -> 4.9.7-x86_64-csi-external-resizer
         sha256:fbae5e73411bed5c2eed978369f7b53c4848e07218b7dfc0ab63c2f115c890f4 -> 4.9.7-x86_64-machine-config-operator
         sha256:fc81c6614a38195a7c0f9465135a1064e6cbca09bce42653cb0f5b8d0513965b -> 4.9.7-x86_64-kube-rbac-proxy
     stats: shared=5 unique=285 size=9.438GiB ratio=0.99

   phase 0:
     lab-installer.karmalabs.corp:5000 ocp4 blobs=290 mounts=0 manifests=141 shared=5

   info: Planning completed in 27.29s
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:626b321f688cb48ef17e00764ff950943e6f776ad0d42d229dedeb4d6a1db3d6 17.16MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:fba19f7f6910ac263c029e59db5969f9213d480ee51e3be9674ec1290a65e879 29.84MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:53de18eed10c0b7e53ab8be2750768cfdcc1df9e320c06bc697ff19aa5603908 374.5KiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:fa56458364ac2a56f0051268f5e8249e7b9c9d5333b3458d0d7b6d50ecd30bc6 39.35MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:7a9eee3b7981073f117952604a5cd2b32814bfb7ac37047c2cedc5426791a785 9.476MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:4b2bfed57f6412e6513a60e0491be8721592df856726494e79c8553118f77897 11.45MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:a0453b87f28599bd146de4333b3bb6bda5a24c550308a9c8d18c5c50f84e4824 28.83MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:7356b81aa7304d516ee8a8a279804e90bad57d13296c60fc35bfc93313d1dcd7 32.76MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:88e435ac65bd0addb7210665e220c2508b54a48678d0e47e199c8f961631c816 44.97MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:cf8acd280d29161aab647117ba03bedf28eb769ccda11b727edc1ae9e4676830 412.2MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:93aec587377458c393edef72be660cd67c8934923dd2efe3f0b2361e2eb14060 137.8MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:e0a10bba1818f07243214762dbebfd11c4a6d7175f22a410b7838628a5933600 31.82MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:802e95f73fb87648a0b168369a6b8b2d8cd86b25a08317ece4bbf418b3737053 28.26MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:e5719d450d133998894141a5f56fa3ca62d9bba8c3a4c14a0f23d2dd04aa8bac 16.92MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:15ecbe9e118c3bc0e4e585da1539383435d8f2f4aeecf4ad0ce5ea5797e5adff 24.64MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:2d88ebc27e93b2648b4368808d0682d6b86fb27e9a8c9117d7591c1e1a3ef407 39.09MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:c8c0554931286354ee41452f49b63ef27b72b0b92c3d44f84a870597fdc94761 17.44MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:f5c7b4fa93b9d218e99110ad3eddaf04784ab55077ad1dc574266d8e5f5ad04b 13.44MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:66a04b080e544dc2332946c38052c5c7d2e2eb017ccde5b574099e5bc0cc8065 29.56MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:ccedeed05e4207050ef44dd5773c948a2b4f7d85b7cf0ea6f18984518f03d947 83.55MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:e54107e78c6408f1da8f297c9257acce8c12342fc9081b73cb64f6f191ef97c0 9.386MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:8a41da6cec2398e936fb11fbe66344278f9bccb4552667d16c9cf7bd2a3d44a7 29.01MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:6df6866f6fdfdba183f680ad854ec2e81a446c9f8723f35feb81a25ec410f242 50.28MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:0b3793e01f41d947f8bce3b51f6b419a5526431686f5fb8be092d66a288bdc17 28.25MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:a3c8f12d44d6493423ad9e28fef942b73e66d005143faed486226a96ff3f37e3 8.9MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:2302304d5598f1bf063ee89cd5edc404c760dc617f117c2e0aaa6b6e7ca3e5c3 124.4MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:33a119f5e566aa590281b2842b9f03d7c405b4988f626e5107878da8c3f9a7c4 7.585MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:367f4b46a5fe7586aaec3634167371eaf51987196ea7a6cc95afe601d9955c8e 14.86MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:445e5ef5e706881c789bc938c70c6bbbf90dd06f1afc113710da68e654152fd2 19.7MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:e293256dc1ab2a9495dd7204625cd9f8a273d0d3da3f18526bcb150496f7a1a3 21.33MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:9efbeff868ca47aadbbbdb5c9949337505735b38fad00ff82305645bb3b89a0c 41.51MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:0749408b74331c62d4ee9ac898d4ac15790e0dfefca6698f0edd46019fd2dc3f 4.802MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:a72d0b8729ec3eb4367676c92680df04228e6971323d143b7d067c4d58dae198 6.993MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:cccf212cf4cc833a114e03ad1185251bfc3d908f1bcc7b5153c0d551e1cc8ed4 29.68MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:6f3b01383337a298930884ef8961ed0e3a7aae2d591fa02adf60212a0ca70e3e 92.83MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:2afb2eb1e42baa07bd1c5c5d4aacb7a4af054a7154270cbba7c82476761ce240 29.71MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:720275e24950d9fb54b7ad5a62a21505c3a666f050d8d0a7deb78b8062bbe3b1 27.25MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:e50ca0bc0533a68185ae4d6886dac4d54656369bd4324f06ec78d51e9cabfed1 28.41MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:72428c44ac70b800d0d7027b9a782c57ea1c49a1006490a0375d8bc7b77642e6 14.15MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:f314371d464bc25b8d9e1875b9060fd63ed60df06d819413948d955eb5d35d04 18.18MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:930a24a335705c0b20fe79b020f568f998354e975373e27ce42982fd3aa323fd 10.68MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:048edbb18d9b1752c92ae662c195bdcdd515a6a4333c9a5c014ec34868467114 11.85MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:81936105471f5aef77794f125cae27e1e9672b969a0d6d34a173c048a5d37a04 38.36MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:e1d96d74a2b42252d3fe3840dd179ec9d4e53efc368006f3c5ce69c4b09506c4 32.52MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:352d8584ca4cc2e44c565ae1fd0e5ed7d2ce6cad5a35813b71ade3121914f3c0 29.97MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:64408119965c952b5c82666873dafd71ab13d3ed2c9c31f8f4ebe22d7db9d504 24.78MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:ab91fda21693d6bea099bdff18c74abbe85c31dea5f23daf226adef3a7660ab2 275.1MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:8affa7ba3e4abed2e987e77f289b4578edb4ee21bc11466945faa97813478dfc 55.47MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:9fa7e6e181436a42f71ad38303d0bd0f360e3256b3635ceb2ef620dd5cc60377 25.78MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:09dd8cae3e466952936c3d0dffac28a96ca88bb87311b008b54384e38b6e401e 17.87MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:8fe48571d13bcd4928aad13cacc72caf04116c089d964c37c53b5138d20d0e05 25.9MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:95a7976d52f959cad92d750e5b0c4dbf5d689f2a81159b48f459b5b04f276e1e 8.801MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:38f2d1843c57344091241ea9fdce07caff856b9fc32fe4a91741a57688eff1bf 47.28MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:241f8b429e01c0a1a18abd44fd7d9bb47ffd35900d6dae4f787d4e01a2fbbf2d 29.61MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:16de42bf1c6e1f05cb0109c3f6fa2d42c7ce63f45afa3c92b7904160cd6ded3e 2.716MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:e45e03a1e673b1352ef34df7c6204429b08de25e1c3b99667534e1f9981f563b 401.9MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:ad99100dced0d2119d428a3319f521801e8fc69f5a122d5efb2d6f1acb05399e 90.52MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:809e9fdf6fc5aa3940ff883cceab0da5bc7ef663b68b7eb96b52d2f70b6668eb 12.14MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:54b18f0c1870b759dbdfb6c5132402209d9729c46068ed5115904994153ae3f2 41.01MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:52e1e0b0ae9ca461e6878abc19455a9e912cf76c5375c182bd69de34ab6e1fd5 25.35MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:9ec044578bb6db72f1970786cc028eab409debb85ec26c854ff35e63370445a6 91.55MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:6a044de06db0f61120dd2aa3224fd223bb0700f5adfdf2b3d98d9bdfb7baac0d 30.25MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:72bab76b5562a8d638c9754e23116065700f0bf5465c1aa785423454931595f9 34.89MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:02fe70cbb796b47c80a3982ff567d9af5731c36e693e3020556d8f17c8ff92e1 129.6MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:16726b8f329ac3282e9b197e9567fa906fa4b67dd74ada5583eedde1acef4cd3 1.029GiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:ad3dfe687ff1b4eac6f7feecbc801071a3823a212ab8a8c0dde1783600f22b53 150.9MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:5e10dec8216473c24c7e7af88c5366f8ff823d190afd370f953c15dcebe887db 112.4MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:b1090b12aaaef17b6379025090b47edceb857b424e7c6b6658d42ab0856833a7 21.32MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:ac029f5f6f561a5255318871a92509074840937aa14908d4fe305a9d43fc067d 34.6MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:57586190fcb74276d1b61cb824e02aae141b6c98b7e2a3d77bffb5e88bee5d8a 45MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:4068a75a5665067da383d3472fb15010c6ede8296673f468cddf31372e1a7431 9.534MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:2e6e85f13ac41c7b6440c9ba2ecf21dbe0dda394136f17dd79fd380926da32d9 105.2MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:9481cb1c61f71b18c54294f7ab30b196fdaa0060e3a156a6ce77b5e553fa5536 33.48MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:5389bb779808f52baf44033972e885e670994bb9a04b33a210f34ec4859408f4 120.8MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:8b9a0c1273777e2405d56f6c32a8719dda4dd7eb426b42933fa6181cbe2798be 254.3MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:d657b2cdecaf6f68f08f7038b5f01136a92ca82ba6afd4c1304b47da58b0ba6d 18.92MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:74eb221a1190858dea5273c6367499b7047c9aac3d10cdd73898fb7cebc20149 86.38MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:2d678de5f6af21c1f812b0ebe17bdea75503f0c5026143429702a791cd1dc70e 40.88MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:313e40d8306fc9a7f4a0e479a6f3be58809245890a4bcb00e999a9b1417e912c 31.87MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:1c243b082d6332976400a9f2bd280e43d255b0b076ba9918041f277db7fffacf 25.42MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:0b0334e3d50db81777ea74adad1b2fa7d348bc386122144e76589161ba0da6d2 29.15MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:b679ce34f2e79abb75e66c6d0b8d8eea9b78fcd948a4973e7bda10fccc98e094 25.98MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:b2cb52b1ed8a6c29925130683485ca0ddf26135c902973b59e3b85538e04c4f4 68.26MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:7a02c97f53bb3e4b7ff01c7f682e55639cb6103b94fd40ba987b25805aa8c0c2 9.219MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:9bd621fd25b3f6af722a9927011e2c52ada9eda0553adfb03361031c60e09257 152.7MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:c6bef045b656245e16e8c6e13be1b337652a6289482039d1d033675e9db8eaf1 103.6MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:247117ceab4073d061c36bfd7702ba20e02b2cdcea47fbc2da6fad6af325e095 24.45MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:47ee8eb7287d509cfcae37ba8303369a92d248e0205255d1e2625a466044b54f 434.3MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:3dafb7ce990955c865f81239572064b14585f7678e94d920166cfd9c3f5df5af 29.59MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:8dc6794054405e67417c0582d3dfff6e836d46d08acc912ba5bb18153ea4224b 49.1MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:de0315f77908b36bded7ff7871773a103329d230a490d071642123afed992a69 29.64MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:d857582bea95499dd10bda291d820dce6c4fda7c33810406ec2cea2dfaf462a1 21.11MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:e57b924e71694998a52fe5fcd6dd82f27ff3a38e458c2306a59dca8fbc9fb61d 118.1MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:45f8f1755cfb625379b2668e50a87a129abc0bdf96b86954b7b96ef9897eef99 38.55MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:c9aca95b77ccaf9dc5a6e7b0092a5c93bea35b44f3e4bc914c62768581d07148 421.2MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:626138ddd8a2d28e3ab511730cfd6937406470b96f1b5825ace55ac2dfb49b01 13.57MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:a741a1c21aeb6b19d73364947077ad95b9f03bd6a9b62e606b5efc22c87404df 30.53MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:7492892b5e7853eb6234a57f4ab3b2a00208ac0b5318c6925a77b08024151b52 6.042MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:101e49f360bb05fbf3951e7d748dbf63faa50a07aed7c92115b194974f3437a3 5.034MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:eac1b95df832dc9f172fd1f07e7cb50c1929b118a4249ddd02c6318a677b506a 79.44MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:f0aa6c37b45ae68681e019b571b957fc5e9c9ebbd66c4299458bde9ae12aceb4 18.63MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:9d0c1d71973a179f98db25d0f5dbfe43ca6f5f3e4a1c25e403203a3370497bd1 130MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:84bc3dab2efafa1f2bd8157a15ef9dd4a23557fdd7358151a50ac7dbf51209d3 3.44MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:b43c2735ff2f94df00a1504731f3eda0e330d1ac65fd3d6ba6701bdac95e6c10 19.89MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:b5781c57cffa8e6c5e3ae1618a498b23ae4e57bc0862abe0d46ac0c27a69b370 20.76MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:fb44c74f36a9cb2285bbc4ed2d28832b97cd31a003caa655b660b1cfa267e40f 22.67MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:4620514455f3b1051f0f4460ed9dba2cc6e72edde663c96648facf59f3f03a76 435.8MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:72c8c2eb9a1af31b42cbb99cac5af66fe34ed1bc615f604548c53ca9008347b0 131.9MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:2dfee98672778d02d57f49b329aae6a7eff485a62112646c1e53937e7d07e425 18.02MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:6b0b505bf4d22df29cef3cedfdb8bb1947608c70dfde4352e3105c13b7325b6b 60.97MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:8e1f8299ae48cdb1a6ab42dfb48d2e5f5769b91dff9fbde4d87a7b4802acc234 5.335MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:a9431271827ba69daa92d11245bb50e7e05c041b89b4090b862860283f57574a 186.4MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:68864141dcd073e3e4379bcaf7bacb1b19fa0c293da25f8835dda9c1660fa8fb 37.69MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:95bb11286ffa4629626361161846b587eaebf7e6fc5be9b59120388d459a1aea 433.3MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:72885a81707deb1d8543ce2134d13691341a7c4fe7a9b3a48f94ad4c9fd1642f 29.78MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:e22321c63f0f6ec35f29133f0f59f9f1ef96675cd9bce699e08dea53e7464613 18.1MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:44c835b889889938274a454feb4e98b2cc6d533690095b604a28a0cd9360dce5 27.21MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:42cd9d27ea411d91c1c2e1b2ebd02531172046e602ec238fe2f5e7d3b2ea5819 29.56MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:833937e86288cf0810fe2f3f3f091e8f21a23db7572794a8a78f5f1ebec9003c 94.31MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:e3b537021da4df14a5624bdfcd493cfe8c99da1aa4d5cd4591ad0ed2b477b0ec 30.19MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:de2a09a071f980349b3761090b374c0d31a44c49673bd976db9830dc38b6840d 31.33MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:8272348703e5a7d43b0cc8a548ed1cd1e1dcbecf472c2c52764404c02050d130 29.36MiB




   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:ddef0b8dafbbdd741e049e7b68cc43e2f34cf823d865315ad83869948896afb9 14.61MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:7b4b6cb225abe0a6d65a4d68f0ccf0f613f259368f4857f2285e0d97a50b1388 62.35MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:7804f363532eba76317364c7c548ddaef6a3f93ebb5edd1e4483e646f7e28f7d 45.86MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:b61c3074dd7067516154ad2141f3995340bd19122be5a32dc41e3cc06d9ee7c1 19.99MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:c980ac22ce4874cda4dbb6e07ffd5f5174e76f26141e053492ec186d4f7a39ac 25.04MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:934b5acae9ef7926edb61751407e0adb478746c714d98ef7b96957850cdd4eb4 29.63MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:157537e57374f03ddd085c000ddbfd311133c1577d2af661bc9cef58eebd9ee8 25.2MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:5333f505fbcd4c446f9067a09d98652f6b7441f4918b678cb6700ef1f375c628 24.93MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:ce1cacfe1d27de0711e4d3ea12ae84541160e2beceb2ad7d965e21642ef277aa 30.21MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:eeca239718c8acf5c0f075f72f3942f6d83cd9f391f2816cdd3ead992b4d4c77 20.09MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:c71b5003366876faa2cb02eb097f5a5fbf138544e5ea375c1e35bbf77e2a81a7 91.14MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:372b2bb393e07c59050476939a5a21876707c4e0ea130a60eae75a4d7f564841 31.12MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:c8177f2abd74bfa004be57007b83db653b91bce59d9087c7d78bf3a5cae206ec 108.1MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:0bc56e8679aa66db98d6434e315fa2d0ef36993b4b5a0a131aa9640bce25df74 21.59MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:7e99997cc9b770ec909a5c8098a8fab839337b43013c075505c93b3c3c21a6b3 98.65MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:56764cdf702c98b30386be602cea63931b75f54d57cfd4a307db510a7c07a2bf 16.12MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:19ff28ff547bb885e50a88bb29be78e8b1e7bdf268b025e7052cf2fc5ce02e47 38.72MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:450c1856cde291bbe8de8e7eff490e70c10d4bc6f3f51c1f4f6170bd529ca925 6.133MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:01bb209932cb471d1ef1e24722ddcd75ac82426fe74da41338ef3f36893e4d98 86.26MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:983aa85fb9628adb1adc62f8e3869c6f9df87e0874ea92199fedfc6514647e3c 43.34MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:005e519404108145e27c6b62a0317b423b3ed312500f4f799cbdece832d8a9d6 25.29MiB
   uploading: lab-installer.karmalabs.corp:5000/ocp4 sha256:3fb8184e9de5f386c7421a08dbddd2217af4496f6f13ec448bbaeb0d87edbfcd 537.8KiB
   sha256:32a461d8ea341926133857f586dd602f7fe85c608ad93e46d07be7298fb5a6cb lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-coredns
   sha256:905ad7df7e6900619c73f144ccbc1b5e60a8b0dcec73c099470ef43a7ee1bbe8 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-autoscaler
   sha256:881c259179500e163e0f8f4e6f2b425408daacc26c2cde4a7095e90776d8060b lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-tests
   sha256:52042dbf174836944f9a03271499504f3a0d7a745a56693db0a386eea02afbc9 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-multus-networkpolicy
   sha256:b7deb0532f3c38759685e5bbece97417e99d9bc26b4b2a8414cb4963ec38ff3b lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-kuryr-controller
   sha256:38c835034f6c3f509771217a6236379b90897d8e041a4bfe780b7c23630b021a lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-grafana
   sha256:1f583ea8fb1035753979e3adaec1f7668e920e8d8a94cddf0646b723b16b6d9e lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-network-metrics-daemon
   sha256:bd6ad5c429fb7e31e6045e7927f76210c22e7573f387bc61168520ff4453e2c0 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-configmap-reloader
   sha256:bf8ab195054fa186a310f5534806e47178c3354daada970f3545e7d0a7dcbb07 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-kube-proxy
   sha256:701ffd1c51a84b9b712fed1a2681bb917b28b2170939252871701c0ab3b5b1fc lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-openstack-cinder-csi-driver-operator
   sha256:df0c66fa32624c2f286629fe88be9e602f756698317e73c258eb4dd7319d5e3a lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-storage-operator
   sha256:fbae5e73411bed5c2eed978369f7b53c4848e07218b7dfc0ab63c2f115c890f4 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-machine-config-operator
   sha256:3de4983cddbf5a2c92f71ceaf087434c50e8d5e193ffb9cf6f21c69d662d3933 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-kube-apiserver-operator
   sha256:238194aeaf2f240e800e99195103a75b3c27ad57cb3b31ceb34b187850d78946 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-multus-cni
   sha256:c0e1e8b8bf3b6cbbed2fb00aa21dbd3235ee20f66fa0d82860dd216098fbf2cd lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-openstack-cloud-controller-manager
   sha256:868279f5315c4582c971a7b2d20b951773544ea280a161ae389eb5b0fd715424 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-machine-approver
   sha256:bfa5e4216d205199490cd7358da492e060be4fe6c654a8713a41218d4047ce46 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-azure-machine-controllers
   sha256:033ddc1e24008c6183722e6a0583ac050f0fa157485508e165874d43f2bae6ab lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-openshift-state-metrics
   sha256:823f071c623306435b53fe42db79a663a62c435b7284be0fe2befa2553af3752 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-kube-state-metrics
   sha256:f72aa34decd784392a5784e93ffd8616445c3f749d932e4f9502f29523493e4e lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-csi-external-resizer
   sha256:7680102adb86388a3ae7399d25e14fbfd0f8bbf3c6377653f88b7104ef0509db lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-telemeter
   sha256:38c1ef9d44f4a90bf83f3dc75f2aacc6478356c7fa2708c881e914af4df5c8e8 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-hyperkube
   sha256:9665c5b4996ad961fffd2672f7bf61654b9700e3ab9cc954e6892c8f8d2f635d lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-ironic-hardware-inventory-recorder
   sha256:738b21ab3a9af2f3dbc2e0be5a598d9b10f27afcb6c3504c4a9b0c62f02724a6 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-console-operator
   sha256:a9532f0636367a6776915e79332e6acfbc1cf6875f9477236e651f20435c70c3 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-prometheus-config-reloader
   sha256:306883a3908244448769eacd7dbfcf209ec56dd03021823a2941799be1be676b lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-prometheus-node-exporter
   sha256:be638091383eadef518fcdad50493bfde851f8010d6d2c57e0f9cecc0f70f48e lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-keepalived-ipfailover
   sha256:2ceee2ebe189d8c18a1899f9f2cb0af0dca58d14c415777f26caa689d1339b1f lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-network-tools
   sha256:ac2ad5b01eed7b0222dabbfb5c6d4b19ddc85bdaab66738f7ff620e4acffb6ac lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-machine-os-content
   sha256:4491e2aa17088ba7461019aacedd713cbc70becfa60962123b65290308f449e9 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-azure-cloud-controller-manager
   sha256:7ca795f6897e5057ca7c1c2bfb2e80fba1ba479be72ade1d81c7fbadfe9eb10f lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-multus-route-override-cni
   sha256:da3185ad005ba094e86c4d7484c591ed6e81bfae7a8760bd33e0772bcfda53db lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-monitoring-operator
   sha256:a68a352a5e835daa99352c73bf13032436a148b02af8cee4d555bba969cca24b lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-machine-api-operator
   sha256:4d76d15cd9636109bc60931e4b85143852d2dd8d24d42e66785256ff4dfbc3f5 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-operator-lifecycle-manager
   sha256:cf349629029e936efe55b99176fc7b30834b49778330b67b7de89205bb98dfe7 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-csi-snapshot-controller
   sha256:9065acf7561d962955488b476b3f24af3b8b72b2fde1690cb35d3245c53c6390 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-vsphere-csi-driver-syncer
   sha256:b7aa0776dad20a024ed5df80ae8590ad973376aca1af4cb7dfb60a7af9e69415 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-csi-driver-manila
   sha256:1410141d4cbedd0d98af5376d0f0ce7764f1a84f0657034b5f958a94c345fe8d lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-deployer
   sha256:49dfda0a23064a8b82acc977b4e5554108a7c55b1e0259bf23f82f579267d1ce lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-csi-external-snapshotter
   sha256:04c9df04f725722cc4ff6799ca928c86c91f1bb0ec342d6251fc58940466c88b lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-operator-marketplace
   sha256:b47101401214acae9f8b92ef4b6ee38564206a9cd5215a087a12ce63c7f485d3 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-policy-controller
   sha256:2451bc005859a0987ef74382c4b839e900d7e903c77663840ff0ed0207a47635 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-csi-snapshot-validation-webhook
   sha256:27fb78cf79e0ece439b68c361591e94d425c4c5ae2737f868aec095f14ab2786 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-container-networking-plugins
   sha256:5c55be02e32e688ec5a404858a08cf533ba15b50b6f0e028089635b47db5866e lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64
   sha256:5b82201b95d2d6ad49a0acf957bd96cc266b06c5066dc4ac07f7ed90edf507c7 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-aws-ebs-csi-driver
   sha256:717fcc233a77be33872984fbe37ccaff2ecce0da5de11df59b1a3bed55d71fb1 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-openshift-controller-manager-operator
   sha256:c84ffc50d0ca44b7aef6e4d9b8c791affc5404a047ce7e9b73208b5c96ae0e21 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-gcp-pd-csi-driver-operator
   sha256:aaea2c8986613d921d83db5cc346f3ec7ecc6335b5fa09d74907a9cec4aa8fdb lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-kuryr-cni
   sha256:0af4ea37b14033cf6bfbce81a20dbb60ee04dc7e28f9aa890e151834e8400a88 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-openshift-apiserver
   sha256:3b965dbf1f0f5b173ef961d71a04d36c41831b8086ee8b33607ebfe1cc7ac158 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-ingress-operator
   sha256:16033ec3aed9bbf059909a0afb3d5a98a09129c8d51c1ad6cf75566a3808f54a lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-version-operator
   sha256:65369b6ccff0f3dcdaa8685ce4d765b8eba0438a506dad5d4221770a6ac1960a lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-driver-toolkit
   sha256:17bfe558a9b7201bd2e58bfc4fc73230a530ffc423fe082f9b7fdc870dd01271 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-jenkins-agent-base
   sha256:5c6e763d01ed9eecbfb02dbe47b0b66abd9943126f3fb3cc6de9041007af8a36 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cli-artifacts
   sha256:99754e32729f454eb82af5e3a29c35ec41f17418a6c83a0bacbc666f00c52695 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-ironic
   sha256:b426482b2bb57fb6a93611fa7e6a77200d8312458c2383a37ae743732114a322 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-ovirt-machine-controllers
   sha256:5e620f670b78ae31e9f01b5439cd9223c65d5a722c2742f0f73dcbe8c31237b8 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-baremetal-operator
   sha256:13201e0adde9ac709d5588b9e59de0dbc313dd1c095ffd4bf535369ccf4e934c lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-ironic-static-ip-manager
   sha256:eaf8eb2df8bf32e3d44f86e8eff0437937ba1b3ac9dad72e53dba5a447b3d886 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-network-operator
   sha256:6949da0886e5c938aa308dc49bf45431538e554d958a730c8ee2555cfb5d4b37 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cli
   sha256:2f51eba9bed3db47a06578298b8e06db68e0f88c6be66d7120829495ea4458a1 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-service-ca-operator
   sha256:6dbd05798bfcb09c072e9ab974133cb5d415f13d1dc3831fca4a33c529a6fa3a lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-docker-builder
   sha256:308b56720ca4bc317b4edacc6c5f266c9ce86f7ec6fde15aca24776a47127c31 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-docker-registry
   sha256:45c72c864086f0cfa47c69b57a3d8dd753be4069ea3f0f6850e1c89c5ab2501f lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-ironic-machine-os-downloader
   sha256:821f460b926444b9edd0bc04289050009e9ea3d5ca0d722451b76467a166f0c6 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-bootstrap
   sha256:718902f807c8269d5ada075dc258df209b0cc309eb58600aa55a63234f787273 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-installer
   sha256:650d86ec3b60e373e0db0214e4fc3dd424d67f589d6dab8de9c250e54ae62af4 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-multus-whereabouts-ipam-cni
   sha256:3ba48e83d25460644a26005374596dff2b39bebc305d1e2d6d07c3eb55bbbbf2 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-csi-driver-nfs
   sha256:852fced3a8cdfe1ac8edc4a8c1f022e33ced4c080e09c2ea4a9fe7dc92d4ec0f lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-oauth-server
   sha256:0ccaeb1a468008b32fc9cce0ac5c486648f8622dfacce5814c4dac82feee5daa lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-multus-admission-controller
   sha256:2ad7eab3629a7475f9f809a9df22ad0eea5f172a5c151c8143f1f18ac73ade37 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-vsphere-csi-driver-operator
   sha256:fc81c6614a38195a7c0f9465135a1064e6cbca09bce42653cb0f5b8d0513965b lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-kube-rbac-proxy
   sha256:ba56e5195741e54e654face4997c5c40be083f5302e5903983415e86a17a0e86 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-ironic-inspector
   sha256:03b88f06eb9727fdcc3e393bed85203ab3ba9d585ba2b9f69fbddc2f4d872c47 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-ovirt-csi-driver
   sha256:67efca98ca6f362bf75eb12e8722245bb1264d64d94cbcfb0f66365b84cbec4d lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-must-gather
   sha256:199b3a8fe3a5a64583afd1263d753de504dc9c60d31df443bd764fb2f39bdb43 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-oauth-apiserver
   sha256:91d524f71d0e7acb7c89eea38eafda21af342d668c26ed538bb1d4697137ec17 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-oauth-proxy
   sha256:800172d60861c4d7018e23cbac3c802c59fccda92848818b072f929a343b2889 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-gcp-pd-csi-driver
   sha256:74f37c929e78bb96bc07a0870fdbd52741e82b429a0794440651c408f5160795 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-baremetal-installer
   sha256:130c0f1053706666907afb64900df1dd627893d8979cdb56d7ed9da2f01f9db1 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-dns-operator
   sha256:2d4d74c0bf35a4d08c619d9f58b21cc1a888338702ccee982cf89b0479f78893 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-node-tuning-operator
   sha256:12fca9bd40b0ffe218ba7e469b321b46c14ef6e90afb4a82101139a7e91d7d7c lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-aws-machine-controllers
   sha256:de21b72c912e534a2e1713c870963ade63710bb684ec5a9e3c994b421adf7926 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-prometheus-alertmanager
   sha256:ea30e26dfd31644c94ea2e470211116f1b85dd8f5e828365be577d439db0dd43 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-jenkins-agent-nodejs
   sha256:e9c11afc09113059eb64208da91e1f81bde9acda6e2ee11425c440622be21663 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-openshift-apiserver-operator
   sha256:01ecfa030ee5975d85afa62ca4df4560748ffb263c1aa52494929951c02a4f11 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-etcd-operator
   sha256:d89c6d40803507c97d2e82995d712c70040edca64fe627c47bab03d28d1e3068 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-k8s-prometheus-adapter
   sha256:87f042dca494bf46dd5604e84c1a5b965fd53375093fe7006dee004bcab188d3 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-azure-cloud-node-manager
   sha256:aca06b6adba4da8e4087cbbc1cf585e37b237bce377bc4918fa9991c7e79942f lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-prometheus
   sha256:708cc4c2a19a52fdabb4f2f5ddf575c1c896c981ee15b678b93b5cd1072937c7 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-vsphere-csi-driver
   sha256:1a56399b5c2fe169156cd5e410abb021e3714d1ee08db6927932a989273e053e lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-kube-controller-manager-operator
   sha256:c45687f4b08bb8d1e69342fa29da14298f58c755054954777261eb9f3976243c lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-openstack-machine-controllers
   sha256:5b0db3d158efadae362e068a796920a2c9184b2a3ae2188063904a90547394c1 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-baremetal-machine-controllers
   sha256:80ac8e87d79736479565f9e780fe18ee0d6b9c95d1029b6e3b488326dad4ea80 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-kube-storage-version-migrator
   sha256:8277f5f94b0e4db67f490d8e01cb524c3890c404738db0118f647936d75f5abb lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-pod
   sha256:e6f50c7ffabcc0b6ccae73c3a3dc5ad20a94137f9d8c98473eaaf437b8c2da93 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-kube-scheduler-operator
   sha256:53eaae5fadd9f9585797a0978a1a39ef46a064d2f46810aa59e5f4a8577d2444 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-cloud-controller-manager-operator
   sha256:55672d1859385409273a984375b226bb29b49c3130237be3bd5241684c01aa9e lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-ironic-ipa-downloader
   sha256:da71bad01f548cbc81e271eff00c810a19f3bfbf717f221124a846c89f0d9ed1 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-prometheus-operator
   sha256:63eb87db627320e0134b538daf63566d3d19749491ed4a266a4088aa03e8fdb9 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-autoscaler-operator
   sha256:58cf3f6650938559b316a8487562c32086bab77adec7cf1fce8022825882c687 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-insights-operator
   sha256:b84ba4ecf6d5682d66d198aface7884ce5adf51f341f1ea47b741e6018854dca lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-libvirt-machine-controllers
   sha256:6f076502c8ddf922eb238a941f76fdadf8ddbb83a3e6d07f99def1a4bfde1d77 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-openshift-controller-manager
   sha256:5b12e15bdb08e5b6d47f3ffc5ef59321eee3f994779235bc19a78080b3cc63b0 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-aws-pod-identity-webhook
   sha256:628d2d1e8898aab03e0a0248dc53cd1bba8ce76a2b23201ea6ee0a9e4343db01 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-csi-external-attacher
   sha256:825ef5eb718e3757ef1a4df1b40917ec50a3f78d79b34273ad460515ffdc020d lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-console
   sha256:3b2d37c7858d2cd9366be804b63173467cc34815aa2d5e389158972006857f30 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-vsphere-problem-detector
   sha256:92e975189cb58919e8a2811edd414f5be5b759dcd61762a6e9ab1bee50200cbb lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-etcd
   sha256:1a530a0d0dbbec578ea6b0cbd901d78f4a395a9896fae1df05c3c940337ccb3e lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-sdn
   sha256:365a6e46b15a074f268417c1472c6d79ff85d6062b6af59628d094cf53b4e7aa lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-jenkins
   sha256:d2ae96692553d6c08218aaa883c147172039bbfae2dc719579f193e116a19e18 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-samples-operator
   sha256:3d3323102b9c0076c08018789b4865058d280842e97a36fae1afea13b00a6cee lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-authentication-operator
   sha256:a2d509765b7f3a23cf3d780878bc8f1fb0e908b5c2c98aea55964d4ee9f44791 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-aws-ebs-csi-driver-operator
   sha256:c98a79fd2cd933603ec567aabce007d1ccee24cc8e5bf12f8ead9507c5cd67e3 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-ovn-kubernetes
   sha256:b42499bdb227da2d2d4f81def7271598e3d3a4386e71f95c6c1c06210cba4bcf lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-aws-cloud-controller-manager
   sha256:2ce9667775acdefcff0a90199c2b87b001b98d7ea5b5e7ed18453ba47b318235 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-baremetal-runtimecfg
   sha256:5efb96bd375d8248bd891743b46385329f1b211c0bd4b0dde58bea2a63b99486 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-haproxy-router
   sha256:dd7bee3938a03ca4adf7e463bae2edb257ac2788aa7d81881b257cde9bb977dd lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-gcp-machine-controllers
   sha256:54a933585eea48ba4ebd8ce3fa61687d05d0dd38ce4b03cde8d4006e081d22a9 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-kube-storage-version-migrator-operator
   sha256:2dec93a89cbefc7c50d867fe420647f27c602d2643419bf41015bb51177d19cb lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-egress-router-cni
   sha256:053ce06d7890d34a628c71db07f06e3a4de6e652dad444a63727e4d0fce1441e lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-openstack-cinder-csi-driver
   sha256:daee78847a7b8a9f000129270decd4751e0cd2694bcab6e81cf1b98b0b592d2b lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-csi-node-driver-registrar
   sha256:e182d8ac108fe6943f3d1187f8b8825de3b87ce19084514e841d7e351bec93ee lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-installer-artifacts
   sha256:b8be5c3293d4f4096132a4a436a6d6cf14c91711a3566aea2fe4728436f997a5 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-image-registry-operator
   sha256:17e245626b90fd1e73936c3840d3f27dabb7100cdd07d8945c5c3d408dc55dc3 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cloud-credential-operator
   sha256:d70923a803680c2221ca58c35fc296bb01797c7a4c2c8feeffe8e55f350a7139 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-prom-label-proxy
   sha256:3fa748cf130e1d5100b029a6c6e357b143242e246b7114fd5f288a08e009797e lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-update-keys
   sha256:ab9d9256d43783a061c613d78abd8eabb2323798098fb5dbe63c4ca13318b0c4 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-mdns-publisher
   sha256:8de8d8a3289b2e477d279bc1f3ea03fe7785c219a426814e9ae14b891f635855 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-thanos
   sha256:a3e1acdad51d67db44badac6ab046e1aa2b2a40bb530a2c7ac184d86195817ab lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-baremetal-operator
   sha256:8b1af36bf0985b6a2bb486b02553a89091ad71a067959d9840391ae5f9e8ceda lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-jenkins-agent-maven
   sha256:53de0ae3fb21fa7e617a20862b7824707d201306ca639132a9a94cc234435ed1 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-azure-disk-csi-driver-operator
   sha256:14af1530eb9ec2f1caf13990b4356c0f1b35fa2ff2519b0e08a9752190e8c773 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-csi-external-provisioner
   sha256:3d0b4e7c95824f18fd9d6cc00fe12e13516a170d55f9c4d0ebd51f5074ccb688 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-operator-registry
   sha256:c8d625f6d7fe4bddfd9e7ff1801bd0d608153057b2eaac61790bd78a939ba53e lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-csi-snapshot-controller-operator
   sha256:bb6c09cf7cc43e3a7ab8a0ee068db87552e203d351321fcaa3a1840d59c444ed lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-cluster-config-operator
   sha256:84be0fe13eb20a33ef01d0c31809b84a97fa754d5d17791e43b4f477608ffe76 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-ovirt-csi-driver-operator
   sha256:c66f7404d5cc5d3203c941290b4fc5433154dfca4f9900fda27eb40ff1b460cf lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-csi-driver-manila-operator
   sha256:f4ddae7f0218896f038c812e5becef748648a552080474fedf89cbbc677b939c lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-csi-livenessprobe
   sha256:a6f6387a01f0275c777b4dee489967227a84d1cbea504d972a394c4ea48437df lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-tools
   sha256:b20b1ce89582ee300a88e3de5226c09b31ae2b6e05de74b5e1c89b2bb56800c7 lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64-azure-disk-csi-driver
   info: Mirroring completed in 6m50.67s (24.68MB/s)

   Success
   Update image:  lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64
   Mirror prefix: lab-installer.karmalabs.corp:5000/ocp4
   Mirror prefix: lab-installer.karmalabs.corp:5000/ocp4:4.9.7-x86_64

   To use the new mirrored repository to install, add the following section to the install-config.yaml:

   imageContentSources:
   - mirrors:
     - lab-installer.karmalabs.corp:5000/ocp4
     source: quay.io/openshift-release-dev/ocp-release
   - mirrors:
     - lab-installer.karmalabs.corp:5000/ocp4
     source: quay.io/openshift-release-dev/ocp-v4.0-art-dev


   To use the new mirrored repository for upgrades, use the following to create an ImageContentSourcePolicy:

   apiVersion: operator.openshift.io/v1alpha1
   kind: ImageContentSourcePolicy
   metadata:
     name: example
   spec:
     repositoryDigestMirrors:
     - mirrors:
       - lab-installer.karmalabs.corp:5000/ocp4
       source: quay.io/openshift-release-dev/ocp-release
     - mirrors:
       - lab-installer.karmalabs.corp:5000/ocp4
       source: quay.io/openshift-release-dev/ocp-v4.0-art-dev

   real    7m25.757s
   user    1m26.168s
   sys 0m37.834s

Those two scripts do the following:

-  Install podman and openssl.

-  Creates SSL certificates.

-  Creates a htpasswd file.

-  Creates and launches a registry using tls and said htpasswd for authentication.

-  Sets this registry as a systemd service.

-  Leverages ``oc adm release mirror`` to fetch Openshift content and push it to our local registry.

-  Patches the *install-config.yaml* so that it makes use of our internal registry during deployment. In particular, imagecontentsources and ca as additionalTrustBundle are added to the file.

Disconnected olm operators (Optional)
=====================================

In this section, we sync some olm operator. Open the file 06_disconnected_olm.sh and change line 40 to sync the operators you want. The previous lune shows you how to sync common operators such as local-storage-operator or performance-addon-operator.

::

   /root/04_disconnected_olm.sh

Expected Output

::

   Login Succeeded!
   Login Succeeded!
   WARN[0000] DEPRECATION NOTICE:
   Sqlite-based catalogs and their related subcommands are deprecated. Support for
   them will be removed in a future release. Please migrate your catalog workflows
   to the new file-based catalog format.
   INFO[0000] pruning the index                             packages="[local-storage-operator performance-addon-operator]"
   INFO[0000] Pulling previous image registry.redhat.io/redhat/redhat-operator-index:v4.9 to get metadata  packages="[local-storage-operator performance-addon-operator]"
   INFO[0000] running /bin/podman pull registry.redhat.io/redhat/redhat-operator-index:v4.9  packages="[local-storage-operator performance-addon-operator]"
   INFO[0019] running /bin/podman pull registry.redhat.io/redhat/redhat-operator-index:v4.9  packages="[local-storage-operator performance-addon-operator]"
   INFO[0021] Getting label data from previous image        packages="[local-storage-operator performance-addon-operator]"
   INFO[0021] running podman inspect                        packages="[local-storage-operator performance-addon-operator]"
   INFO[0021] running podman create                         packages="[local-storage-operator performance-addon-operator]"
   INFO[0022] running podman cp                             packages="[local-storage-operator performance-addon-operator]"
   INFO[0035] running podman rm                             packages="[local-storage-operator performance-addon-operator]"
   INFO[0036] deleting packages                             pkg=3scale-operator
   INFO[0036] packages: [3scale-operator]                   pkg=3scale-operator
   INFO[0036] deleting packages                             pkg=advanced-cluster-management
   INFO[0036] packages: [advanced-cluster-management]       pkg=advanced-cluster-management
   INFO[0036] deleting packages                             pkg=amq-broker-rhel8
   INFO[0036] packages: [amq-broker-rhel8]                  pkg=amq-broker-rhel8
   INFO[0036] deleting packages                             pkg=amq-online
   INFO[0036] packages: [amq-online]                        pkg=amq-online
   INFO[0036] deleting packages                             pkg=amq-streams
   INFO[0036] packages: [amq-streams]                       pkg=amq-streams
   INFO[0037] deleting packages                             pkg=amq7-interconnect-operator
   INFO[0037] packages: [amq7-interconnect-operator]        pkg=amq7-interconnect-operator
   INFO[0037] deleting packages                             pkg=ansible-automation-platform-operator
   INFO[0037] packages: [ansible-automation-platform-operator]  pkg=ansible-automation-platform-operator
   INFO[0037] deleting packages                             pkg=apicast-operator
   INFO[0037] packages: [apicast-operator]                  pkg=apicast-operator
   INFO[0037] deleting packages                             pkg=aws-efs-csi-driver-operator
   INFO[0037] packages: [aws-efs-csi-driver-operator]       pkg=aws-efs-csi-driver-operator
   INFO[0037] deleting packages                             pkg=businessautomation-operator
   INFO[0037] packages: [businessautomation-operator]       pkg=businessautomation-operator
   INFO[0037] deleting packages                             pkg=cincinnati-operator
   INFO[0037] packages: [cincinnati-operator]               pkg=cincinnati-operator
   INFO[0037] deleting packages                             pkg=cluster-kube-descheduler-operator
   INFO[0037] packages: [cluster-kube-descheduler-operator]  pkg=cluster-kube-descheduler-operator
   INFO[0037] deleting packages                             pkg=cluster-logging
   INFO[0037] packages: [cluster-logging]                   pkg=cluster-logging
   INFO[0037] deleting packages                             pkg=clusterresourceoverride
   INFO[0037] packages: [clusterresourceoverride]           pkg=clusterresourceoverride
   INFO[0037] deleting packages                             pkg=codeready-workspaces
   INFO[0037] packages: [codeready-workspaces]              pkg=codeready-workspaces
   INFO[0037] deleting packages                             pkg=codeready-workspaces2
   INFO[0037] packages: [codeready-workspaces2]             pkg=codeready-workspaces2
   INFO[0037] deleting packages                             pkg=compliance-operator
   INFO[0037] packages: [compliance-operator]               pkg=compliance-operator
   INFO[0037] deleting packages                             pkg=container-security-operator
   INFO[0037] packages: [container-security-operator]       pkg=container-security-operator
   INFO[0037] deleting packages                             pkg=costmanagement-metrics-operator
   INFO[0037] packages: [costmanagement-metrics-operator]   pkg=costmanagement-metrics-operator
   INFO[0037] deleting packages                             pkg=cryostat-operator
   INFO[0037] packages: [cryostat-operator]                 pkg=cryostat-operator
   INFO[0037] deleting packages                             pkg=datagrid
   INFO[0037] packages: [datagrid]                          pkg=datagrid
   INFO[0037] deleting packages                             pkg=devworkspace-operator
   INFO[0037] packages: [devworkspace-operator]             pkg=devworkspace-operator
   INFO[0037] deleting packages                             pkg=eap
   INFO[0037] packages: [eap]                               pkg=eap
   INFO[0037] deleting packages                             pkg=elasticsearch-operator
   INFO[0037] packages: [elasticsearch-operator]            pkg=elasticsearch-operator
   INFO[0037] deleting packages                             pkg=file-integrity-operator
   INFO[0037] packages: [file-integrity-operator]           pkg=file-integrity-operator
   INFO[0037] deleting packages                             pkg=fuse-apicurito
   INFO[0037] packages: [fuse-apicurito]                    pkg=fuse-apicurito
   INFO[0037] deleting packages                             pkg=fuse-console
   INFO[0037] packages: [fuse-console]                      pkg=fuse-console
   INFO[0037] deleting packages                             pkg=fuse-online
   INFO[0037] packages: [fuse-online]                       pkg=fuse-online
   INFO[0037] deleting packages                             pkg=gatekeeper-operator-product
   INFO[0037] packages: [gatekeeper-operator-product]       pkg=gatekeeper-operator-product
   INFO[0037] deleting packages                             pkg=integration-operator
   INFO[0037] packages: [integration-operator]              pkg=integration-operator
   INFO[0037] deleting packages                             pkg=jaeger-product
   INFO[0037] packages: [jaeger-product]                    pkg=jaeger-product
   INFO[0037] deleting packages                             pkg=jws-operator
   INFO[0037] packages: [jws-operator]                      pkg=jws-operator
   INFO[0037] deleting packages                             pkg=kiali-ossm
   INFO[0037] packages: [kiali-ossm]                        pkg=kiali-ossm
   INFO[0037] deleting packages                             pkg=klusterlet-product
   INFO[0037] packages: [klusterlet-product]                pkg=klusterlet-product
   INFO[0037] deleting packages                             pkg=kubernetes-nmstate-operator
   INFO[0037] packages: [kubernetes-nmstate-operator]       pkg=kubernetes-nmstate-operator
   INFO[0037] deleting packages                             pkg=kubevirt-hyperconverged
   INFO[0037] packages: [kubevirt-hyperconverged]           pkg=kubevirt-hyperconverged
   INFO[0037] deleting packages                             pkg=metallb-operator
   INFO[0037] packages: [metallb-operator]                  pkg=metallb-operator
   INFO[0037] deleting packages                             pkg=mtc-operator
   INFO[0037] packages: [mtc-operator]                      pkg=mtc-operator
   INFO[0037] deleting packages                             pkg=mtv-operator
   INFO[0037] packages: [mtv-operator]                      pkg=mtv-operator
   INFO[0037] deleting packages                             pkg=multicluster-engine
   INFO[0037] packages: [multicluster-engine]               pkg=multicluster-engine
   INFO[0037] deleting packages                             pkg=nfd
   INFO[0037] packages: [nfd]                               pkg=nfd
   INFO[0037] deleting packages                             pkg=node-healthcheck-operator
   INFO[0037] packages: [node-healthcheck-operator]         pkg=node-healthcheck-operator
   INFO[0037] deleting packages                             pkg=ocs-operator
   INFO[0037] packages: [ocs-operator]                      pkg=ocs-operator
   INFO[0037] deleting packages                             pkg=openshift-gitops-operator
   INFO[0037] packages: [openshift-gitops-operator]         pkg=openshift-gitops-operator
   INFO[0037] deleting packages                             pkg=openshift-jenkins-operator
   INFO[0037] packages: [openshift-jenkins-operator]        pkg=openshift-jenkins-operator
   INFO[0037] deleting packages                             pkg=openshift-pipelines-operator-rh
   INFO[0037] packages: [openshift-pipelines-operator-rh]   pkg=openshift-pipelines-operator-rh
   INFO[0037] deleting packages                             pkg=openshift-special-resource-operator
   INFO[0037] packages: [openshift-special-resource-operator]  pkg=openshift-special-resource-operator
   INFO[0037] deleting packages                             pkg=opentelemetry-product
   INFO[0037] packages: [opentelemetry-product]             pkg=opentelemetry-product
   INFO[0038] deleting packages                             pkg=poison-pill-manager
   INFO[0038] packages: [poison-pill-manager]               pkg=poison-pill-manager
   INFO[0038] deleting packages                             pkg=ptp-operator
   INFO[0038] packages: [ptp-operator]                      pkg=ptp-operator
   INFO[0038] deleting packages                             pkg=quay-bridge-operator
   INFO[0038] packages: [quay-bridge-operator]              pkg=quay-bridge-operator
   INFO[0038] deleting packages                             pkg=quay-operator
   INFO[0038] packages: [quay-operator]                     pkg=quay-operator
   INFO[0038] deleting packages                             pkg=red-hat-camel-k
   INFO[0038] packages: [red-hat-camel-k]                   pkg=red-hat-camel-k
   INFO[0038] deleting packages                             pkg=rh-service-binding-operator
   INFO[0038] packages: [rh-service-binding-operator]       pkg=rh-service-binding-operator
   INFO[0038] deleting packages                             pkg=rhacs-operator
   INFO[0038] packages: [rhacs-operator]                    pkg=rhacs-operator
   INFO[0038] deleting packages                             pkg=rhpam-kogito-operator
   INFO[0038] packages: [rhpam-kogito-operator]             pkg=rhpam-kogito-operator
   INFO[0038] deleting packages                             pkg=rhsso-operator
   INFO[0038] packages: [rhsso-operator]                    pkg=rhsso-operator
   INFO[0038] deleting packages                             pkg=sandboxed-containers-operator
   INFO[0038] packages: [sandboxed-containers-operator]     pkg=sandboxed-containers-operator
   INFO[0038] deleting packages                             pkg=serverless-operator
   INFO[0038] packages: [serverless-operator]               pkg=serverless-operator
   INFO[0038] deleting packages                             pkg=service-registry-operator
   INFO[0038] packages: [service-registry-operator]         pkg=service-registry-operator
   INFO[0038] deleting packages                             pkg=servicemeshoperator
   INFO[0038] packages: [servicemeshoperator]               pkg=servicemeshoperator
   INFO[0038] deleting packages                             pkg=skupper-operator
   INFO[0038] packages: [skupper-operator]                  pkg=skupper-operator
   INFO[0038] deleting packages                             pkg=sriov-network-operator
   INFO[0038] packages: [sriov-network-operator]            pkg=sriov-network-operator
   INFO[0038] deleting packages                             pkg=submariner
   INFO[0038] packages: [submariner]                        pkg=submariner
   INFO[0038] deleting packages                             pkg=vertical-pod-autoscaler
   INFO[0038] packages: [vertical-pod-autoscaler]           pkg=vertical-pod-autoscaler
   INFO[0038] deleting packages                             pkg=web-terminal
   INFO[0038] packages: [web-terminal]                      pkg=web-terminal
   INFO[0038] deleting packages                             pkg=windows-machine-config-operator
   INFO[0038] packages: [windows-machine-config-operator]   pkg=windows-machine-config-operator
   INFO[0038] Generating dockerfile                         packages="[local-storage-operator performance-addon-operator]"
   INFO[0038] writing dockerfile: index.Dockerfile601712286  packages="[local-storage-operator performance-addon-operator]"
   INFO[0038] running podman build                          packages="[local-storage-operator performance-addon-operator]"
   INFO[0038] [podman build --format docker -f index.Dockerfile601712286 -t lab-installer.karmalabs.corp:5000/olm-index/redhat-operator-index:v4.9 .]  packages="[local-storage-operator performance-addon-operator]"

   real    0m46.603s
   user    0m43.984s
   sys 0m22.988s
   Getting image source signatures
   Copying blob ba3365d1784d done
   Copying blob 5d6a8d4078ce done
   Copying blob c62ac451311d done
   Copying blob dd4ed6fbb3ba done
   Copying blob c71a09fbf6a2 done
   Copying blob 6d75f23be3dd done
   Copying config 9807efd2fa done
   Writing manifest to image destination
   Storing signatures

   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   !! DEPRECATION NOTICE:
   !!   Sqlite-based catalogs are deprecated. Support for them will be removed in a
   !!   future release. Please migrate your catalog workflows to the new file-based
   !!   catalog format.
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   src image has index label for database path: /database/index.db
   using index path mapping: /database/index.db:/tmp/536383754
   wrote database to /tmp/536383754
   using database at: /tmp/536383754/index.db
   lab-installer.karmalabs.corp:5000/
     olm/olm-index-redhat-operator-index
       blobs:
         lab-installer.karmalabs.corp:5000/olm-index/redhat-operator-index sha256:b894df0e9cdcbfae84cdff712a1f411957cee45c9880da7fa86419df91909b3e 166B
         lab-installer.karmalabs.corp:5000/olm-index/redhat-operator-index sha256:9807efd2fade40f1aec0cb6afb3841caf95119ad874ad1c186cbc8995f1fb238 3.486KiB
         lab-installer.karmalabs.corp:5000/olm-index/redhat-operator-index sha256:99bbe933c0e4433c7fd6941c88af807907a5c024eeea9ba68168b0a02104f64f 20.93KiB
         lab-installer.karmalabs.corp:5000/olm-index/redhat-operator-index sha256:639208cddb94771f2d42cf8f53ec21e6ea7a1e17485806b8ffa3b6b7528cc11e 686.5KiB
         lab-installer.karmalabs.corp:5000/olm-index/redhat-operator-index sha256:c3528915f8acda6a378f500237b8d3ce80951ac0556f059b834891ca42ee629f 812KiB
         lab-installer.karmalabs.corp:5000/olm-index/redhat-operator-index sha256:0c3f40efe9c88feb29cd66831b5fb7bd1cd6816a65fe56911631f1050ab19444 3.747MiB
         lab-installer.karmalabs.corp:5000/olm-index/redhat-operator-index sha256:4ad6714115439f812b62c5d3ee9d1077534bd5fec4244f4cb421771c62d7e62e 13.57MiB
       manifests:
         sha256:c751ebab527f6572eaac9ea7681af629845c9852573ea2ed0f608b5fd4fa7cd0 -> v4.9
     olm/openshift4-ose-kube-rbac-proxy
       blobs:
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:47aa3ed2034c4f27622b989b26c06087de17067268a19a1b3642a7e2686cd1a3 1.747KiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:27cb39a08c6eb46426e92622c4edea9b9b8495b2401d02c773e239dd40d99a22 1.749KiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:a43c17e99eba2aa2dc91309d9a3ea5a4303192581c17d960742beba057310838 1.751KiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:e868028034be105ba8828c69f0f89f7b5517c673f58400fa143067e68524a384 1.752KiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:5904a74cf240cb014e4d552232bbb0b3e1841067c3a10c28d69e18bf77a8bcd4 5.719KiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:6bfca1871189d9c8ada17f7bd50aea7fac75f77bae3f6ad33703c899019f95b0 5.721KiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:6e1c2b0b6bd80617058dace0ae1ccbc25c83d2fbe55d673da8e0acb87310e7a1 5.724KiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:55cfe216987656584bb09709d8de7b6339758593edc4bbf0d336cde224a3841d 5.734KiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:c3d0b3cd21108afc0d4c92fa1d81c4a259b5d96a38097d753daef5182b8491f8 6.09MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:ac58ad8783963479746820574454cea7577bde4455e634d3375f37aba3633001 6.101MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:d210a32994f406eaf5bd279c63f4fb1dcba50b9c1be55ad57fe965e3ad761f72 6.108MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:2ba1023276a3f31f3f034f21224704e5f5b2618c0f751ffe6a6898a5e081fc0e 6.133MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:d0e70ac12890105f713e7bfa4041263bc3ac3fdaa29c684c11fd32ea345cf741 10.59MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:5c27806d08be52d124b7a641f9ae3dd9f56665d8f34886c69817d1bd58224548 10.68MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:8371edeb80944cd165f030b9809d8dcb6266a91345dd84adaa035a43d7d65a87 10.76MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:71b833585865125a4752cd0885165f3a15bd106b38fb29ba840bde57da4f9cc2 11.34MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:fe8ec63cfe4747253fe2543aec59571d0de704c0a43a1eb8f68dab635009f9dc 15.86MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:89b92dfc7f69c1d7f3b31b47890b98bd33b1ae61b67899b03576bd07a3d3c47f 16.28MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:4a7a6d81f648de56fd64b4b893b88c754dce1f27fcdbb64fd6a5f31ee147dcef 17.39MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:c4907b32df1f8f1ee8e0bbe312f999c5cc1422b44929ecf4c8fac386470699fd 17.44MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:3eabe22a2aec9181c0849b1a23a6104a81bcf00bea55a52a45dba613f0afd896 76.79MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:2d5d59c100e7ad4ac35a22da06b6df29070833b69ddff30f13cb9e11e69dce1e 78.57MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:eac1b95df832dc9f172fd1f07e7cb50c1929b118a4249ddd02c6318a677b506a 79.44MiB
         registry.redhat.io/openshift4/ose-kube-rbac-proxy sha256:ed6ee657d49e14dc574507ea575b857343d444d423231c7f827ae0d3105b7937 87.04MiB
       manifests:
         sha256:4fc86a4a96c593c8f234d4edf057c9e2215ff799a82464d81adcb6dd13ea455e
         sha256:8b4f814c112d7b91dc5e7904d4f3c684f3d77227344d2b553a84d4a1bc2829d3
         sha256:96ebd88d19be8a3b5679ad24041d456e01c0a1a9f0bf9a535725488083f4cd17
         sha256:b98bd93ac4f9efe1cbcac3936076568fae6cc6c19845fab12a1b80586b33296f
         sha256:ca006e25d09c1706a7faec17527ff4a14e64368d6541583b519dbaeb4a30d32f
         sha256:8b4f814c112d7b91dc5e7904d4f3c684f3d77227344d2b553a84d4a1bc2829d3 -> a8cc7e74
     olm/openshift4-ose-local-storage-diskmaker
       blobs:
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:47aa3ed2034c4f27622b989b26c06087de17067268a19a1b3642a7e2686cd1a3 1.747KiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:27cb39a08c6eb46426e92622c4edea9b9b8495b2401d02c773e239dd40d99a22 1.749KiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:a43c17e99eba2aa2dc91309d9a3ea5a4303192581c17d960742beba057310838 1.751KiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:e868028034be105ba8828c69f0f89f7b5517c673f58400fa143067e68524a384 1.752KiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:6e55b2e3076a07f23f0ad08af69be04efe22e56197dc10c9a9f03f9593b934f8 5.815KiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:4058de8da8fe8af15213b3893e15869e86f01581e5e3475f1339ee9c25b5e6eb 5.817KiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:594f4e0be2daf310ac7f43eb34b2879c94397d2e6e74a5db5179b010489c9e6c 5.82KiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:19d788ac28ff34667be086502279927b610d719b164638c4e29874e0c8e29b06 5.831KiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:c3d0b3cd21108afc0d4c92fa1d81c4a259b5d96a38097d753daef5182b8491f8 6.09MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:ac58ad8783963479746820574454cea7577bde4455e634d3375f37aba3633001 6.101MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:d210a32994f406eaf5bd279c63f4fb1dcba50b9c1be55ad57fe965e3ad761f72 6.108MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:2ba1023276a3f31f3f034f21224704e5f5b2618c0f751ffe6a6898a5e081fc0e 6.133MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:d0e70ac12890105f713e7bfa4041263bc3ac3fdaa29c684c11fd32ea345cf741 10.59MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:5c27806d08be52d124b7a641f9ae3dd9f56665d8f34886c69817d1bd58224548 10.68MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:8371edeb80944cd165f030b9809d8dcb6266a91345dd84adaa035a43d7d65a87 10.76MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:71b833585865125a4752cd0885165f3a15bd106b38fb29ba840bde57da4f9cc2 11.34MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:41b5c4fd705c125a86f32562747a39a914ce960ddb9de97d172870bb4b4a824d 27.44MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:2ae16a9e914000df3a69e9ba24215fb038400fa6d16798e9b6de3e12c69379e2 28.8MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:9253a6e9c3007be9aa6ced2f4b40977efd425bf0ff00f5b7c0a448cc3fe04730 29.98MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:4c4d6e754c8d38fa7deeeb98d90193876a5e6c285e2ab3eaefe9945235951869 30.18MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:3eabe22a2aec9181c0849b1a23a6104a81bcf00bea55a52a45dba613f0afd896 76.79MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:2d5d59c100e7ad4ac35a22da06b6df29070833b69ddff30f13cb9e11e69dce1e 78.57MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:eac1b95df832dc9f172fd1f07e7cb50c1929b118a4249ddd02c6318a677b506a 79.44MiB
         registry.redhat.io/openshift4/ose-local-storage-diskmaker sha256:ed6ee657d49e14dc574507ea575b857343d444d423231c7f827ae0d3105b7937 87.04MiB
       manifests:
         sha256:207dfff315700175332194156b3cce8e0c05ead5a08c95ed258d4ef773cb7385
         sha256:2574e73af12ea219293d247046d3015a19481905e8b859ad84961086f092f585
         sha256:57ed851ce2bfa1a60b65d1fc0fd8a120443d56c71959eae88b8e16b2e5a7028d
         sha256:6a5c51b61d31c4f771c1ce02e2f8614c3df24ea8e09fcb8d5ea9ea137e7ce0b6
         sha256:6a61dd35c5cf355d285d8d7341a6abd123c526ebc603a177a281acb9764356c7
         sha256:2574e73af12ea219293d247046d3015a19481905e8b859ad84961086f092f585 -> d32f4d30
     olm/openshift4-ose-local-storage-operator
       blobs:
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:47aa3ed2034c4f27622b989b26c06087de17067268a19a1b3642a7e2686cd1a3 1.747KiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:27cb39a08c6eb46426e92622c4edea9b9b8495b2401d02c773e239dd40d99a22 1.749KiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:a43c17e99eba2aa2dc91309d9a3ea5a4303192581c17d960742beba057310838 1.751KiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:e868028034be105ba8828c69f0f89f7b5517c673f58400fa143067e68524a384 1.752KiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:064792261eb9dab08daf67c125973c77b760a86ce3fe8452d713d9beb06e5695 5.869KiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:68af5901957b4eb502e16775006a766cd5e4f6e31fdf26645a05f914d0bdf610 5.871KiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:314341f8c1d5fedc45d99c859ee3c7250b5d7334798a2015f53c6d0ef969a4bd 5.874KiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:23892b4d78e7e87f93763697407c7e3ca7dc199fd7e1dc09ca93a597d1dc85d6 5.885KiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:c3d0b3cd21108afc0d4c92fa1d81c4a259b5d96a38097d753daef5182b8491f8 6.09MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:ac58ad8783963479746820574454cea7577bde4455e634d3375f37aba3633001 6.101MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:d210a32994f406eaf5bd279c63f4fb1dcba50b9c1be55ad57fe965e3ad761f72 6.108MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:2ba1023276a3f31f3f034f21224704e5f5b2618c0f751ffe6a6898a5e081fc0e 6.133MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:d0e70ac12890105f713e7bfa4041263bc3ac3fdaa29c684c11fd32ea345cf741 10.59MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:5c27806d08be52d124b7a641f9ae3dd9f56665d8f34886c69817d1bd58224548 10.68MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:8371edeb80944cd165f030b9809d8dcb6266a91345dd84adaa035a43d7d65a87 10.76MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:71b833585865125a4752cd0885165f3a15bd106b38fb29ba840bde57da4f9cc2 11.34MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:c5f97614663335c43d29bf34fcfee521acb7f7ec407cd225a22dff373ad62b23 18.29MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:5f66527c36bb05f734652a043a1f53f29e1189490e78310bce6a9293151df772 20.08MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:74a2cc6bd6c4ac46722886fc654fd4bf4aa2b0885bab3ee05764ea1e90bed9d9 21.44MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:daf0fc851c5133b93fd32086cedec51d7f7119b047cd57500f9b4987eac90886 21.54MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:3eabe22a2aec9181c0849b1a23a6104a81bcf00bea55a52a45dba613f0afd896 76.79MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:2d5d59c100e7ad4ac35a22da06b6df29070833b69ddff30f13cb9e11e69dce1e 78.57MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:eac1b95df832dc9f172fd1f07e7cb50c1929b118a4249ddd02c6318a677b506a 79.44MiB
         registry.redhat.io/openshift4/ose-local-storage-operator sha256:ed6ee657d49e14dc574507ea575b857343d444d423231c7f827ae0d3105b7937 87.04MiB
       manifests:
         sha256:20724e13517cbe1febbd40f66f87c174c2e2e1ae016f566fcd36d88da615fa38
         sha256:49aadd9aa543c13035b64ec0fde93247d7625f13efc3c7b97c768be227b45fac
         sha256:a9d05d9f01a6405d3c1847198b4a96e1f8844ccff0726f4437fd91e8878c6890
         sha256:d5f3b22f401e28bf402d6a85fb6905da6e966b8640ccc957a8208c0fbad370e5
         sha256:ddfc7fd9d758270e22a67d669884d4e390d18bbe05bf93a7c1c416c3ec7a3c35
         sha256:49aadd9aa543c13035b64ec0fde93247d7625f13efc3c7b97c768be227b45fac -> 1baa3456
     olm/openshift4-ose-local-storage-operator-bundle
       blobs:
         registry.redhat.io/openshift4/ose-local-storage-operator-bundle sha256:f650fb0bbf442b00e9b7c00d9fa6629ab75ad2021df815210a532e90cf96517e 5.42KiB
         registry.redhat.io/openshift4/ose-local-storage-operator-bundle sha256:07a6a80a035fe38587d139a3d24ad398de30f844b1e930965db7591d270c0566 10.34KiB
       manifests:
         sha256:2f3bd4b9fb405c4e6ae5725b64a97e09b597dd3d8373659909c47f898b06d39a -> f3645a00
     olm/openshift4-performance-addon-operator-bundle-registry-container-rhel8
       blobs:
         registry.redhat.io/openshift4/performance-addon-operator-bundle-registry-container-rhel8 sha256:4f4fb700ef54461cfa02571ae0db9a0dc1e0cdb5577484a6d75e68dc38e8acc1 32B
         registry.redhat.io/openshift4/performance-addon-operator-bundle-registry-container-rhel8 sha256:6e159fb8a2ecf83a77ab4ac043fe3fa38b39219f1aae5f726d98e03bec4d8a1d 2.899KiB
         registry.redhat.io/openshift4/performance-addon-operator-bundle-registry-container-rhel8 sha256:9e24305e5fa766f7d753086ccfe6d99fa1a9da65fe9fe783cc0957186b8fc5cf 9.303KiB
       manifests:
         sha256:e7926a59198354d63ace40d054600096de3fb86e77f4c0357189645e286b137f -> cd2b9a2
     olm/openshift4-performance-addon-rhel8-operator
       blobs:
         registry.redhat.io/openshift4/performance-addon-rhel8-operator sha256:94249d6f79d2b13f09a9b5112f5862277c898a1c4afaba493ccdda0c4ab0e887 1.694KiB
         registry.redhat.io/openshift4/performance-addon-rhel8-operator sha256:10dcf39a89eb73b534a83cacf4003ce7e26a44d2a0bb282a4e6a312c7d6d827c 4.058KiB
         registry.redhat.io/openshift4/performance-addon-rhel8-operator sha256:9ac5365600f042b38e14ef1b5cf28212c208ac7d9b8ddf76ac61f8fcae687aa1 33.41MiB
         registry.redhat.io/openshift4/performance-addon-rhel8-operator sha256:dde93efae2ff16e50120b8766f4ff60f0635f420c514d47c40b6e62987423d74 37.49MiB
       manifests:
         sha256:3e8ed35eee92fac3020d5ffb8e11041b342002d2474f00249426a97fa327e489
         sha256:644089fc9e927ab6238fd79cbc94ea09023ac71fdf06ec48d6ac07d8ba9c86a7
         sha256:644089fc9e927ab6238fd79cbc94ea09023ac71fdf06ec48d6ac07d8ba9c86a7 -> fe1027a8
     stats: shared=16 unique=40 size=744.2MiB ratio=0.48

   phase 0:
     lab-installer.karmalabs.corp:5000 olm/olm-index-redhat-operator-index                                       blobs=7  mounts=0 manifests=1 shared=0
     lab-installer.karmalabs.corp:5000 olm/openshift4-performance-addon-operator-bundle-registry-container-rhel8 blobs=3  mounts=0 manifests=1 shared=0
     lab-installer.karmalabs.corp:5000 olm/openshift4-performance-addon-rhel8-operator                           blobs=4  mounts=0 manifests=3 shared=0
     lab-installer.karmalabs.corp:5000 olm/openshift4-ose-local-storage-operator-bundle                          blobs=2  mounts=0 manifests=1 shared=0
     lab-installer.karmalabs.corp:5000 olm/openshift4-ose-local-storage-diskmaker                                blobs=24 mounts=0 manifests=6 shared=16
   phase 1:
     lab-installer.karmalabs.corp:5000 olm/openshift4-ose-local-storage-operator blobs=24 mounts=16 manifests=6 shared=16
     lab-installer.karmalabs.corp:5000 olm/openshift4-ose-kube-rbac-proxy        blobs=24 mounts=16 manifests=6 shared=16

   info: Planning completed in 6.58s
   mounted: lab-installer.karmalabs.corp:5000/olm/olm-index-redhat-operator-index sha256:4ad6714115439f812b62c5d3ee9d1077534bd5fec4244f4cb421771c62d7e62e 13.57MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/olm-index-redhat-operator-index sha256:99bbe933c0e4433c7fd6941c88af807907a5c024eeea9ba68168b0a02104f64f 20.93KiB
   mounted: lab-installer.karmalabs.corp:5000/olm/olm-index-redhat-operator-index sha256:0c3f40efe9c88feb29cd66831b5fb7bd1cd6816a65fe56911631f1050ab19444 3.747MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/olm-index-redhat-operator-index sha256:c3528915f8acda6a378f500237b8d3ce80951ac0556f059b834891ca42ee629f 812KiB
   mounted: lab-installer.karmalabs.corp:5000/olm/olm-index-redhat-operator-index sha256:639208cddb94771f2d42cf8f53ec21e6ea7a1e17485806b8ffa3b6b7528cc11e 686.5KiB
   sha256:c751ebab527f6572eaac9ea7681af629845c9852573ea2ed0f608b5fd4fa7cd0 lab-installer.karmalabs.corp:5000/olm/olm-index-redhat-operator-index:v4.9
   sha256:e7926a59198354d63ace40d054600096de3fb86e77f4c0357189645e286b137f lab-installer.karmalabs.corp:5000/olm/openshift4-performance-addon-operator-bundle-registry-container-rhel8:cd2b9a2
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-performance-addon-rhel8-operator sha256:9ac5365600f042b38e14ef1b5cf28212c208ac7d9b8ddf76ac61f8fcae687aa1 33.41MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-performance-addon-rhel8-operator sha256:dde93efae2ff16e50120b8766f4ff60f0635f420c514d47c40b6e62987423d74 37.49MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:2d5d59c100e7ad4ac35a22da06b6df29070833b69ddff30f13cb9e11e69dce1e 78.57MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:71b833585865125a4752cd0885165f3a15bd106b38fb29ba840bde57da4f9cc2 11.34MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:2ae16a9e914000df3a69e9ba24215fb038400fa6d16798e9b6de3e12c69379e2 28.8MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:d0e70ac12890105f713e7bfa4041263bc3ac3fdaa29c684c11fd32ea345cf741 10.59MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:41b5c4fd705c125a86f32562747a39a914ce960ddb9de97d172870bb4b4a824d 27.44MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:3eabe22a2aec9181c0849b1a23a6104a81bcf00bea55a52a45dba613f0afd896 76.79MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:ed6ee657d49e14dc574507ea575b857343d444d423231c7f827ae0d3105b7937 87.04MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:8371edeb80944cd165f030b9809d8dcb6266a91345dd84adaa035a43d7d65a87 10.76MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:c3d0b3cd21108afc0d4c92fa1d81c4a259b5d96a38097d753daef5182b8491f8 6.09MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:eac1b95df832dc9f172fd1f07e7cb50c1929b118a4249ddd02c6318a677b506a 79.44MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:2ba1023276a3f31f3f034f21224704e5f5b2618c0f751ffe6a6898a5e081fc0e 6.133MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:4c4d6e754c8d38fa7deeeb98d90193876a5e6c285e2ab3eaefe9945235951869 30.18MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:5c27806d08be52d124b7a641f9ae3dd9f56665d8f34886c69817d1bd58224548 10.68MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:d210a32994f406eaf5bd279c63f4fb1dcba50b9c1be55ad57fe965e3ad761f72 6.108MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:9253a6e9c3007be9aa6ced2f4b40977efd425bf0ff00f5b7c0a448cc3fe04730 29.98MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker sha256:ac58ad8783963479746820574454cea7577bde4455e634d3375f37aba3633001 6.101MiB
   sha256:2f3bd4b9fb405c4e6ae5725b64a97e09b597dd3d8373659909c47f898b06d39a lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator-bundle:f3645a00
   sha256:3e8ed35eee92fac3020d5ffb8e11041b342002d2474f00249426a97fa327e489 lab-installer.karmalabs.corp:5000/olm/openshift4-performance-addon-rhel8-operator
   sha256:644089fc9e927ab6238fd79cbc94ea09023ac71fdf06ec48d6ac07d8ba9c86a7 lab-installer.karmalabs.corp:5000/olm/openshift4-performance-addon-rhel8-operator:fe1027a8
   sha256:6a5c51b61d31c4f771c1ce02e2f8614c3df24ea8e09fcb8d5ea9ea137e7ce0b6 lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker
   sha256:57ed851ce2bfa1a60b65d1fc0fd8a120443d56c71959eae88b8e16b2e5a7028d lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker
   sha256:6a61dd35c5cf355d285d8d7341a6abd123c526ebc603a177a281acb9764356c7 lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker
   sha256:207dfff315700175332194156b3cce8e0c05ead5a08c95ed258d4ef773cb7385 lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker
   sha256:2574e73af12ea219293d247046d3015a19481905e8b859ad84961086f092f585 lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-diskmaker:d32f4d30
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:c3d0b3cd21108afc0d4c92fa1d81c4a259b5d96a38097d753daef5182b8491f8 6.09MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:71b833585865125a4752cd0885165f3a15bd106b38fb29ba840bde57da4f9cc2 11.34MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:3eabe22a2aec9181c0849b1a23a6104a81bcf00bea55a52a45dba613f0afd896 76.79MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:2ba1023276a3f31f3f034f21224704e5f5b2618c0f751ffe6a6898a5e081fc0e 6.133MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:ac58ad8783963479746820574454cea7577bde4455e634d3375f37aba3633001 6.101MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:8371edeb80944cd165f030b9809d8dcb6266a91345dd84adaa035a43d7d65a87 10.76MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:d0e70ac12890105f713e7bfa4041263bc3ac3fdaa29c684c11fd32ea345cf741 10.59MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:5c27806d08be52d124b7a641f9ae3dd9f56665d8f34886c69817d1bd58224548 10.68MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:2d5d59c100e7ad4ac35a22da06b6df29070833b69ddff30f13cb9e11e69dce1e 78.57MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:ed6ee657d49e14dc574507ea575b857343d444d423231c7f827ae0d3105b7937 87.04MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:4a7a6d81f648de56fd64b4b893b88c754dce1f27fcdbb64fd6a5f31ee147dcef 17.39MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:d210a32994f406eaf5bd279c63f4fb1dcba50b9c1be55ad57fe965e3ad761f72 6.108MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:eac1b95df832dc9f172fd1f07e7cb50c1929b118a4249ddd02c6318a677b506a 79.44MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:c4907b32df1f8f1ee8e0bbe312f999c5cc1422b44929ecf4c8fac386470699fd 17.44MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:fe8ec63cfe4747253fe2543aec59571d0de704c0a43a1eb8f68dab635009f9dc 15.86MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:71b833585865125a4752cd0885165f3a15bd106b38fb29ba840bde57da4f9cc2 11.34MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:d0e70ac12890105f713e7bfa4041263bc3ac3fdaa29c684c11fd32ea345cf741 10.59MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:2ba1023276a3f31f3f034f21224704e5f5b2618c0f751ffe6a6898a5e081fc0e 6.133MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:2d5d59c100e7ad4ac35a22da06b6df29070833b69ddff30f13cb9e11e69dce1e 78.57MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:c3d0b3cd21108afc0d4c92fa1d81c4a259b5d96a38097d753daef5182b8491f8 6.09MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:ed6ee657d49e14dc574507ea575b857343d444d423231c7f827ae0d3105b7937 87.04MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:3eabe22a2aec9181c0849b1a23a6104a81bcf00bea55a52a45dba613f0afd896 76.79MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:eac1b95df832dc9f172fd1f07e7cb50c1929b118a4249ddd02c6318a677b506a 79.44MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy sha256:89b92dfc7f69c1d7f3b31b47890b98bd33b1ae61b67899b03576bd07a3d3c47f 16.28MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:5f66527c36bb05f734652a043a1f53f29e1189490e78310bce6a9293151df772 20.08MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:ac58ad8783963479746820574454cea7577bde4455e634d3375f37aba3633001 6.101MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:c5f97614663335c43d29bf34fcfee521acb7f7ec407cd225a22dff373ad62b23 18.29MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:daf0fc851c5133b93fd32086cedec51d7f7119b047cd57500f9b4987eac90886 21.54MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:d210a32994f406eaf5bd279c63f4fb1dcba50b9c1be55ad57fe965e3ad761f72 6.108MiB
   uploading: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:74a2cc6bd6c4ac46722886fc654fd4bf4aa2b0885bab3ee05764ea1e90bed9d9 21.44MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:5c27806d08be52d124b7a641f9ae3dd9f56665d8f34886c69817d1bd58224548 10.68MiB
   mounted: lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator sha256:8371edeb80944cd165f030b9809d8dcb6266a91345dd84adaa035a43d7d65a87 10.76MiB
   sha256:4fc86a4a96c593c8f234d4edf057c9e2215ff799a82464d81adcb6dd13ea455e lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy
   sha256:96ebd88d19be8a3b5679ad24041d456e01c0a1a9f0bf9a535725488083f4cd17 lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy
   sha256:ca006e25d09c1706a7faec17527ff4a14e64368d6541583b519dbaeb4a30d32f lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy
   sha256:b98bd93ac4f9efe1cbcac3936076568fae6cc6c19845fab12a1b80586b33296f lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy
   sha256:8b4f814c112d7b91dc5e7904d4f3c684f3d77227344d2b553a84d4a1bc2829d3 lab-installer.karmalabs.corp:5000/olm/openshift4-ose-kube-rbac-proxy:a8cc7e74
   sha256:ddfc7fd9d758270e22a67d669884d4e390d18bbe05bf93a7c1c416c3ec7a3c35 lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator
   sha256:d5f3b22f401e28bf402d6a85fb6905da6e966b8640ccc957a8208c0fbad370e5 lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator
   sha256:a9d05d9f01a6405d3c1847198b4a96e1f8844ccff0726f4437fd91e8878c6890 lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator
   sha256:20724e13517cbe1febbd40f66f87c174c2e2e1ae016f566fcd36d88da615fa38 lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator
   sha256:49aadd9aa543c13035b64ec0fde93247d7625f13efc3c7b97c768be227b45fac lab-installer.karmalabs.corp:5000/olm/openshift4-ose-local-storage-operator:1baa3456
   info: Mirroring completed in 44.82s (16.97MB/s)
   no digest mapping available for lab-installer.karmalabs.corp:5000/olm-index/redhat-operator-index:v4.9, skip writing to ImageContentSourcePolicy
   wrote mirroring manifests to manifests-redhat-operator-index-1637920908

   real    0m52.593s
   user    0m9.901s
   sys 0m4.806s

The script does the following:

-  Gathers oc-mirror binary
-  Leverages it to create a catalog where to sync images of the choosen operators
-  Syncs the corresponding operators
-  Applies the generated catalogsource and imagecontentsource policy so that the nodes use the disconnected source for those operators. When run prior to deploying, those assets are rather added as extra manifests for the install.

Openshift deployment
====================

Now, we can finally launch the deployment!!!

::

   /root/scripts/07_deploy_openshift.sh

Expected Output

::

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
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-random src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-random\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-vsphereprivate src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-vsphereprivate\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-ignition src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-ignition\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-local src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-local\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-ovirt src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-ovirt\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-google src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-google\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-ironic src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-ironic\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-libvirt src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-libvirt\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-openstack src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-openstack\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-vsphere src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-vsphere\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-aws src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-aws\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-azurerm src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-azurerm\""
   time="2020-05-12T09:56:35Z" level=debug msg="Symlinking plugin terraform-provider-azureprivatedns src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-407594662/plugins/terraform-provider-azureprivatedns\""
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
   time="2020-05-12T10:10:10Z" level=info msg="Waiting up to 20m0s for the Kubernetes API at https://api.lab.karmalabs.corp:6443..."
   time="2020-05-12T10:10:10Z" level=info msg="API v1.18.2 up"
   time="2020-05-12T10:10:10Z" level=info msg="Waiting up to 40m0s for bootstrapping to complete..."
   time="2020-05-12T10:17:24Z" level=debug msg="Bootstrap status: complete"
   time="2020-05-12T10:17:24Z" level=info msg="Destroying the bootstrap resources..."
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-libvirt src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-libvirt\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-openstack src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-openstack\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-vsphere src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-vsphere\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-aws src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-aws\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-azurerm src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-azurerm\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-azureprivatedns src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-azureprivatedns\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-google src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-google\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-ironic src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-ironic\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-ignition src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-ignition\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-local src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-local\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-ovirt src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-ovirt\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-random src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-random\""
   time="2020-05-12T10:17:24Z" level=debug msg="Symlinking plugin terraform-provider-vsphereprivate src: \"/bin/openshift-install\" dst: \"/tmp/openshift-install-678758349/plugins/terraform-provider-vsphereprivate\""
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
   time="2020-05-12T10:17:32Z" level=info msg="Waiting up to 1h0m0s for the cluster at https://api.lab.karmalabs.corp:6443 to initialize..."
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
   time="2020-05-12T11:13:03Z" level=info msg="Access the OpenShift web-console here: https://console-openshift-console.apps.lab.karmalabs.corp"
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
   time="2020-05-12T11:13:03Z" level=info msg="Waiting up to 1h0m0s for the cluster at https://api.lab.karmalabs.corp:6443 to initialize..."
   time="2020-05-12T11:13:03Z" level=debug msg="Cluster is initialized"
   time="2020-05-12T11:13:03Z" level=info msg="Waiting up to 10m0s for the openshift-console route to be created..."
   time="2020-05-12T11:13:03Z" level=debug msg="Route found in openshift-console namespace: console"
   time="2020-05-12T11:13:03Z" level=debug msg="Route found in openshift-console namespace: downloads"
   time="2020-05-12T11:13:03Z" level=debug msg="OpenShift console route is created"
   time="2020-05-12T11:13:03Z" level=info msg="Install complete!"
   time="2020-05-12T11:13:03Z" level=info msg="To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/root/ocp/auth/kubeconfig'"
   time="2020-05-12T11:13:03Z" level=info msg="Access the OpenShift web-console here: https://console-openshift-console.apps.lab.karmalabs.corp"
   time="2020-05-12T11:13:03Z" level=info msg="Login to the console with user: \"kubeadmin\", and password: \"XXXX\""
   time="2020-05-12T11:13:03Z" level=info msg="Time elapsed: 0s"

This script does the following things:

-  Calls the script clean.sh located in /root/bin which removes bootstrap vms which would be left around from a previous failed deployment.
-  Calls the previously mentioned helper script redfish.py so that it actually stops through Redfish all the nodes declared in our install-config.yaml.
-  Creates ocp directory where install-config.yaml gets copied.
-  Copies any yaml files from the manifests directory into the ocp/openshift one so that one can customize the installation (Generally unsupported/to be used at one’s own risk).
-  Launches the install retrying several time to account for timeouts.
-  Waits for all workers defined in the *install-config.yaml* to show up.

Troubleshooting the deployment
------------------------------

During the deployment, you can use typical openshift troubleshooting:

1. Connect to the bootstrap vm with ``kcli list vm`` and ``kcli console -s $BOOTSTRAP_VM``
2. Connect to it using ``kcli ssh core@$BOOTSTRAP_VM``
3. Review bootstrap logs using the command showed upon connecting to the bootstrap vm.

Review
======

This concludes the lab !

In this lab, you have accomplished the following activities.

1. Properly prepare a successful Baremetal ipi deployment.
2. Deploy Openshift!
3. Understand internal aspects of the workflow and how to troubleshoot issues.

Additional resources
====================

Documentation
-------------

-  https://github.com/openshift/installer/blob/master/docs/user/metal/install_ipi.md
-  https://openshift-kni.github.io/baremetal-deploy

Cleaning the lab
----------------

::

   kcli delete plan --yes lab
