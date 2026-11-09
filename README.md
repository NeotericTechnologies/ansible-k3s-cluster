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

For a functional cluster, keep the inventory and network-specific overrides in
your private `ansible-k3s-cluster-ops` repository. Follow
[Private Configuration and Multi-Repository Workspace](#private-configuration-and-multi-repository-workspace)
below to set up the companion repository and Vault password.

Copy an example inventory into the private repository and customize it:

```bash
mkdir -p ../ansible-k3s-cluster-ops/ansible/inventories
cp -r ansible/inventories/examples/ha-cluster ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster
vi ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster/hosts.ini
```

### 3. Configure Variables

Public defaults are in `ansible/group_vars/all/`, with each component's settings
in its own file. Put environment-specific values in the private inventory's
`group_vars/all/` overrides rather than changing public defaults. The following
examples show the corresponding component settings:

```yaml
# ansible/group_vars/all/k3s.yml
cluster_name: "my-k3s-cluster"
k3s_version: "v1.28.5+k3s1"
control_plane_vip: "192.168.1.100"

# ansible/group_vars/all/kube-vip.yml
kube_vip_interface: "eth0"

# Enable desired add-ons in their component files
# ansible/group_vars/all/cert-manager.yml
cert_manager_enabled: true
# ansible/group_vars/all/rancher.yml
rancher_enabled: true
# ansible/group_vars/all/traefik.yml
traefik_enabled: true
# ansible/group_vars/all/multus.yml
multus_enabled: true
```

Version management policy:

- Treat the matching files under `ansible/group_vars/all/` as the canonical source for managed component versions.
- Avoid embedding new hard-coded versions in role defaults or playbook commands.
- Use inventory-specific overrides (for example files under `../ansible-k3s-cluster-ops/ansible/inventories/test-cluster/group_vars/all/`) when environment-specific version differences are required.

For multus VLAN networking, define secondary networks in the private inventory:

```yaml
# VLAN networks with DHCP-based IP assignment (default)
multus_vlan_networks:
  - name: iot-vlan
    # Must match an interface that exists on every target node.
    # Using ens18 (same NIC as kube_vip_interface) avoids "Link not found" from macvlan.
    interface: ens18
    # Leave vlan_id unset unless the host already has a matching VLAN subinterface (e.g. ens18.10).
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
# Recommended: Unified playbook for install and upgrades (same command)
ansible-playbook \
  -i ansible/default-inventory.yml \
  -i ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster \
  ansible/playbooks/site.yml
```

Alternatively, use individual playbooks for granular control:

```bash
# Deploy k3s core cluster (control-plane + workers + kube-vip)
ansible-playbook -i ansible/default-inventory.yml \
  -i ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster \
  ansible/playbooks/cluster-core.yml

# Deploy optional platform add-ons
ansible-playbook -i ansible/default-inventory.yml \
  -i ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster \
  ansible/playbooks/cluster-addons.yml
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

## Private Configuration and Multi-Repository Workspace

Use a **private** `ansible-k3s-cluster-ops` repository alongside this project.
It is a configuration companion, not a standalone Ansible project: this
repository provides the playbooks, roles, collection requirements, public
defaults, and Ansible configuration.

### Repository Layout and Overrides

Clone your private repository beside the main checkout:

```bash
# Run from the ansible-k3s-cluster repository root
git clone <your-private-ops-repository-url> ../ansible-k3s-cluster-ops
```

Keep the inventory layout in the private repository:

```text
ansible-k3s-cluster-ops/
└── ansible/inventories/test-cluster/
    ├── hosts.ini
    ├── group_vars/all/       # Plaintext and encrypted component overrides
    │   ├── kube-vip.yml      # Non-sensitive settings
    │   └── kube-vip-sensitive.yml # Vault-encrypted sensitive settings
    └── host_vars/           # Encrypted host connection details
        └── k3s-server-01.yml
```

Use generic host aliases in `hosts.ini`, with membership in `k3s_servers`,
`k3s_agents`, and their parent `k3s_cluster` group, as shown in the example
inventories. Store each host's `ansible_host` and connection settings in its
matching `host_vars/<alias>.yml` file.

Keep sensitive values in the private repository, encrypted with Ansible Vault:

- IP addresses, address ranges, ports, and hostnames (not repository names)
- Email addresses and credentials
- Multus VLAN network configuration, including interfaces and IPAM settings
- Synology and NFS endpoints and storage class configuration

The sensitive sections at the bottom of the public component files identify
settings to override. Preserve public defaults unless your environment needs a
different value; private overrides may also select add-ons or versions.

Separate each component's private overrides into `<component>.yml` for
non-sensitive settings (versions, enablement flags, replica counts) and
`<component>-sensitive.yml` for Vault-encrypted sensitive values. Ansible loads
both files automatically. Define each variable in only one file to avoid
conflicting values. Keep host connection details encrypted in `host_vars/`.

### Shared Vault Settings and Automatic Decryption

Provide the matching Vault password in the main project's Git-ignored
`.vault_pass` file, with access limited to its owner. Never commit it, copy it
into the ops repository, or include it in logs or shared output. Ensure the
private repository also ignores password files and other unencrypted secrets.

Run Ansible and Vault commands from the **main repository root**.
The main [ansible.cfg](ansible.cfg) defines
`vault_identity_list = ansible-k3s-cluster@.vault_pass` and
`vault_password_file = .vault_pass`. Ansible uses these settings for automatic
decryption of the private inventory variables; no `--vault-id` or
`--ask-vault-pass` option is needed.

For example, create or edit an encrypted override from the main checkout:

```bash
mkdir -p ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster/group_vars/all
ansible-vault create --encrypt-vault-id ansible-k3s-cluster \
  ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster/group_vars/all/kube-vip-sensitive.yml

# Use edit instead of create for an existing encrypted file
ansible-vault edit \
  ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster/group_vars/all/kube-vip-sensitive.yml
```

Encrypt existing plaintext variable files with `ansible-vault encrypt
--encrypt-vault-id ansible-k3s-cluster <file>` before committing them.
Do not commit a real environment's plaintext inventory addresses or credentials.

### Combine Public Defaults with Private Inventory

Pass both inventory sources, with the public defaults first:

```bash
ansible-playbook \
  -i ansible/default-inventory.yml \
  -i ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster \
  ansible/playbooks/cluster-core.yml
```

[ansible/default-inventory.yml](ansible/default-inventory.yml) contains
`all: {}`. Its location beside `ansible/group_vars` lets Ansible discover the
public all/server/agent variables. The second inventory supplies hosts and
inventory-scoped overrides, which take precedence over the corresponding
public defaults. Do not pass `ansible/group_vars` itself as an inventory.

Use the same two `-i` arguments for `site.yml`, `cluster-addons.yml`,
`scale-nodes.yml`, and other lifecycle playbooks. To validate loading and
playbook syntax without deploying:

```bash
ansible-playbook \
  -i ansible/default-inventory.yml \
  -i ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster \
  ansible/playbooks/cluster-core.yml --syntax-check
```

`ansible-inventory --list` or `--host` with these sources can inspect merged
variables, but prints decrypted sensitive values. Do not share that output.

### Manage Both Repositories in VS Code

Open [ansible-k3s-cluster.code-workspace](ansible-k3s-cluster.code-workspace)
in VS Code with **File > Open Workspace from File**, or:

```bash
code ansible-k3s-cluster.code-workspace
```

The workspace includes this checkout (`.`) and the sibling
`../ansible-k3s-cluster-ops` checkout. Both appear in Explorer and Source
Control, so you can manage public automation and private overrides together.
They remain separate Git repositories: review and commit changes to each
independently, and never add private configuration to the public repository.
Keep terminal working directories in the main checkout when running Ansible
so its configuration and Vault password file are used.

## Project Structure

```
ansible/
├── default-inventory.yml # Inventory source for public defaults (all: {})
├── inventories/          # Inventory files
│   └── examples/        # Example HA and single-node inventories
├── group_vars/          # Cluster configuration
│   ├── all/            # Component-specific public defaults
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
    ├── site.yml             # Unified install/upgrade orchestrator
    ├── cluster-core.yml     # Provision/update core cluster
    ├── cluster-addons.yml   # Deploy platform add-ons
    ├── scale-nodes.yml      # Add/remove nodes
    ├── upgrade-k3s.yml      # (deprecated) Minor/patch k3s upgrades
    └── includes/            # Modular upgrade logic
        ├── detect-versions.yml
        ├── compute-plan.yml
        ├── upgrade-k3s-rolling.yml
        ├── upgrade-rancher.yml
        ├── upgrade-kube-vip.yml
        └── upgrade-addon.yml
```

## Usage

For private deployments, use both inventory sources as described in
[Combine Public Defaults with Private Inventory](#combine-public-defaults-with-private-inventory).
The local `ansible/inventories/production` examples below are an alternative
inventory location; include `-i ansible/default-inventory.yml` before that
inventory to load the shared defaults, and do not commit sensitive values here.

### ssh

```bash
ssh-agent bash
ssh-add <path to your private key here>
```

**Example:**

> [!NOTE]
> The project level `.ssh` is an ignored folder.

```bash
ssh-agent bash
ssh-add ./.ssh/Private\ SSH\ Key\ -\ Neoteric\ -\ wade.openssh
```

### Provision Core Cluster

```bash
ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-core.yml
```

```bash
ansible-playbook -i ansible/default-inventory.yml \
  -i ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster \
  ansible/playbooks/cluster-core.yml
```

### Deploy Add-ons

```bash
ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-addons.yml
```

```bash
ansible-playbook -i ansible/default-inventory.yml \
  -i ../ansible-k3s-cluster-ops/ansible/inventories/test-cluster \
  ansible/playbooks/cluster-addons.yml
```


### Update Configuration

Modify variables in `group_vars/` and re-run playbooks to apply changes:

```bash
# Update core cluster settings
ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-core.yml

# Update add-on configuration
ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-addons.yml
```

### Scale Nodes

Add new hosts to inventory, then:

```bash
ansible-playbook -i ansible/inventories/production ansible/playbooks/scale-nodes.yml
```

### Upgrade k3s Version

Update `k3s_version` in `group_vars/all/k3s.yml`, then:

```bash
# Recommended: Unified workflow (handles dependency ordering, cordon/drain, constraint validation)
ansible-playbook -i ansible/inventories/production ansible/playbooks/site.yml
```

To upgrade Rancher and k3s together (Rancher is upgraded first automatically):

```bash
# Update rancher_version in group_vars/all/rancher.yml and k3s_version in group_vars/all/k3s.yml, then:
ansible-playbook -i ansible/inventories/production ansible/playbooks/site.yml
```

To allow a version downgrade:

```bash
ansible-playbook -i ansible/inventories/production ansible/playbooks/site.yml \
  -e "allow_downgrade=true"
```

Legacy upgrade playbook (deprecated, still functional):

```bash
ansible-playbook -i ansible/inventories/production ansible/playbooks/upgrade-k3s.yml
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
ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-core.yml --check
```

### Smoke Tests

```bash
ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/smoke.yml
```

### Focused Feature Smoke Tests
```bash
ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/multus-dhcp-test.yml
ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/scale-test.yml
ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/upgrade-test.yml
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

- **Conditional Deployment**: Enable/disable via `*_enabled` flags in the corresponding files under `group_vars/all/`
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

1. Check prerequisites: `ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-core.yml --tags prerequisites`
2. Verify SSH access: `ansible -i ansible/inventories/production all -m ping`
3. Check control-plane VIP: `ping <control_plane_vip>`

### Control-plane VIP not accessible

1. Verify kube-vip pods: `kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip`
2. Check network interface: Ensure `kube_vip_interface` matches your host's network interface
3. Verify ARP: `ip addr show` on control-plane nodes should show VIP

### Add-ons not deploying

1. Check enablement flags in the corresponding files under `group_vars/all/`
2. Verify cluster is operational: `kubectl get nodes`
3. Check pod status: `kubectl get pods -A`

## Development

This project has been configured to use GitHub Spec Kit. The project includes a dev container with Spec Kit installed for this purpose so you can avoid installing any tooling locally on your machine.

For environment-specific configuration, open the
[multi-repository workspace](#manage-both-repositories-in-vs-code) to work on
this project and your private ops repository together.

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
