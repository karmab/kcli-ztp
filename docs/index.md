# Introduction and Prerequisites

This hands on lab guides the user in deploying Openshift using baremetal IPI. The goal is to make you understand Baremetal IPI internals and workflow so that you can easily make use of it with real Baremetal and troubleshoot issues.

This guide is a reference, you will need to make substitutions where needed below. 

## General Prerequisites

You will need the following items to be able to complete the lab from beginning to end.

## Prereqs
* Access to a libvirt instance
* Pull secret from try.openshift.com
* Kcli installed and configured against your target hypervisor


# Deploy infrastructure

## Deploy The plan

We use the following command:

```
kcli create plan -P lab lab
```


We deploy 3 masters to emulate baremetal

```
kcli list vm
```

We are also deploying an additional installer vm for the purpose of the lab, which will contain all the scripts to be launched in the next sessions.

2. Note the ip for the installer vm and connect to it

```
kcli info vm lab-installer -o ip
```

3. Connect to the vm and explore the artefacts available in /root


```
kcli ssh root@lab-installer
ls /root
```

**NOTE:** In the remainder of the lab, we assume you are connected (through ssh) to the installer vm


# Preparation of the node


```
bash /root/00_prep.sh
```

# Binaries retrieval


```
01_get_clients.sh
```

# Caching of images

```
02_cache.sh
```

# Disconnected procedure

```
03_disconnected.sh
```

# Install config patching

```
04_patch_installconfig.sh
```

# Virtual masters handling

```
05_virtual.sh
```

# Openshift deployment

```
06_deploy_openshift.sh
```

# Review

This concludes the lab !

In this lab, you have accomplished the following activities.

1. Properly prepare a successful Baremetal ipi.
2. Deploy Openshift!
3. Understand internal aspects of the workflow and how to troubleshoot issues
