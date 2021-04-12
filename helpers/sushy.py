#!/usr/bin/env python

import os
import netifaces
import requests
# import socket
import yaml

interface = [i for i in netifaces.interfaces() if str(i) == 'eth0'][0]
addresses = netifaces.ifaddresses(interface)
for address_family in (netifaces.AF_INET, netifaces.AF_INET6):
    family_addresses = addresses.get(address_family)
    if not family_addresses:
        continue
    for address in family_addresses:
        ip = address['addr']
        if ':' in ip:
            ip = '[%s]' % ip
        break

# hostname = socket.gethostname()
# ip = socket.gethostbyname(hostname)
url = "http://%s:8000/redfish/v1/Systems" % ip
systems = {}
for member in requests.get(url).json()['Members']:
    portid = member['@odata.id'].replace('/redfish/v1/Systems/', '')
    name = requests.get("%s/%s" % (url, portid)).json()['Name']
    systems[name] = portid

ports = []
installfile = "/root/install-config.yaml"
with open(installfile) as f:
    data = yaml.safe_load(f)
    uri = data['platform']['baremetal']['libvirtURI']
    hosts = data['platform']['baremetal']['hosts']
    for host in hosts:
        name = host['name']
        address = host['bmc']['address'].replace('ipmi://', '')
        if not address.startswith('DONTCHANGEME') or ':' not in address:
            continue
        else:
            portnumber = address.split(':')[1]
            portid = systems[name]
            ports.append([portnumber, portid])
for entry in ports:
    portnumber, portid = entry
    redfish_url = "redfish-virtualmedia+http://DONTCHANGEME:8000/redfish/v1/Systems/%s" % portid
    cmd = "sed -i s@ipmi://DONTCHANGEME:%s@%s@ %s" % (portnumber, redfish_url, installfile)
    os.system(cmd)
