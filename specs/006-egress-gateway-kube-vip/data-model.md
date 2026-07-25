# Data Model: Egress Gateway and Kube-VIP Enhancements

**Feature**: `006-egress-gateway-kube-vip`
**Date**: 2026-07-25
**Sources**: spec.md, research.md, direct observation of ansible/roles/kube-vip/

---

## Entities

### 1. EgressGatewayVIP

A dedicated Kubernetes LoadBalancer Service that holds the cluster's stable outbound source IP address. Managed by kube-vip.

| Field | Source | Type | Notes |
|-------|--------|------|-------|
| `kube_vip_egress_enabled` | `defaults/main.yml` | bool | Master enable flag. Default: `false`. |
| `kube_vip_egress_ip` | `defaults/main.yml` | string | IPv4 address for the egress VIP. Independent of `kube_vip_lb_ip_range`. No default — must be set by operator when enabled. |
| `kube_vip_egress_hostname` | `defaults/main.yml` | string | Hostname associated with egress VIP (for documentation; DNS out of scope). Default: `""`. |
| `kube_vip_egress_namespace` | `defaults/main.yml` | string | Namespace for the egress Service. Default: `kube-system`. |
| `kube_vip_egress_pod_cidr_override` | `defaults/main.yml` | string | Overrides auto-detected pod CIDR for egress rules (`egress_podcidr`). Default: `""` (auto-detect). |
| `kube_vip_egress_svc_cidr_override` | `defaults/main.yml` | string | Overrides auto-detected service CIDR for egress rules (`egress_servicecidr`). Default: `""` (auto-detect). |

**Service manifest fields** (managed by kube-vip role template):
- `type: LoadBalancer`
- `loadBalancerIP: {{ kube_vip_egress_ip }}`
- `externalTrafficPolicy: Local`
- `annotations.kube-vip.io/egress-internal: "true"`

**State transitions**:
1. `kube_vip_egress_enabled: false` (default) → no egress Service created, no Cilium policy applied
2. `kube_vip_egress_enabled: true`, playbook runs → egress Service created + CiliumEgressGatewayPolicy applied
3. Active node fails → kube-vip lease expires (≤15s default) → VIP migrates to new leader node

**Validation rules**:
- `kube_vip_egress_ip` MUST be non-empty when `kube_vip_egress_enabled: true`
- `kube_vip_egress_ip` MUST NOT overlap with `kube_vip_lb_ip_range`

---

### 2. ServiceLeaderElectionLease

A `coordination.k8s.io/v1 Lease` object per LoadBalancer Service. kube-vip instances compete for each lease; winner owns the service VIP on that node.

| Field | Source | Type | Notes |
|-------|--------|------|-------|
| `kube_vip_svc_election_enabled` | `defaults/main.yml` | bool | Enable per-service election. Auto-set `true` when `kube_vip_egress_enabled: true`. Default: `false`. |
| `vip_leaseduration` | DaemonSet env | int | Seconds. Default: `15`. |
| `vip_renewdeadline` | DaemonSet env | int | Seconds. Default: `10`. |
| `vip_retryperiod` | DaemonSet env | int | Seconds. Default: `2`. |

