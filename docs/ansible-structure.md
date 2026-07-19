# Ansible Project Structure

This document describes the organization of the Ansible playbooks, roles, and inventories for managing k3s cluster lifecycle.

## Directory Layout

```
ansible/
├── inventories/          # Inventory definitions
│   ├── examples/        # Example inventories for reference
│   │   ├── ha-cluster/  # 3-node control-plane + workers
│   │   └── single-node/ # Single control-plane node
│   └── production/      # Production inventory (user-defined)
├── group_vars/          # Group-level variables
│   ├── all.yml         # Cluster-wide settings
│   ├── k3s_servers.yml # Control-plane node settings
│   └── k3s_agents.yml  # Worker node settings
├── host_vars/           # Host-specific variables (optional)
├── roles/               # Ansible roles
│   ├── k3s-common/     # Shared prerequisites and validation
│   ├── k3s-server/     # k3s control-plane installation
│   ├── k3s-agent/      # k3s worker node installation
│   ├── kube-vip/       # Control-plane VIP and service load balancer
│   ├── cert-manager/   # Certificate management with DNS-01
│   ├── multus/         # VLAN-based secondary networking
│   ├── rancher/        # Rancher cluster management
│   ├── rancher-monitoring/ # Observability stack
│   ├── traefik/        # Ingress controller configuration
│   └── synology-csi/   # Synology persistent storage (optional)
└── playbooks/           # Playbook entrypoints
    ├── cluster-core.yml     # Provision/update k3s core
    ├── cluster-addons.yml   # Deploy optional platform add-ons
    ├── scale-nodes.yml      # Add/remove nodes
    └── upgrade-k3s.yml      # Minor/patch k3s upgrades

tests/
└── ansible/
    ├── inventories/     # Test inventories
    └── smoke/          # Smoke test playbooks
```

## Supported Platforms

### Target Hosts
- **Operating System**: Debian or Ubuntu Linux (systemd-based distributions)
- **Architecture**: x86_64 or arm64
- **Access**: SSH connectivity from Ansible control node

### Host Prerequisites

Before running the playbooks, ensure each target host meets the following requirements:

#### System Requirements
- **CPU**: Minimum 2 cores (control-plane), 1 core (workers)
- **Memory**: Minimum 2GB RAM (control-plane), 1GB RAM (workers)
- **Storage**: Minimum 20GB available disk space
- **Python**: Python 3.x installed (for Ansible modules)

#### Network Requirements
- **Connectivity**: Hosts must be able to communicate with each other
- **DNS**: Proper DNS resolution or `/etc/hosts` entries
- **Ports**: Required k3s ports must be open between nodes:
  - **6443/tcp**: Kubernetes API (control-plane VIP)
  - **10250/tcp**: Kubelet metrics
  - **2379-2380/tcp**: etcd (control-plane only, embedded etcd HA)
  - **8472/udp**: Flannel VXLAN (default CNI)
  - **51820/udp**: Flannel Wireguard (if using Wireguard backend)
  - **51821/udp**: Flannel Wireguard (if using Wireguard backend)

#### Software Prerequisites
- **systemd**: Required for k3s service management
- **iptables** or **nftables**: Required for kube-proxy
- **Container runtime**: k3s includes containerd (no external runtime needed)

