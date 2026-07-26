#!/usr/bin/env python3
"""
Dynamic Inventory Script for Ansible driven by Terraform Outputs / State.
Outputs JSON format expected by Ansible (--list / --host).
"""

import json
import os
import subprocess
import sys

def get_terraform_outputs():
    tf_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../terraform"))
    try:
        cmd = ["terraform", "output", "-json"]
        result = subprocess.run(cmd, cwd=tf_dir, capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except Exception as e:
        # Fallback inventory for offline/local demonstration mode
        return {
            "control_plane_ips": {"value": ["192.168.1.10", "192.168.1.11", "192.168.1.12"]},
            "worker_ips": {"value": ["192.168.1.20", "192.168.1.21", "192.168.1.22"]},
            "lb_ip": {"value": "192.168.1.100"}
        }

def build_ansible_inventory(tf_outputs):
    control_planes = tf_outputs.get("control_plane_ips", {}).get("value", ["192.168.1.10"])
    workers = tf_outputs.get("worker_ips", {}).get("value", ["192.168.1.20"])
    lb_ip = tf_outputs.get("lb_ip", {}).get("value", "192.168.1.100")

    inventory = {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            "children": ["control_plane", "workers", "loadbalancers"]
        },
        "control_plane": {
            "hosts": [f"k8s-cp-{i+1}" for i in range(len(control_planes))]
        },
        "workers": {
            "hosts": [f"k8s-worker-{i+1}" for i in range(len(workers))]
        },
        "loadbalancers": {
            "hosts": ["k8s-lb-1"]
        }
    }

    # Host vars assignment
    for i, ip in enumerate(control_planes):
        hostname = f"k8s-cp-{i+1}"
        inventory["_meta"]["hostvars"][hostname] = {
            "ansible_host": ip,
            "ansible_user": "root",
            "node_role": "control-plane"
        }

    for i, ip in enumerate(workers):
        hostname = f"k8s-worker-{i+1}"
        inventory["_meta"]["hostvars"][hostname] = {
            "ansible_host": ip,
            "ansible_user": "root",
            "node_role": "worker"
        }

    inventory["_meta"]["hostvars"]["k8s-lb-1"] = {
        "ansible_host": lb_ip,
        "ansible_user": "root",
        "node_role": "loadbalancer"
    }

    return inventory

def main():
    tf_outputs = get_terraform_outputs()
    inventory = build_ansible_inventory(tf_outputs)
    
    if len(sys.argv) == 2 and sys.argv[1] == "--host":
        print(json.dumps({}))
    else:
        print(json.dumps(inventory, indent=2))

if __name__ == "__main__":
    main()
