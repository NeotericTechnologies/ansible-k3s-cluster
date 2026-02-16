# Contracts: k3s Ansible Cluster Lifecycle

This document maps user actions to Ansible playbook entrypoints and describes the inputs and observable outcomes.

## Contract C-001: Provision New HA k3s Cluster

- **User Action**: "Provision a new HA k3s cluster with optional platform add-ons."
- **Playbooks**: `ansible/playbooks/cluster-core.yml` (core) and, optionally, `ansible/playbooks/cluster-addons.yml` (add-ons)
- **Invocation (example)**:
  - Core only: `ansible-playbook -i ansible/inventories/examples/ha-cluster ansible/playbooks/cluster-core.yml`
  - Core + add-ons: `ansible-playbook -i ansible/inventories/examples/ha-cluster ansible/playbooks/cluster-core.yml && ansible-playbook -i ansible/inventories/examples/ha-cluster ansible/playbooks/cluster-addons.yml`
- **Required Inputs**:
  - Inventory with `k3s_servers` and `k3s_agents` groups populated.
  - Group/host vars defining `ClusterConfig`, `NetworkConfig`, and (optionally) `AddonConfig` (including cert-manager, multus, Rancher, rancher-monitoring, Traefik, and Synology CSI).
- **Expected Outcomes**:
  - New k3s cluster created with embedded etcd HA.
  - Control-plane reachable via configured VIP/DNS via kube-vip or equivalent.
  - When the add-ons playbook is executed with add-ons enabled, required add-ons are deployed and healthy.
  - Playbooks can be safely re-run without recreating the cluster.

## Contract C-002: Update Existing Cluster Configuration

- **User Action**: "Apply configuration changes to an existing k3s cluster and its add-ons."
- **Playbooks**: `ansible/playbooks/cluster-core.yml` and `ansible/playbooks/cluster-addons.yml`
- **Invocation (example)**:
  - Core only: `ansible-playbook -i <existing-inventory> ansible/playbooks/cluster-core.yml`
  - Core + add-ons: `ansible-playbook -i <existing-inventory> ansible/playbooks/cluster-core.yml && ansible-playbook -i <existing-inventory> ansible/playbooks/cluster-addons.yml`
- **Required Inputs**:
  - Existing inventory and vars representing current desired state.
  - Updated vars for core cluster settings (including kube-vip VIP/service LB configuration) and for cert-manager, Rancher, Traefik, multus, monitoring, or Synology CSI.
- **Expected Outcomes**:
  - Only changed resources are updated; cluster and workloads remain available.
  - No recreation of the cluster or unnecessary node reboots.

## Contract C-003: Scale Nodes (Add/Remove Servers and Agents)

- **User Action**: "Add or remove control-plane and worker nodes."
- **Playbook**: `ansible/playbooks/scale-nodes.yml`
- **Invocation (example)**:
  - `ansible-playbook -i <inventory-with-updated-nodes> ansible/playbooks/scale-nodes.yml`
- **Required Inputs**:
  - Inventory updated to include or remove nodes in `k3s_servers` / `k3s_agents`.
  - Node-specific variables (SSH connectivity, labels, taints) defined for new nodes.
- **Expected Outcomes**:
  - New nodes join the cluster with the correct role.
  - Nodes removed are drained and cleanly detached while preserving etcd quorum when in HA mode.

## Contract C-004: Minor/Patch k3s Upgrade

- **User Action**: "Upgrade k3s within a minor/patch range."
- **Playbook**: `ansible/playbooks/upgrade-k3s.yml`
- **Invocation (example)**:
  - `ansible-playbook -i <inventory> -e k3s_version=v1.29.3+k3s1 ansible/playbooks/upgrade-k3s.yml`
- **Required Inputs**:
  - Desired `k3s_version` variable set to a compatible minor/patch release.
- **Expected Outcomes**:
  - Cluster upgraded in a rolling fashion.
  - No major-version-specific migrations are attempted.
  - Control-plane downtime limited to rolling restarts as per SC-006.

## Contract C-005: Optional Synology CSI Enablement

- **User Action**: "Enable Synology CSI-backed persistent storage."
- **Playbook**: `ansible/playbooks/cluster-addons.yml` (behavior gated by vars)
- **Invocation (example)**:
  - `ansible-playbook -i <inventory> -e synology_csi_enabled=true ansible/playbooks/cluster-addons.yml`
- **Required Inputs**:
  - Synology-specific variables (endpoint, credentials, desired StorageClasses).
- **Expected Outcomes**:
  - Synology CSI driver deployed and configured.
  - Expected StorageClasses created and ready for stateful workloads.
  - Clusters without Synology variables remain unchanged and compliant when only the core cluster playbook is run.
