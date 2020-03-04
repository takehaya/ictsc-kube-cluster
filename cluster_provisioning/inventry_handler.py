#!/usr/bin/env python
# -*- coding:utf-8 -*-

import os
import subprocess
import json

def insert_inventory(inv, baddr, addr, port, host_name):
    if host_name == "k8s_lb_server_ipaddressport":
        inv["lb_server"]["hosts"].append(addr)

    inv["cloud_servers"]["hosts"].append(addr)
    inv["_meta"]["hostvars"][addr] = {"ansible_host": baddr, "ansible_port": port}

__location__ = os.path.realpath(
    os.path.join(os.getcwd(), os.path.dirname(__file__)))

baseaddr = ""
cmd = 'terraform workspace show'
workspacedir = (subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True).communicate()[0]).decode('utf-8').strip()
filepath = "terraform.tfstate.d/%s/terraform.tfstate" % workspacedir

with open(os.path.join(__location__, filepath)) as f:
    hosts = json.loads(f.read())
 
inventory = {
    "cloud_servers":{"hosts":[]}, 
    "_meta": {"hostvars": {}}
    }

for host_name in hosts["outputs"]:
    if host_name == "public_address_list":
        continue
    
    if host_name == "k8s_lb_server_ipaddressport":
        inventory["lb_server"] = {"hosts":[]}

    prefix = host_name.split("_")[-1]
    conndata = hosts["outputs"][host_name]['value']
    if prefix == "addr":
        baseaddr = conndata
    elif prefix == "ipaddressport":
        dnets = conndata
        if isinstance(dnets, list):
            for dnet in dnets:
                addr, port = dnet.split("=")
                insert_inventory(inventory, baseaddr, addr, str(port), host_name)


print(json.dumps(inventory))
