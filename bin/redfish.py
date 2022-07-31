#!/usr/bin/env python3

import re
import requests
import sys
import yaml
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
from urllib.parse import urlparse


action = sys.argv[1] if len(sys.argv) > 1 else 'status'
custom_host = sys.argv[2] if len(sys.argv) > 2 else None
installfile = "/root/install-config.yaml"
with open(installfile) as f:
    data = yaml.safe_load(f)
    uri = data['platform']['baremetal']['libvirtURI']
    hosts = data['platform']['baremetal']['hosts']
    for host in hosts:
        name = host['name']
        if custom_host is not None and name != custom_host:
            continue
        address = host['bmc']['address']
        user, password = host['bmc'].get('username'), host['bmc'].get('password')
        if user is None or password is None:
            print(f"Missing creds for {name}. Skipping")
            continue
        if 'ipmi' in address:
            continue
        else:
            match = re.match(".*(http.*|idrac-virtualmedia.*|ilo5-virtualmedia.*|redfish-virtualmedia.*)", address)
            address = match.group(1)
            for _type in ['idrac', 'redfish', 'ilo5']:
                address = address.replace(f'{_type}-virtualmedia', 'https')
            info = requests.get(address, verify=False, auth=(user, password)).json()
            if action == 'status':
                status = info['PowerState']
                print(f"{name}: {status}")
            elif action in ['off', 'on']:
                print(f"running {action} for {name}")
                actions = {'off': 'ForceOff', 'on': 'On'}
                currentaction = actions[action]
                actionaddress = f"{address}/Actions/ComputerSystem.Reset"
                headers = {'Content-type': 'application/json'}
                requests.post(actionaddress, json={"ResetType": currentaction}, headers=headers, auth=(user, password),
                              verify=False)
            elif action == 'reset' and ':8000/redfish/v1/Systems' not in address:
                print(f"resetting {name}")
                manager_address = f"{info['Links']['ManagedBy'][0]['@odata.id']}"
                p = urlparse(address)
                baseurl = f"{p.scheme}://{p.netloc}"
                actionaddress = f"{baseurl}{manager_address}/Actions/Manager.Reset"
                headers = {'Content-type': 'application/json'}
                requests.post(actionaddress, json={"ResetType": "GracefulRestart"}, headers=headers,
                              auth=(user, password), verify=False)
