#!/usr/bin/env python3

import os
import sys
import yaml

action = sys.argv[1] if len(sys.argv) > 1 else 'status'
installfile = "/root/install-config.yaml"
with open(installfile) as f:
    data = yaml.safe_load(f)
    hosts = data['platform']['baremetal']['hosts']
    for host in hosts:
        name = host['name']
        address = host['bmc']['address']
        if 'ipmi' not in address:
            continue
        address = address.replace('ipmi://', '').replace('[', '').replace(']', '')
        if ':' in address:
            port = address.split(':')[-1]
            address = address.replace(':%s' % port, '')
            port = '-p %s' % port
        else:
            port = ''
        username = host['bmc']['username']
        password = host['bmc']['password']
        cmd = "ipmitool -H %s -U %s -P %s -I lanplus %s chassis power %s" % (address, username, password, port, action)
        print(cmd)
        os.system(cmd)
