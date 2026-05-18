# Data Model: Baseline k3s Ansible Cluster Lifecycle

## Overview

This data model describes the configuration entities and relationships that the Ansible playbooks and roles will operate on. It is implementation-agnostic and focuses on the logical structure of inventories, variables, and cluster concepts.

## Entities

### 1. ClusterConfig

Represents the desired state of a single k3s cluster.

- **Fields**:
  - `name`: Human-friendly cluster name.
  - `k3s_version`: Pinned k3s version (minor/patch) for servers and agents.
  - `cluster_cidr`: Pod network CIDR.
  - `service_cidr`: Service network CIDR.
  - `control_plane_vip`: Virtual IP or DNS name used for control-plane access.
  - `api_port`: Port exposed on the VIP for the Kubernetes API.
  - `ha_mode`: Enum: `single-node` | `embedded-etcd-ha`.
  - `addons`: Composite field enabling/disabling add-ons (cert-manager, multus, Rancher, rancher-monitoring, Traefik, Synology CSI).

- **Relationships**:
  - 1-to-many with `NodeConfig` (a cluster has many nodes).
  - 1-to-1 with `NetworkConfig` and `AddonConfig`.

### 2. NodeConfig

Represents a physical or virtual host that participates in the cluster.

- **Fields**:
  - `hostname` / `inventory_name`: Identifier used in Ansible inventory.
  - `role`: Enum: `server` (control-plane) | `agent` (worker).
  - `ip_address`: Primary management IP.
  - `ssh_user`: SSH user Ansible will use.
  - `labels`: Key/value labels to apply to the Kubernetes node.
  - `taints`: Taints for scheduling control.
  - `groups`: Inventory groups this host belongs to (e.g., `k3s_servers`, `k3s_agents`).

- **Relationships**:
  - Many-to-1 with `ClusterConfig`.

### 3. NetworkConfig

Describes cluster networking beyond the base k3s defaults.

- **Fields**:
  - `base_cni`: The default CNI used by k3s.
  - `multus_enabled`: Boolean.
  - `multus_version`: Helm chart version for Multus deployment.
  - `multus_install_method`: Installation method (must be `helm`).
  - `multus_plugin_type`: Plugin variant (must be `thick` — bundles all CNI functionality into a single binary).
  - `multus_cni_conf_dir`: CNI config directory (k3s-specific path override: `/var/lib/rancher/k3s/agent/etc/cni/net.d`).
  - `multus_cni_bin_dir`: CNI binary directory (k3s-specific path override: `/var/lib/rancher/k3s/data/current/bin`).
  - `vlan_networks`: List of `VlanNetwork` definitions used by multus.

- **Relationships**:
  - 1-to-many with `VlanNetwork`.

### 4. VlanNetwork

Represents a single VLAN-backed secondary network for pods via multus.

- **Fields**:
  - `name`: Logical name for the network (e.g., `storage-net`).
  - `vlan_id`: VLAN identifier on the physical network.
  - `interface`: Host interface on which the VLAN is available.
  - `cidr`: IP range assigned to this network.
  - `gateway`: Optional default gateway.

- **Relationships**:
  - Many-to-1 with `NetworkConfig`.

### 5. AddonConfig

Enables and configures cluster add-ons.

- **Fields**:
  - `kube_vip`: `KubeVipConfig`.
  - `cert_manager`: `CertManagerConfig`.
  - `rancher`: `RancherConfig`.
  - `rancher_monitoring`: `RancherMonitoringConfig`.
  - `traefik`: `TraefikConfig`.
  - `synology_csi`: `SynologyCsiConfig` (optional).

### 6. KubeVipConfig

Configuration for kube-vip control-plane and service endpoint behavior.

- **Fields**:
  - `enabled`: Boolean.
  - `deployment_mode`: Enum: `daemonset`.
  - `control_plane_vip`: IP/FQDN used for API-server endpoint.
  - `service_lb_cidr_or_range`: Address range used for `LoadBalancer` Services.
  - `interface`: Host network interface kube-vip should bind.
  - `arp_enabled`: Boolean for ARP advertisement mode.

