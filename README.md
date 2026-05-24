# Ansible k3s Cluster Lifecycle Management

A constitutional Ansible repository for managing the complete lifecycle of k3s Kubernetes clusters: provisioning, configuration updates, scaling, and upgrades.

## Features

✨ **Core Capabilities**
- Provision highly-available k3s clusters with embedded etcd (3-node control-plane)
- Single-node development clusters for testing
- Control-plane VIP via kube-vip for HA API access
- LoadBalancer service support via kube-vip cloud controller
- Idempotent playbooks for safe re-runs and configuration updates

🎯 **Platform Add-ons** (Optional, modular deployment)
- **cert-manager**: Provider-agnostic DNS-01 certificate issuers (Cloudflare, Route53, etc.)
- **multus CNI**: VLAN-based secondary pod networking
- **Rancher**: Web-based cluster management and monitoring
- **rancher-monitoring**: Prometheus + Grafana observability stack
- **Traefik**: Ingress controller with LoadBalancer integration
- **Synology CSI**: Persistent storage from Synology NAS (optional)

🔧 **Operational Support**
- Node scaling: Add/remove control-plane and worker nodes
- Minor/patch upgrades: Rolling k3s version upgrades (major upgrades out-of-scope)
- Host prerequisite validation: Fail-fast checks for OS, CPU, memory, ports, network
- Smoke tests and ansible-lint validation

## Quick Start

### Prerequisites

- **Control node**: Ansible Core 2.15+ with Python 3.8+
- **Target hosts**: Debian/Ubuntu Linux (systemd, x86_64/arm64) with SSH access
- **Minimum resources**:
  - Control-plane: 2 CPU cores, 2GB RAM, 20GB disk
  - Workers: 1 CPU core, 1GB RAM, 20GB disk
- **Network**: Required ports open between nodes (see [docs/ansible-structure.md](docs/ansible-structure.md))

### 1. Clone Repository

```bash
git clone <repository-url>
cd ansible-k3s-cluster
```

### 2. Configure Inventory

Copy an example inventory and customize for your environment:

```bash
cp -r ansible/inventories/examples/ha-cluster ansible/inventories/production
vi ansible/inventories/production/hosts.ini
```

### 3. Configure Variables

Edit cluster configuration in `ansible/group_vars/all.yml`:

```yaml
cluster_name: "my-k3s-cluster"
k3s_version: "v1.28.5+k3s1"
control_plane_vip: "192.168.1.100"
kube_vip_interface: "eth0"

# Enable desired add-ons
cert_manager_enabled: true
rancher_enabled: true
traefik_enabled: true
multus_enabled: true
```

For multus VLAN networking, define secondary networks:

```yaml
# VLAN networks with DHCP-based IP assignment (default)
multus_vlan_networks:
  - name: iot-vlan
    # Must match an interface that exists on every target node.
    # Using enp6s18 (same NIC as kube_vip_interface) avoids "Link not found" from macvlan.
    interface: enp6s18
    # Leave vlan_id unset unless the host already has a matching VLAN subinterface (e.g. enp6s18.10).
    ipam_type: dhcp          # dhcp (default) | host-local | static

  - name: iot-vlan-2
    interface: eth0
    vlan_id: 50
    ipam_type: dhcp

  - name: storage-vlan
    interface: eth0
    vlan_id: 100
    ipam_type: host-local
    cidr: 10.10.100.0/24
    gateway: 10.10.100.1
```

See the [Multus role documentation](ansible/roles/multus/README.md) for full configuration details.

### 4. Provision Cluster

```bash
# Deploy k3s core cluster (control-plane + workers + kube-vip)
ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-core.yml

# Deploy optional platform add-ons
ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-addons.yml
```

### 5. Verify Cluster

```bash
# SSH to first control-plane node
ssh admin@k3s-server-01

# Check cluster health
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
kubectl get pods -A
```

## Project Structure

```
ansible/
├── inventories/          # Inventory files
│   ├── examples/        # Example HA and single-node inventories
│   └── production/      # Your production inventory
├── group_vars/          # Cluster configuration
│   ├── all.yml         # Cluster-wide settings
│   ├── k3s_servers.yml # Control-plane config
│   └── k3s_agents.yml  # Worker config
├── roles/               # Ansible roles
│   ├── k3s-common/     # Prerequisites and validation
│   ├── k3s-server/     # Control-plane installation
│   ├── k3s-agent/      # Worker node installation
│   ├── kube-vip/       # VIP and LoadBalancer
│   ├── cert-manager/   # Certificate management
│   ├── multus/         # Secondary networking
│   ├── rancher/        # Cluster management UI
│   ├── rancher-monitoring/ # Observability
│   ├── traefik/        # Ingress controller
│   └── synology-csi/   # Synology persistent storage
└── playbooks/           # Playbook entrypoints
    ├── cluster-core.yml     # Provision/update core cluster
    ├── cluster-addons.yml   # Deploy platform add-ons
    ├── scale-nodes.yml      # Add/remove nodes
    └── upgrade-k3s.yml      # Minor/patch k3s upgrades
```

## Usage

### Provision Core Cluster