**DaemonSet env var** (confirmed: https://kube-vip.io/docs/usage/kubernetes-services/):
```yaml
- name: svc_election
  value: "true"
```

**State transitions**:
1. Service created → all kube-vip pods participate in lease election
2. Leader elected → VIP bound to leader node
3. Leader unavailable → lease expires → new election → new leader binds VIP

---

### 3. KubeVipDHCPConfig

Configuration enabling DHCP-based IP assignment for LoadBalancer services.

| Field | Source | Type | Notes |
|-------|--------|------|-------|
| `kube_vip_lb_dhcp_enabled` | `defaults/main.yml` | bool | Enable DHCP mode. Default: `false`. Mutually exclusive with non-empty `kube_vip_lb_ip_range`. |
| `kube_vip_lb_ip_range` | `defaults/main.yml` (existing) | string | Static IP range. Default: `"192.168.1.200-192.168.1.220"`. Must be `""` when DHCP enabled. |

**Mechanics** (confirmed: kube-vip docs v0.2.1+):
- Operator creates Service with `spec.loadBalancerIP: 0.0.0.0`
- kube-vip creates `macvlan` interface on host, requests IP via DHCP
- Assigned IP set as Service ExternalIP

**Validation rules**:
- `kube_vip_lb_dhcp_enabled: true` AND `kube_vip_lb_ip_range` non-empty → playbook MUST fail with message: `"kube_vip_lb_dhcp_enabled and kube_vip_lb_ip_range are mutually exclusive"`

**Networking prerequisites** (operator responsibility, documented in README):
- External DHCP server on cluster node network
- DHCP server must accept macvlan client MACs
- `macvlan` kernel module loaded on nodes (standard Linux)

---

### 4. KubeVipConsolidatedClusterRole

Single ClusterRole granting all permissions required by both kube-vip DaemonSet and kube-vip-cloud-controller.

| Field | Value |
|-------|-------|
| Name | `kube-vip` |
| Namespace | cluster-scoped |

**Rules** (union of current kube-vip + kube-vip-cloud-controller ClusterRoles, observed from templates):

| API Group | Resources | Verbs |
|-----------|-----------|-------|
| `""` | `services`, `services/status` | `list`, `get`, `watch`, `update`, `patch` |
| `""` | `nodes`, `endpoints` | `list`, `get`, `watch`, `update`, `patch` |
| `""` | `configmaps` | `get`, `list`, `watch` |
| `""` | `events` | `create`, `patch` |
| `discovery.k8s.io` | `endpointslices` | `list`, `get`, `watch` |
| `coordination.k8s.io` | `leases` | `list`, `get`, `watch`, `update`, `create` |

**Note**: `pods` verb requirements for egress v2 active-endpoint tracking are **assumed**; must be verified against kube-vip v1.1.2 at implementation. Add `pods: list, get, watch` to ClusterRole if needed.

**ClusterRoleBindings** (two, each pointing to `kube-vip` ClusterRole):
1. `kube-vip` → ServiceAccount `kube-vip` in `kube-system`
2. `kube-vip-cloud-controller` → ServiceAccount `kube-vip-cloud-controller` in `kube-system`

---

### 5. CiliumInstallation

Cilium CNI installed and managed by new Ansible role `ansible/roles/cilium`.

| Field | Source | Type | Notes |
|-------|--------|------|-------|
| `cilium_enabled` | `defaults/main.yml` (new role) | bool | Enable Cilium CNI. Default: `false`. |
| `cilium_version` | `defaults/main.yml` (new role) | string | Pinned Cilium version (e.g. `v1.16.x`). No default — must be set. |
| `cilium_namespace` | `defaults/main.yml` (new role) | string | Install namespace. Default: `kube-system`. |
| `cilium_helm_repo` | `defaults/main.yml` (new role) | string | Helm chart repo URL. Default: `https://helm.cilium.io/`. |

**k3s flags required** (assumption, must verify vs k3s docs):
```
--flannel-backend=none
--disable-network-policy
```

Applied to k3s-server ExtraArgs via `ansible/roles/k3s-server` or k3s-common role.

**State transitions**:
1. `cilium_enabled: false` → Flannel is CNI (k3s default)
2. `cilium_enabled: true` → k3s server starts with Flannel disabled; Cilium DaemonSet installed post-join
3. CNI switch on existing cluster → requires k3s-server restart on all control-plane nodes (rolling, coordinated)

---

### 6. CiliumEgressGatewayPolicy

A `CiliumEgressGatewayPolicy` custom resource that steers matching pod egress traffic through the kube-vip egress VIP node.

| Field | Source | Type | Notes |
|-------|--------|------|-------|
| `kube_vip_egress_policy_name` | `defaults/main.yml` | string | Name of the CiliumEgressGatewayPolicy CR. Default: `egress-gateway-policy`. |
| `kube_vip_egress_pod_selector` | `defaults/main.yml` | dict | Kubernetes label selector matching pods whose egress is gated. Default: `{}` (match all — operator should restrict). |
| `kube_vip_egress_namespace_selector` | `defaults/main.yml` | dict | Namespace selector for the policy. Default: `{}`. |
| `kube_vip_egress_gateway_node_selector` | `defaults/main.yml` | dict | Node selector for the gateway node. Must match the node holding the kube-vip egress VIP. |
| `kube_vip_egress_gateway_interface` | `defaults/main.yml` | string | Network interface for egress on gateway node. Default: `{{ kube_vip_interface }}`. |

**Validation rules**:
- `kube_vip_egress_gateway_node_selector` MUST be non-empty when `kube_vip_egress_enabled: true`

---

## Variable Dependency Graph

```
kube_vip_egress_enabled: true
├── auto-sets kube_vip_svc_election_enabled: true
├── requires kube_vip_egress_ip (non-empty)
├── requires kube_vip_egress_gateway_node_selector (non-empty)
├── requires cilium_enabled: true (playbook asserts)
└── creates:
    ├── egress LoadBalancer Service (kube-vip role)
    └── CiliumEgressGatewayPolicy (kube-vip role or cilium role)

kube_vip_lb_dhcp_enabled: true
└── requires kube_vip_lb_ip_range: "" (mutual exclusion enforced)

kube_vip_svc_election_enabled: true
└── sets svc_election: "true" in kube-vip DaemonSet env
```