### 7. CertManagerConfig

Configuration for cert-manager and its issuers.

- **Fields**:
  - `enabled`: Boolean.
  - `email`: Contact email for Let's Encrypt.
  - `dns_provider`: Enum/string key (e.g., `cloudflare`, `route53`).
  - `dns_provider_credentials`: Provider-specific credential map.
  - `staging_issuer_name`: Name of the staging ClusterIssuer.
  - `production_issuer_name`: Name of the production ClusterIssuer.

### 8. RancherConfig

Configuration for Rancher deployment.

- **Fields**:
  - `enabled`: Boolean.
  - `hostname`: FQDN for Rancher UI.
  - `ingress_class`: Ingress class to use (e.g., Traefik).
  - `tls_source`: Source of TLS certs (e.g., cert-manager issuer).

### 9. RancherMonitoringConfig

Configuration for rancher-monitoring.

- **Fields**:
  - `enabled`: Boolean.
  - `retention`: Metric retention period (high-level).
  - `scrape_targets_overrides`: Optional overrides for scraping.

### 10. TraefikConfig

Configuration for Traefik ingress controller.

- **Fields**:
  - `enabled`: Boolean.
  - `service_type`: Service type (e.g., `LoadBalancer` or `NodePort` depending on kube-vip usage).
  - `entrypoints`: High-level list of entrypoints/ports.

### 11. SynologyCsiConfig

Optional configuration for Synology CSI integration.

- **Fields**:
  - `enabled`: Boolean (implied by presence of Synology variables).
  - `endpoint`: Synology NAS endpoint.
  - `username`: Username for storage authentication (secret-managed).
  - `password`: Password or token (secret-managed).
  - `default_storage_class`: Name of the default StorageClass created.
  - `additional_storage_classes`: List of additional StorageClass definitions.

## State Transitions

### Node Lifecycle

- `absent` → `present` → `configured` → `ready` for scheduling.
- Removal path: `ready` → `draining` → `removed` (cluster membership removed, services stopped).

### Cluster Lifecycle

- `not_provisioned` → `provisioned` → `configured` → `operational`.
- Upgrade path: `operational` → `upgrading` (minor/patch) → `operational`.

## Validation Rules

- `ha_mode = embedded-etcd-ha` requires an odd number of control-plane nodes (recommended 3) in the inventory.
- `control_plane_vip` must resolve or be reachable from all nodes defined in the cluster.
- When `kube_vip.enabled = true`, `deployment_mode` must be `daemonset` for this baseline.
- When `multus_enabled = true`, `multus_plugin_type` must be `thick` and installation must use the official Helm chart.
- When `cert_manager.enabled = true`, both staging and production issuers must be fully specified (provider, credentials, email).
- When `synology_csi.enabled = true`, endpoint and credentials must be present, and at least one StorageClass must be defined.
- multus VLAN definitions must reference valid interfaces and non-overlapping CIDRs relative to the base cluster networks.

## k3s Deployment Compatibility Constraints

All add-on deployments managed by the playbooks MUST adhere to these constraints:

1. **No symlinks on nodes**: Roles and tasks must not create symlinks on target nodes for any deployment artifact.
2. **No file copies to nodes for runtime workloads**: Add-ons (kube-vip, cert-manager, multus, Rancher, rancher-monitoring, Traefik, Synology CSI) must be deployed as in-cluster resources via the Kubernetes API (Helm charts, manifests applied via `kubernetes.core` modules), not by copying files to the node filesystem.
3. **No modification of default k3s paths**: Roles must not remove, rename, or alter paths managed by k3s (e.g., `/var/lib/rancher/k3s`, `/etc/rancher/k3s`, the k3s data directory structure).

These constraints ensure that k3s upgrade paths remain intact and the k3s service manager retains full control of its runtime environment.
