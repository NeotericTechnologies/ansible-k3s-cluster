# Ansible Variable Contracts: Egress Gateway and Kube-VIP Enhancements

**Feature**: `006-egress-gateway-kube-vip`
**Date**: 2026-07-25
**Contract type**: Ansible role variable interface (input variables and their effects)

This document defines the public variable interface for the modified/new Ansible roles. Operators configure the feature by setting these variables in group_vars or host_vars.

---

## Role: `kube-vip` — New Variables

### Egress Gateway

```yaml
# Enable the load-balanced egress gateway (combines kube-vip egress + Cilium EgressGatewayPolicy)
kube_vip_egress_enabled: false  # bool — master enable flag

# IP address for the egress VIP (independent of kube_vip_lb_ip_range)
# REQUIRED when kube_vip_egress_enabled: true
kube_vip_egress_ip: ""  # e.g. "192.168.1.245"

# Hostname associated with egress VIP (DNS registration is out of scope)
kube_vip_egress_hostname: ""  # e.g. "egress.cluster.local"

# Namespace for the egress LoadBalancer Service
kube_vip_egress_namespace: "kube-system"

# Override auto-detected pod CIDR for kube-vip egress rules (leave empty for auto-detect)
kube_vip_egress_pod_cidr_override: ""

# Override auto-detected service CIDR for kube-vip egress rules (leave empty for auto-detect)
kube_vip_egress_svc_cidr_override: ""

# Name of the CiliumEgressGatewayPolicy CR created by this role
kube_vip_egress_policy_name: "egress-gateway-policy"

# Label selector for pods whose egress traffic is gated (Kubernetes matchLabels format)
# Empty dict ({}) matches all pods — operators SHOULD restrict this in production
kube_vip_egress_pod_selector: {}

# Namespace selector for the CiliumEgressGatewayPolicy
kube_vip_egress_namespace_selector: {}

# Node selector for the POOL of eligible egress gateway nodes.
# kube-vip svc_election elects the active VIP holder within this pool.
# Cilium egress gateway active-backup detects which node has egressIP bound (via ARP)
# and routes there automatically — no manual sync required on failover.
# Default targets all control-plane nodes; narrow only if a dedicated gateway node pool is used.
kube_vip_egress_gateway_node_selector:
  node-role.kubernetes.io/control-plane: "true"

# Network interface for egress on the gateway node
kube_vip_egress_gateway_interface: "{{ kube_vip_interface }}"
```

**Side effects when `kube_vip_egress_enabled: true`**:
- `kube_vip_svc_election_enabled` is forced `true` (required for egress `externalTrafficPolicy: Local`)
- Cilium presence is asserted; playbook fails if Cilium is not the active CNI

---

### Service Election

```yaml
# Enable per-service leader election (each LoadBalancer Service elects its own leader node)
# Automatically set true when kube_vip_egress_enabled: true
kube_vip_svc_election_enabled: false  # bool
```

**Effect**: Sets `svc_election: "true"` in kube-vip DaemonSet env. Requires `coordination.k8s.io/leases` RBAC (already in consolidated ClusterRole).

---

### DHCP for LoadBalancer Services

```yaml
# Enable DHCP-based IP assignment for LoadBalancer services
# MUTUALLY EXCLUSIVE with non-empty kube_vip_lb_ip_range
kube_vip_lb_dhcp_enabled: false  # bool
```

**Mutual exclusion enforcement**: Playbook fails with error `"kube_vip_lb_dhcp_enabled and kube_vip_lb_ip_range are mutually exclusive"` if both `kube_vip_lb_dhcp_enabled: true` AND `kube_vip_lb_ip_range` is non-empty.

**Operator action**: With DHCP enabled, create Services with `spec.loadBalancerIP: 0.0.0.0`. kube-vip creates `macvlan` interface and obtains IP from network DHCP server.

**Prerequisites**:
- External DHCP server reachable on the cluster node network
- DHCP server accepts `macvlan` client MAC addresses
- `macvlan` kernel module available on cluster nodes (standard Linux kernel)

---

## Role: `cilium` — New Role Variables

```yaml
# Enable Cilium as the cluster CNI (replaces Flannel)
cilium_enabled: false  # bool

# Cilium version — MUST be pinned, no "latest"
# Validate against https://github.com/cilium/cilium/releases before setting
cilium_version: ""  # e.g. "v1.16.6"

# Namespace for Cilium installation
cilium_namespace: "kube-system"

# Cilium Helm chart repository
cilium_helm_repo: "https://helm.cilium.io/"

# Helm release name
cilium_helm_release_name: "cilium"

# Additional Helm values to pass to the Cilium chart (merged with role defaults)
cilium_helm_values: {}
```

**Required k3s server flags when `cilium_enabled: true`** (applied to k3s-server role):
```
--flannel-backend=none
--disable-network-policy
```

---

## Mutual Exclusion and Dependency Matrix

| Condition | Result |
|-----------|--------|
| `kube_vip_lb_dhcp_enabled: true` AND `kube_vip_lb_ip_range` non-empty | Playbook fails with descriptive error |
| `kube_vip_egress_enabled: true` AND `cilium_enabled: false` | Playbook fails: "Cilium CNI required for egress gateway" |
| `kube_vip_egress_enabled: true` AND `kube_vip_egress_ip` empty | Playbook fails: "kube_vip_egress_ip required when kube_vip_egress_enabled" |
| `kube_vip_egress_enabled: true` AND `kube_vip_egress_gateway_node_selector` empty | Playbook fails: "kube_vip_egress_gateway_node_selector must not be empty — specify at least one label to select the gateway node pool" |
| `kube_vip_egress_enabled: true` | `kube_vip_svc_election_enabled` forced `true` |

---

## RBAC Contract

**Single ClusterRole `kube-vip`** (replaces separate `kube-vip` and `kube-vip-cloud-controller` ClusterRoles):

```yaml
rules:
  - apiGroups: [""]
    resources: ["services", "services/status"]
    verbs: ["list", "get", "watch", "update", "patch"]
  - apiGroups: [""]
    resources: ["nodes", "endpoints"]
    verbs: ["list", "get", "watch", "update", "patch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]
  - apiGroups: ["discovery.k8s.io"]
    resources: ["endpointslices"]
    verbs: ["list", "get", "watch"]
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["list", "get", "watch", "update", "create"]
  # pods: add "list","get","watch" if kube-vip egress v2 requires pod tracking
  # (verify against kube-vip v1.1.2 source at implementation time)
```

**Two ClusterRoleBindings**, each referencing `kube-vip` ClusterRole:
1. `kube-vip` → `kube-system/kube-vip`
2. `kube-vip-cloud-controller` → `kube-system/kube-vip-cloud-controller`