```bash
ansible-playbook -i inventories/production ansible/playbooks/cluster-core.yml
```

### Deploy Add-ons

```bash
ansible-playbook -i inventories/production ansible/playbooks/cluster-addons.yml
```

### Update Configuration

Modify variables in `group_vars/` and re-run playbooks to apply changes:

```bash
# Update core cluster settings
ansible-playbook -i inventories/production ansible/playbooks/cluster-core.yml

# Update add-on configuration
ansible-playbook -i inventories/production ansible/playbooks/cluster-addons.yml
```

### Scale Nodes

Add new hosts to inventory, then:

```bash
ansible-playbook -i inventories/production ansible/playbooks/scale-nodes.yml
```

### Upgrade k3s Version

Update `k3s_version` in `group_vars/all.yml`, then:

```bash
ansible-playbook -i inventories/production ansible/playbooks/upgrade-k3s.yml
```

## Documentation

- **[Ansible Structure Guide](docs/ansible-structure.md)**: Directory layout, supported platforms, host prerequisites
- **[Quickstart Guide](specs/001-k3s-ansible-baseline/quickstart.md)**: Step-by-step provisioning and usage examples
- **[Feature Specification](specs/001-k3s-ansible-baseline/spec.md)**: Complete functional requirements
- **[Implementation Plan](specs/001-k3s-ansible-baseline/plan.md)**: Technical architecture and decisions
- **[Multus CNI Role](ansible/roles/multus/README.md)**: VLAN networking, DHCP IPAM, and NetworkAttachmentDefinition configuration
- **[Constitution](.specify/memory/constitution.md)**: Project governance and design principles

## Validation

### Lint Playbooks

```bash
ansible-lint ansible/playbooks/cluster-core.yml
ansible-lint ansible/playbooks/cluster-addons.yml
```

### Dry-Run (Check Mode)

```bash
ansible-playbook -i inventories/production ansible/playbooks/cluster-core.yml --check
```

### Smoke Tests

```bash
ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/smoke.yml
```

## Architecture

### Core Design Principles

1. **Minimal Core**: Separate core k3s provisioning from optional platform add-ons
2. **Idempotent**: Safe to re-run playbooks without side effects
3. **k3s-Specific**: Leverage k3s embedded etcd, no kubeadm assumptions
4. **Variable-Driven**: All configuration via inventory and group_vars, no hardcoded values
5. **Secure Defaults**: No plain-text secrets, Ansible Vault recommended

### HA Architecture

- **Control-plane**: 3-node embedded etcd cluster (odd number required)
- **VIP Access**: kube-vip provides floating IP for API server access
- **LoadBalancer**: kube-vip cloud controller allocates external IPs for LoadBalancer services
- **CNI**: Flannel VXLAN (k3s default) + optional multus for secondary networks

### Add-ons Strategy

- **Conditional Deployment**: Enable/disable via `*_enabled` flags in `group_vars/all.yml`
- **Helm-Based**: Rancher, rancher-monitoring use Helm charts
- **kubectl-Based**: cert-manager, multus, kube-vip use manifests
- **Provider-Agnostic**: cert-manager DNS-01 supports multiple providers via credentials

## Scale and Scope

### Target Scale

- **Control-plane nodes**: 1-3 (odd number for HA)
- **Worker nodes**: Up to ~10 nodes
- **Cluster size**: Small to medium deployments

### Out of Scope

- Large-scale clusters (dozens/hundreds of nodes)
- Full disaster recovery (complete etcd loss)
- Major version upgrades (e.g., k3s 1.x → 2.x)
- Air-gapped/offline installations

## Supported Platforms

- **OS**: Debian 11+, Ubuntu 20.04+
- **Architectures**: x86_64, arm64
- **Init System**: systemd
- **Access**: SSH with sudo privileges

## Troubleshooting

### Cluster not provisioning

1. Check prerequisites: `ansible-playbook -i inventories/production ansible/playbooks/cluster-core.yml --tags prerequisites`
2. Verify SSH access: `ansible -i inventories/production all -m ping`
3. Check control-plane VIP: `ping <control_plane_vip>`

### Control-plane VIP not accessible

1. Verify kube-vip pods: `kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip`
2. Check network interface: Ensure `kube_vip_interface` matches your host's network interface
3. Verify ARP: `ip addr show` on control-plane nodes should show VIP

### Add-ons not deploying

1. Check enablement flags in `group_vars/all.yml`
2. Verify cluster is operational: `kubectl get nodes`
3. Check pod status: `kubectl get pods -A`

## Development

This project has been configured to use GitHub Spec Kit. The project includes a dev container with Spec Kit installed for this purpose so you can avoid installing any tooling locally on your machine.

## Contributing

This project follows constitutional governance. See [.specify/memory/constitution.md](.specify/memory/constitution.md) for design principles and contribution guidelines.

## License

[Specify your license here]

## References

- [k3s Documentation](https://docs.k3s.io/)
- [kube-vip](https://kube-vip.io/)
- [cert-manager](https://cert-manager.io/)
- [Rancher](https://www.rancher.com/)
- [Ansible Documentation](https://docs.ansible.com/)

