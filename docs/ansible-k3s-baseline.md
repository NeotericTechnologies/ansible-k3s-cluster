# k3s Ansible Baseline Documentation

## Overview

This Ansible project provides production-ready automation for managing k3s Kubernetes clusters from initial provisioning through the complete lifecycle including configuration updates, node scaling, and version upgrades.

## Project Goals

- **Provision HA k3s clusters** with embedded etcd (3-node control-plane)
- **Update cluster configuration** idempotently via playbook re-runs
- **Scale nodes** up/down based on inventory changes
- **Upgrade k3s versions** with zero-downtime rolling updates
- **Deploy baseline add-ons** including cert-manager, multus, Rancher, monitoring

## Supported Environments

### Operating Systems

- **Debian 11 (Bullseye)** - Fully tested
- **Debian 12 (Bookworm)** - Fully tested
- **Ubuntu 20.04 LTS** - Supported
- **Ubuntu 22.04 LTS** - Supported

### System Requirements

**Control-Plane Nodes (k3s-servers):**
- 2 CPU cores minimum (4+ recommended for production)
- 4 GB RAM minimum (8+ GB recommended)
- 20 GB disk space for etcd and container images
- systemd init system
- NetworkManager or standard networking

**Worker Nodes (k3s-agents):**
- 2 CPU cores minimum
- 2 GB RAM minimum
- 20 GB disk space
- systemd init system

### Architecture Support

- **x86_64 (amd64)** - Primary target
- **ARM64 (aarch64)** - Supported for edge/embedded use cases

### Network Requirements

**Required Ports (must be open):**

Control-Plane Nodes:
- `6443/tcp` - Kubernetes API server
- `2379-2380/tcp` - etcd client/peer communication
- `10250/tcp` - Kubelet metrics
- `10251/tcp` - kube-scheduler
- `10252/tcp` - kube-controller-manager

Worker Nodes:
- `10250/tcp` - Kubelet API
- `8472/udp` - Flannel VXLAN overlay network

kube-vip:
- ARP broadcasts for VIP failover (Layer 2 network)

**Internet Access:**
- Required for downloading k3s binaries (get.k3s.io)
- Required for pulling container images (docker.io, ghcr.io, registry.k8s.io)
- Air-gapped installations are NOT supported in this baseline

## Scale Assumptions

### Supported Cluster Sizes

- **Control-Plane:** 1-3 nodes
  - Single node: Development/testing only
  - Three nodes: Recommended HA configuration
  - Etcd quorum: Odd numbers preferred (1, 3, 5)

- **Workers:** 0-10 nodes
  - Designed for small-medium workloads
  - Can be scaled beyond 10, but performance testing recommended

### Scale Limitations

**NOT designed for:**
- Large-scale clusters (50+ nodes)
- Multi-datacenter deployments
- Edge computing fleets (100+ locations)
- High-throughput production workloads (1000+ req/s)

For larger scale requirements, consider:
- Rancher RKE2
- kubeadm-based clusters
- Managed Kubernetes services (EKS, AKS, GKE)

## Relationship to k3s-io/k3s-ansible

