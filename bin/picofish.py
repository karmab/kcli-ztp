#!/usr/bin/env python3

import os
import netifaces
import re
import sys
import yaml

installfile = "/root/install-config.yaml"


def get_ip(nic='eth0'):
    interface = [i for i in netifaces.interfaces() if str(i) == nic][0]
    addresses = netifaces.ifaddresses(interface)
    for address_family in (netifaces.AF_INET, netifaces.AF_INET6):
        family_addresses = addresses.get(address_family)
        if not family_addresses:
            continue
        for address in family_addresses:
            ip = address['addr']
            if ip.startswith('fe'):
                continue
            else:
                if ':' in ip:
                    ip = '[%s]' % ip
                return ip


picofish = "quay.io/rhsysdeseng/picofish:latest"
port = 8999
nic = sys.argv[1] if len(sys.argv) > 1 else 'eth0'
ip = get_ip(nic=nic)
with open(installfile) as f:
    data = yaml.safe_load(f)
    uri = data['platform']['baremetal']['libvirtURI']
    hosts = data['platform']['baremetal']['hosts']
    for index, host in enumerate(hosts):
        address = host['bmc']['address'].replace('ipmi://', '')
        user, password = host['bmc'].get('username'), host['bmc'].get('password')
        if address.startswith('picofish'):
            port += 1
            match = re.match(".*(http.*|picofish-virtualmedia.*)", address)
            hostip = match.group(1).replace('picofish-virtualmedia://', '').split('/')[0]
            newaddress = f"redfish-virtualmedia://{hostip}:{port}/redfish/v1/Systems/1"
            sedcmd = f"sed -i s/{address}/{newaddress} {installfile}"
            os.system(sedcmd)
            picocmd = f"podman run -p {port}:9000 -e HOST={ip} -e USERNAME={user} -e PASSWORD={password} {picofish}"
            os.system(picocmd)
