#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
import time

import requests
import yaml

INSTALL_CONFIG = "/root/install-config.yaml"
OC = "/root/bin/oc"
BMC_WAIT_TIMEOUT = 300


def load_yaml(path):
    if not os.path.exists(path):
        print(f"Path {path} doesn't exist!")
        sys.exit(1)
    with open(path) as f:
        try:
            data = yaml.safe_load(f)
        except Exception as e:
            print(f"Can't load YAML from {path}: {e}")
            sys.exit(1)
    return data


def check_output_run(cmd):
    try:
        result = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        return result
    except subprocess.CalledProcessError as e:
        print(
            f"Got status code {e.returncode} from command \"{' '.join(cmd)}\"")
        print(f"Error message:\n{e.output.decode('utf-8').strip()}")
        sys.exit(e.returncode)


def get_cmd_data(cmd):
    yaml_data = check_output_run(cmd).decode("utf-8").strip()
    return yaml.safe_load(yaml_data)


def wait_for_bmc(bmc_ip):
    # Give it a time to start reboot
    time.sleep(60)
    url = f"https://{bmc_ip}/redfish/v1/"
    web_res = None
    try:
        web_res = requests.get(url, verify=False, timeout=10)
    except Exception:
        pass
    t = 10
    while t < BMC_WAIT_TIMEOUT and web_res is None:
        time.sleep(30)
        t += 40
        try:
            web_res = requests.get(url, verify=False, timeout=10)
        except Exception:
            pass
    if web_res is None or web_res.status_code != 200:
        print(
            f"BMC {bmc_ip} is not up during timeout {BMC_WAIT_TIMEOUT}"
            f"Please check manually when the URL is up: {url}")
        sys.exit(1)
    else:
        print(f"BMC is UP within {t} seconds!")


def reboot_bmc(name, skip_wait_bmc):
    # TODO(sshnaidm): Add support for HP BMs
    auth = ('root', 'calvin')
    headers = {'Accept': 'application/json',
               'Content-Type': 'application/json'}
    url = ("https://%s"
           "/redfish/v1/Managers/iDRAC.Embedded.1/Actions/Manager.Reset")
    install = load_yaml(INSTALL_CONFIG)
    for host in install['platform']['baremetal']['hosts']:
        if host['name'] == name:
            bmc_url = host['bmc']['address']
            for i in bmc_url.split("/"):
                if len(i.split(".")) == 4:
                    bmc_ip = i
                    bmc_redfish = url % bmc_ip
                    ret = requests.post(bmc_redfish,
                                        json={"ResetType": "GracefulRestart"},
                                        verify=False,
                                        auth=auth,
                                        headers=headers)
                    if ret.status_code != 204:
                        print(
                            f"Error status code when resetting BMC {bmc_ip}"
                            f" - {ret.status_code}")
                        sys.exit(1)
                    else:
                        print(f"Successfully rebooted BMC {bmc_ip}")
                        print("Waiting for BMC to come up .......")
                    if not skip_wait_bmc:
                        wait_for_bmc(bmc_ip)


def discover_name(name):
    # Check if we got IP of BMC or BM name
    if len(name.split(".")) != 4:
        return name
    install = load_yaml(INSTALL_CONFIG)
    for host in install['platform']['baremetal']['hosts']:
        if f"/{name}/" in host['bmc']['address']:
            name = host['name']
            return name
    print(f"Can't find IP {name} in install config {INSTALL_CONFIG}")
    sys.exit(1)


def create_bm_yaml(name):

    get_bmh = [
        OC, '-n', 'openshift-machine-api', 'get', 'bmh', name, '-o', 'yaml']
    dict_data = get_cmd_data(get_bmh)
    new_yaml = {
        'apiVersion': dict_data['apiVersion'],
        'kind': dict_data['kind'],
        'metadata': {
            'name': dict_data['metadata']['name'],
            'namespace': dict_data['metadata']['namespace']
        },
        'spec': dict_data['spec'],
    }
    file_path = f"{name}.yaml"
    print(f"Creating a YAML file for a BMH object: {file_path}")
    with open(file_path, "w") as f:
        yaml.safe_dump(new_yaml, f)
    return file_path, dict_data


def create_bmsecret_yaml(bm_data):
    secret_name = bm_data['spec']['bmc']['credentialsName']
    get_secret = [OC, '-n', 'openshift-machine-api', 'get', 'secret',
                  secret_name, '-o', 'yaml']
    dict_data = get_cmd_data(get_secret)
    new_yaml = {
        'apiVersion': dict_data['apiVersion'],
        'kind': dict_data['kind'],
        'metadata': {
            'name': dict_data['metadata']['name'],
            'namespace': dict_data['metadata']['namespace']
        },
        'data': dict_data['data'],
        'type': dict_data['type'],
    }
    file_path = f"{secret_name}.yaml"
    print(f"Creating a YAML file for a secret: {file_path}")
    with open(file_path, "w") as f:
        yaml.safe_dump(new_yaml, f)
    return file_path


def delete(name):
    print(f"Deleting BMH object '{name}' ..........")
    del_cmd = [OC, '-n', 'openshift-machine-api', 'delete', 'bmh', name]
    data = check_output_run(del_cmd)
    if data:
        print("Command output:", data.decode("utf-8").strip())


def apply(file_path):
    print(f"Applying file {file_path}......")
    apply_cmd = [OC, 'apply', '-f', file_path]
    data = check_output_run(apply_cmd)
    if data:
        print("Command output:", data.decode("utf-8").strip())


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("bm_name")
    parser.add_argument("--reboot-bmc", action="store_true",
                        help="Reboot the BMC of baremetal")
    parser.add_argument("--skip-wait-bmc", action="store_true",
                        help="Don't wait for BMC to come up after a reboot.")
    parser.add_argument("--skip-redeploy-bm", action="store_true",
                        help="Skip BM redeploy")
    args = parser.parse_args()
    bm_name = discover_name(args.bm_name)
    if args.reboot_bmc:
        reboot_bmc(bm_name, args.skip_wait_bmc)
    if not args.skip_redeploy_bm:
        bm_yaml, bm_data = create_bm_yaml(bm_name)
        bmsecret_yaml = create_bmsecret_yaml(bm_data)
        delete(bm_name)
        apply(bmsecret_yaml)
        apply(bm_yaml)
        print(
            """Hint:\n"""
            """  In case you detect pending CSRs with command 'oc get csr' -"""
            """ run command """
            """'oc get csr -o name | xargs oc adm certificate approve'""")


if __name__ == "__main__":
    main()