This project uses [k3s-io/k3s-ansible](https://github.com/k3s-io/k3s-ansible) as an upstream reference (per research decision R-005). Patterns from that project informed the structure of the `k3s-server`, `k3s-agent`, and `k3s-common` roles (host preparation, service installation, token handling). However, this project's roles supersede k3s-ansible directly because:

- Additional integrations are required (kube-vip DaemonSet, cert-manager, multus Helm chart, Rancher, Synology CSI)
- k3s deployment compatibility constraints (no symlinks, no file copies, no path modification) require tighter control
- The playbook lifecycle (scale, upgrade, add-ons) extends beyond k3s-ansible's scope

The `ansible/requirements.yml` documents the `kubernetes.core` and `community.kubernetes` collections used in place of upstream role dependencies.

## Explicit Non-Goals

This baseline intentionally does NOT include:

1. **Disaster Recovery Orchestration**
   - No automated etcd backup/restore
   - No cross-region failover
   - Manual DR procedures required

2. **Multi-Cluster Management**
   - Single cluster focus
   - No federation or multi-cluster coordination
   - Use Rancher for multi-cluster needs

3. **Advanced Networking**
   - No Calico/Cilium integration
   - No network policies by default
   - Basic Flannel VXLAN only

4. **Complex Storage Solutions**
   - No Rook/Ceph integration
   - Basic local-path provisioner
   - Optional Synology CSI for NFS/iSCSI

5. **Air-Gapped Installations**
   - No offline artifact management
   - No private registry configuration
   - Internet access required

6. **Major Version Upgrades**
   - Minor/patch only (e.g., 1.28.5 → 1.28.6)
   - Major upgrades require manual planning
   - No k8s version skipping (1.27 → 1.29)

7. **Application Lifecycle**
   - Infrastructure only
   - No GitOps integration (ArgoCD, Flux)
   - No CI/CD pipelines

8. **Advanced Security**
   - No Pod Security Standards enforcement
   - No OPA/Gatekeeper policies
   - No RBAC role generation
   - Basic TLS defaults only

## Quick Start

### 1. Prerequisites

```bash
# On control machine:
- Ansible Core 2.15+
- Python 3.9+
- SSH key access to all nodes
- sudo privileges on all nodes

# Verify Ansible:
ansible --version
```

### 2. Clone and Configure

```bash
cd ansible/

# Copy example inventory
cp -r inventories/examples/ha-cluster inventories/prod

# Edit inventory
vim inventories/prod/hosts.ini

# Configure cluster variables
vim group_vars/all.yml
```

### 3. Provision Cluster

```bash
# Provision core cluster (control-plane + workers + kube-vip)
ansible-playbook -i inventories/prod/hosts.ini playbooks/cluster-core.yml

# Deploy add-ons (optional)
ansible-playbook -i inventories/prod/hosts.ini playbooks/cluster-addons.yml
```

### 4. Verify Installation

```bash
# Get kubeconfig from first control-plane node
scp user@control-plane-01:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Update server address to VIP
sed -i 's/127.0.0.1/YOUR_VIP_ADDRESS/g' ~/.kube/config

# Verify cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

## Playbook Reference

### cluster-core.yml

**Purpose:** Provision or update core k3s cluster infrastructure

**What it does:**
- Installs k3s on control-plane nodes (embedded etcd HA)
- Deploys kube-vip for control-plane VIP and LoadBalancer services
- Joins worker nodes to cluster
- Validates cluster health

**When to use:**
- Initial cluster provisioning
- Adding/reconfiguring control-plane nodes
- Updating k3s server configuration
- Re-running for idempotent updates

**Example:**
```bash
ansible-playbook -i inventories/prod/hosts.ini playbooks/cluster-core.yml
```

### cluster-addons.yml

**Purpose:** Deploy optional platform add-ons

**What it does:**
- cert-manager: TLS certificate management with DNS-01
- multus: Secondary pod networking (VLANs)
- Rancher: Cluster management UI
- rancher-monitoring: Prometheus + Grafana
- Traefik: Ingress controller (LoadBalancer)
- Synology CSI: NAS persistent storage

**When to use:**
- After cluster-core.yml completes
- Updating add-on configurations
- Enabling/disabling add-ons via group_vars flags

**Example:**
```bash
# Enable specific add-ons in group_vars/all.yml:
cert_manager_enabled: true
traefik_enabled: true

# Deploy
ansible-playbook -i inventories/prod/hosts.ini playbooks/cluster-addons.yml
```

### scale-nodes.yml

**Purpose:** Add or remove cluster nodes based on inventory changes

**What it does:**
- Compares inventory against live cluster state
- Adds new control-plane nodes (serial, with etcd quorum checks)
- Adds new worker nodes
- Drains and removes nodes no longer in inventory
- Validates final cluster state

**When to use:**
- Scaling workers up/down for capacity changes
- Adding control-plane nodes for HA setup
- Decommissioning nodes

**Example:**
```bash
# 1. Edit inventory to add/remove nodes
vim inventories/prod/hosts.ini

# 2. Run scale playbook
ansible-playbook -i inventories/prod/hosts.ini playbooks/scale-nodes.yml
```

**Safety Features:**
- Prevents removing last control-plane node
- Warns about even-numbered control-planes
- Drains workloads before removal
- Serial execution for minimal disruption

### upgrade-k3s.yml

**Purpose:** Rolling k3s version upgrades (minor/patch)

**What it does:**
- Validates cluster health pre-upgrade
- Upgrades control-plane nodes serially (one at a time)
- Waits for each node to return to Ready state
- Upgrades worker nodes serially
- Verifies all nodes report target version

**When to use:**
- Minor version upgrades (e.g., 1.28.x → 1.28.y)
- Patch version upgrades (e.g., 1.28.5+k3s1 → 1.28.5+k3s2)
- Security patch deployment

**Example:**
```bash
# Set target version
ansible-playbook -i inventories/prod/hosts.ini \
  playbooks/upgrade-k3s.yml \
  -e "k3s_version=v1.28.6+k3s1"
```

**Safety Features:**
- Pre-upgrade health validation
- Serial execution (zero downtime)
- Node readiness checks after each upgrade
- Upgrade summary with version verification

**Important:**
- ALWAYS backup etcd before upgrading
- Test upgrades in non-production first
- Review k3s release notes for breaking changes

## Configuration Guide

### Essential Variables

**group_vars/all.yml - Cluster Identity:**
```yaml
cluster_name: my-k3s-cluster
k3s_version: v1.28.5+k3s1
api_port: 6443
```

**group_vars/all.yml - kube-vip (Control-Plane VIP):**
```yaml
control_plane_vip: 192.168.1.100
ha_mode: true
kube_vip_version: v1.1.2
kube_vip_cloud_provider_version: v0.0.12
```

**group_vars/all.yml - LoadBalancer IP Pool:**
```yaml
kube_vip_lb_enabled: true
kube_vip_lb_ip_range: "192.168.1.200-192.168.1.220"
```

**group_vars/all.yml - Add-on Flags:**
```yaml
cert_manager_enabled: true
multus_enabled: false
rancher_enabled: false
rancher_monitoring_enabled: false
traefik_enabled: true
synology_csi_enabled: true
synology_csi_version: "v1.2.1"
synology_csi_namespace: "synology-csi"
synology_csi_endpoint: "synology.example.com"
synology_csi_port: 8443
synology_csi_tls_verify: false
synology_csi_username: "{{ vault_synology_username }}"
synology_csi_password: "{{ vault_synology_password }}"
synology_csi_snapshots_enabled: true
synology_csi_snapshotter_version: "v8.5.0"
synology_csi_storage_classes:
  - name: "synology-iscsi-retain"
    protocol: "iscsi"
    is_default: true
    reclaim_policy: "Retain"
    volume_binding_mode: "Immediate"
    parameters:
      fsType: "ext4"
      location: "/volume1"
  - name: "synology-nfs-delete"
    protocol: "nfs"
    is_default: false
    reclaim_policy: "Delete"
    volume_binding_mode: "Immediate"
    parameters:
      location: "/volume1"
```

`location` must be a DSM volume root path (for example `/volume1` or `/volume2`). Do not use subfolder paths such as `/volume1/my-share`.

### cert-manager Configuration

**Enable with DNS-01 for wildcard certificates:**

```yaml
# group_vars/all.yml
cert_manager_enabled: true
cert_manager_version: "v1.13.3"
cert_manager_email: "admin@example.com"
cert_manager_dns_provider: "cloudflare"  # or route53, digitalocean, google
cert_manager_dns_provider_credentials:
  api_token: "YOUR_CLOUDFLARE_API_TOKEN"
```

**Supported DNS providers:**
- Cloudflare (api_token)
- AWS Route53 (secret_access_key + access_key_id)
- DigitalOcean (access_token)
- Google Cloud DNS (service_account_json)

**Get certificates:**
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-tls
spec:
  secretName: example-tls
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  dnsNames:
    - example.com
    - "*.example.com"
```

### Secrets Management

**Use Ansible Vault for sensitive data:**

```bash
# Create vault file
ansible-vault create group_vars/all/vault.yml

# Add sensitive variables:
vault_cert_manager_api_token: "secret_token_here"
vault_synology_username: "admin"
vault_synology_password: "secret_password"

# Reference in group_vars/all.yml:
cert_manager_dns_provider_credentials:
  api_token: "{{ vault_cert_manager_api_token }}"
synology_csi_username: "{{ vault_synology_username }}"
synology_csi_password: "{{ vault_synology_password }}"

# Run playbooks with vault:
ansible-playbook ... --ask-vault-pass
```

## Testing

### Smoke Tests

**Basic cluster health:**
```bash
ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/smoke.yml
```

**Idempotence validation:**
```bash
ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/idempotence-test.yml
```

**Scale operations:**
```bash
ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/scale-test.yml
```

**Upgrade procedures:**
```bash
ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/upgrade-test.yml
```

### Linting

```bash
cd ansible/
ansible-lint playbooks/*.yml roles/*/tasks/*.yml
```

## Troubleshooting

### Common Issues

**Issue: Control-plane VIP not accessible**
```bash
# Check kube-vip pod status
kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip

# Verify VIP configuration
kubectl describe daemonset kube-vip -n kube-system

# Check ARP table
ip neighbor | grep YOUR_VIP

# Solution: Ensure VIP is in same subnet, check firewall rules
```

**Issue: Worker nodes NotReady**
```bash
# Check worker logs
journalctl -u k3s-agent -n 100

# Verify connectivity to control-plane
# Ensure port 6443 is accessible from workers

# Restart k3s-agent
systemctl restart k3s-agent
```

**Issue: etcd unhealthy**
```bash
# Check etcd status (on control-plane)
k3s kubectl get endpoints -n kube-system kube-controller-manager -o yaml

# Verify etcd members
k3s etcd-snapshot list

# Solution: Ensure odd number of control-planes, check disk space
```

### Log Locations

```bash
# k3s server logs
journalctl -u k3s -f

# k3s agent logs
journalctl -u k3s-agent -f

# View all pods
kubectl get pods --all-namespaces

# Describe failing pod
kubectl describe pod POD_NAME -n NAMESPACE
```

## Maintenance

### Backup Procedures

**etcd Backup:**
```bash
# On control-plane node
k3s etcd-snapshot save --name backup-$(date +%Y%m%d-%H%M%S)

# List snapshots
k3s etcd-snapshot list

# Copy off-server
scp /var/lib/rancher/k3s/server/db/snapshots/* backup-server:/path/
```

**Restore etcd:**
```bash
# Stop k3s on all nodes
systemctl stop k3s

# Restore on first control-plane
k3s server --cluster-reset --cluster-reset-restore-path=/path/to/snapshot

# Restart cluster
systemctl start k3s
```

### Monitoring Health

```bash
# Node status
kubectl get nodes

# System pods
kubectl get pods -n kube-system

# API server health
curl -k https://CONTROL_PLANE_VIP:6443/healthz

# etcd health (on control-plane)
k3s kubectl get cs
```

## Contributing

### Code Standards

- Use FQCN for all Ansible modules (ansible.builtin.*)
- Follow idempotent patterns (no state changes on re-runs)
- Add changed_when guards to command/shell tasks
- Include comprehensive task names
- Document complex logic with comments

### Testing Requirements

- All playbooks must pass ansible-lint
- Run smoke tests before submitting changes
- Test idempotence (playbook runs twice without changes)
- Verify on Debian 11 and Ubuntu 22.04

### Pull Request Template

```markdown
## Description
Brief description of changes

## Testing
- [ ] ansible-lint passed
- [ ] smoke.yml passed
- [ ] idempotence-test.yml passed
- [ ] Tested on Debian 11 / Ubuntu 22.04

## Checklist
- [ ] FQCN modules used
- [ ] Idempotent execution verified
- [ ] Documentation updated
- [ ] No secrets in code
```

## License

This project is licensed under the MIT License.

## Support

For issues and questions:
- GitHub Issues: [project-url]/issues
- Documentation: This file and docs/ansible-structure.md
- k3s Docs: https://docs.k3s.io/

## Version History

- **v1.0.0** - Initial baseline release
  - Core cluster provisioning (embedded etcd HA)
  - kube-vip integration (VIP + LoadBalancer)
  - 6 platform add-ons
  - Scale and upgrade playbooks
  - Comprehensive testing framework
