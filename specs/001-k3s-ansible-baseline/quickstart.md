# Quickstart: Baseline k3s Ansible Cluster Lifecycle

This quickstart explains how to use the Ansible playbooks to provision and manage a k3s cluster according to the baseline specification.

## 1. Prerequisites

- Control node with Ansible Core 2.15+ installed.
- SSH access from the control node to all target hosts.
- Target hosts running a supported Linux distribution (e.g., Debian/Ubuntu), systemd-based, x86_64 or arm64.
- Basic DNS in place for the control-plane VIP/hostname and any ingress hostnames (e.g., Rancher).

## 2. Clone the Repository

- Clone this repository onto the Ansible control node.

## 3. Define Inventory and Variables

- Copy an example inventory from `ansible/inventories/examples/` into your own directory.
- Populate the `k3s_servers` and `k3s_agents` groups with your hosts.
- Set cluster-level variables for:
  - Cluster name and k3s version.
  - Control-plane VIP and API port.
  - Cluster and service CIDRs.
  - Add-on configurations (cert-manager, multus VLANs, Rancher, rancher-monitoring, Traefik, optional Synology CSI, DNS provider).

## 4. Provision a New HA Cluster

- Run the cluster playbook:
  - `ansible-playbook -i <your-inventory> ansible/playbooks/cluster.yml`
- Verify:
  - `kubectl get nodes` shows all control-plane and worker nodes.
  - Control-plane is reachable via the VIP endpoint.
  - Core add-ons (cert-manager, multus, Rancher, monitoring, Traefik) are deployed and healthy.

## 5. Update Cluster Configuration

- Modify your group/host variable files to reflect the new desired configuration (for example, DNS-01 provider settings, Rancher hostname, Traefik options).
- Re-run the same cluster playbook:
  - `ansible-playbook -i <your-inventory> ansible/playbooks/cluster.yml`

## 6. Scale Nodes

- Add or remove hosts in the inventory groups and update host vars as necessary.
- Run the scale playbook:
  - `ansible-playbook -i <your-inventory> ansible/playbooks/scale-nodes.yml`

## 7. Perform a Minor/Patch k3s Upgrade

- Update the `k3s_version` variable to the desired compatible minor/patch.
- Run the upgrade playbook:
  - `ansible-playbook -i <your-inventory> -e k3s_version=<new-version> ansible/playbooks/upgrade-k3s.yml`

## 8. Enable Optional Synology CSI

- Define Synology CSI variables (endpoint, credentials, storage classes).
- Set `synology_csi_enabled: true` in the appropriate variable file.
- Re-run the cluster playbook to deploy and configure Synology CSI.

## 9. Validation and Smoke Tests

- Run `ansible-lint` on the playbooks/roles.
- Use `ansible-playbook --check` for dry-run validation against non-production inventories.