#### Internet Access (if applicable)
- Access to k3s GitHub releases: `https://github.com/k3s-io/k3s/releases`
- Access to container registries: `docker.io`, `quay.io`, `ghcr.io` (for add-ons)
- DNS resolution for external names (Let's Encrypt DNS-01 validation if using cert-manager)

### Ansible Control Node
- **Ansible Core**: Version 2.15 or later
- **Python**: Python 3.8 or later
- **Collections**: Standard Ansible collections (ansible.builtin, kubernetes.core for add-ons)

## Inventory Structure

### Required Groups
- `k3s_servers`: Control-plane nodes (minimum 1, recommended 3 for HA)
- `k3s_agents`: Worker nodes (optional, 0 or more)

### HA Configuration
For high availability with embedded etcd:
- Use **odd number** of control-plane nodes (1, 3, or 5)
- Set `ha_mode: "embedded-etcd-ha"` in `group_vars/all.yml`
- Configure `control_plane_vip` for kube-vip virtual IP

### Single-Node Configuration
For development or small deployments:
- Define single host in `k3s_servers` group
- Set `ha_mode: "single-node"` in `group_vars/all.yml`
- No workers required

## Variable Structure

### Cluster-Wide Variables (`group_vars/all.yml`)
- Cluster identity (name, version)
- Control-plane VIP and port
- Add-on enablement flags
- Add-on configuration (cert-manager, multus, Rancher, etc.)
- kube-vip configuration

### Canonical Version Source Policy

- Use `ansible/group_vars/all.yml` as the authoritative version source for managed components (k3s, kube-vip, cert-manager, multus, Rancher, monitoring, Synology CSI).
- Keep playbooks and role defaults free of duplicate hard-coded version values whenever possible.
- For environment-specific needs, override versions in inventory-scoped group vars rather than editing role internals.

### Same-Scope HA Target Policy

- Every managed component version variable must have corresponding HA/non-HA target variables in the same top-level `group_vars/all.yml` scope.
- Environment-specific adjustments must use inventory-scoped `group_vars/all.yml` overrides for both version and HA target variables together.
- Do not add HA target values only in role defaults when a top-level version variable exists.

### Maintainer Workflow for New Managed Components

1. Add the component version variable in `ansible/group_vars/all.yml`.
2. Add `<component>_ha_min_replicas` and `<component>_non_ha_default_replicas` in the same file section.
3. Add inventory override examples in test/prod inventory `group_vars/all.yml` if needed.
4. Update `docs/ansible-k3s-baseline.md` HA policy table and expectation matrix.
5. Extend `ansible/roles/k3s-common/tasks/resolve-ha-policy.yml` with component policy mapping.
6. Extend runtime observation/validation tasks when executable checks are available.
7. Add/adjust smoke scenarios to verify HA and non-HA behavior.

### Role-Specific Variables
- `group_vars/k3s_servers.yml`: Control-plane node configuration
- `group_vars/k3s_agents.yml`: Worker node configuration
- `host_vars/<hostname>.yml`: Per-host overrides (labels, taints, IPs)

## Playbook Usage

### Provision New Cluster
```bash
# Core k3s cluster only
ansible-playbook -i inventories/production ansible/playbooks/cluster-core.yml

# Core + optional add-ons
ansible-playbook -i inventories/production ansible/playbooks/cluster-core.yml
ansible-playbook -i inventories/production ansible/playbooks/cluster-addons.yml
```

### Update Configuration
```bash
# Update core cluster settings
ansible-playbook -i inventories/production ansible/playbooks/cluster-core.yml

# Update add-on configuration
ansible-playbook -i inventories/production ansible/playbooks/cluster-addons.yml
```

### Scale Nodes
```bash
# Add new nodes (update inventory first)
ansible-playbook -i inventories/production ansible/playbooks/scale-nodes.yml

# Remove nodes (limit to specific hosts)
ansible-playbook -i inventories/production ansible/playbooks/scale-nodes.yml --limit node-to-remove --tags remove
```

### Upgrade k3s Version
```bash
# Minor/patch upgrades only (major upgrades not supported)
ansible-playbook -i inventories/production ansible/playbooks/upgrade-k3s.yml -e k3s_version=v1.28.6+k3s1
```

## Scale and Scope

### Target Scale
This baseline is designed and tested for:
- **Control-plane nodes**: 1-3 nodes (odd number for HA)
- **Worker nodes**: Up to approximately 10 nodes
- **Total cluster size**: Small to medium deployments

### Out of Scope
- **Large-scale operations**: Dozens or hundreds of nodes
- **Full disaster recovery**: Complete etcd loss or rebuild-from-backup
- **Major version upgrades**: k3s major version upgrades (e.g., 1.x → 2.x)

For larger deployments or advanced scenarios, additional tooling and tuning may be required beyond this baseline.

## Non-Goals

- Application workload deployment (focus is infrastructure only)
- Multi-cluster federation or management
- Air-gapped or offline installations (assumes internet access)
- Custom CNI plugins beyond Flannel (k3s default) and multus (secondary networks)

## References

- [k3s Documentation](https://docs.k3s.io/)
- [k3s-io/k3s-ansible](https://github.com/k3s-io/k3s-ansible) - Upstream patterns
- [Feature Specification](../specs/001-k3s-ansible-baseline/spec.md)
- [Data Model](../specs/001-k3s-ansible-baseline/data-model.md)
- [Quickstart Guide](../specs/001-k3s-ansible-baseline/quickstart.md)
