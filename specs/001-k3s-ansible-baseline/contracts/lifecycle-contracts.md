# Contracts: k3s Ansible Cluster Lifecycle

This document maps user actions to Ansible playbook entrypoints and describes the inputs and observable outcomes.

## Cross-Cutting Constraints

All contracts below are subject to these k3s deployment compatibility rules:

- **No symlinks on nodes**: No role or task may create symlinks on target nodes for deployment artifacts.
- **No runtime file copies to nodes**: Add-ons must be deployed as in-cluster resources via the Kubernetes API (Helm charts, manifests via `kubernetes.core` modules), not by copying files to the node filesystem.
- **No modification of default k3s paths**: Roles must not remove, rename, or alter paths managed by k3s (`/var/lib/rancher/k3s`, `/etc/rancher/k3s`, etc.).
- **Multus deployment via Helm**: Multus CNI must be installed using the official Helm chart from `https://k8snetworkplumbingwg.github.io/helm-charts`, with Helm values configuring k3s-compatible host paths for CNI config and binary directories.

## Contract C-001: Provision New HA k3s Cluster

- **User Action**: "Provision a new HA k3s cluster with optional platform add-ons."
- **Playbooks**: `ansible/playbooks/cluster-core.yml` (core) and, optionally, `ansible/playbooks/cluster-addons.yml` (add-ons)
- **Invocation (example)**:
  - Core only: `ansible-playbook -i ansible/inventories/examples/ha-cluster ansible/playbooks/cluster-core.yml`
  - Core + add-ons: `ansible-playbook -i ansible/inventories/examples/ha-cluster ansible/playbooks/cluster-core.yml && ansible-playbook -i ansible/inventories/examples/ha-cluster ansible/playbooks/cluster-addons.yml`
- **Required Inputs**:
  - Inventory with `k3s_servers` and `k3s_agents` groups populated.
  - Group/host vars defining `ClusterConfig`, `NetworkConfig`, and (optionally) `AddonConfig` (including kube-vip, cert-manager, multus, Rancher, rancher-monitoring, Traefik, and Synology CSI).
  - kube-vip variables that explicitly set deployment mode to DaemonSet and define control-plane VIP/service LB address behavior.
- **Expected Outcomes**:
  - New k3s cluster created with embedded etcd HA.
  - kube-vip is installed and running as a DaemonSet.
  - Control-plane reachable via configured VIP/DNS through kube-vip.
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
  - Updated vars for core cluster settings (including kube-vip DaemonSet VIP/service LB configuration) and for cert-manager, Rancher, Traefik, multus, monitoring, or Synology CSI.
- **Expected Outcomes**:
  - Only changed resources are updated; cluster and workloads remain available.
  - kube-vip remains managed as a DaemonSet after updates and converges to desired state.
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
