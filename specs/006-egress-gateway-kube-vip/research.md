# Research: Egress Gateway and Kube-VIP Enhancements

**Feature**: `006-egress-gateway-kube-vip`
**Date**: 2026-07-25
**Sources**: kube-vip.io docs, cilium.io docs, repository direct observation

---

## Decision 1: kube-vip Egress Mechanism

**Decision**: kube-vip acts as **pure VIP manager** for the egress IP — it binds the stable IP to the active gateway node's interface via `svc_election`. Cilium `CiliumEgressGatewayPolicy` performs all pod traffic routing and SNAT using that VIP as `egressIP`. kube-vip's own egress annotation (`kube-vip.io/egress-internal`) is NOT used.

**Rationale**:
- kube-vip egress v2 (`kube-vip.io/egress-internal: "true"`) and `CiliumEgressGatewayPolicy` both perform SNAT independently. Using both creates double-SNAT on the gateway node.
- kube-vip egress requires `externalTrafficPolicy: Local` (pod must be on same node as VIP), which directly conflicts with Cilium's role of routing pod traffic TO the gateway node from any other node.
- Correct separation of concerns: Cilium owns egress routing + SNAT; kube-vip owns HA VIP lifecycle.

**Mechanics**:
- kube-vip creates a standard LoadBalancer Service with `loadBalancerIP: {{ kube_vip_egress_ip }}` — no egress annotations, no `externalTrafficPolicy: Local`
- kube-vip `svc_election` binds the VIP to the current leader node's interface
- `CiliumEgressGatewayPolicy` specifies `egressGateway.egressIP: {{ kube_vip_egress_ip }}` and `egressGateway.nodeSelector` matching the control-plane node pool
- Cilium detects which node has the VIP bound (via ARP/neighbor table), routes matching pod egress there, and SNATs source IP to the VIP
- On kube-vip VIP failover (node failure), kube-vip migrates VIP via ARP; Cilium detects the new binding and reroutes automatically — no external coordination required

**HA design**:
- `CiliumEgressGatewayPolicy.egressGateway.nodeSelector` targets the **pool** of eligible gateway nodes (e.g., `node-role.kubernetes.io/control-plane: "true"`), not a single hostname
- kube-vip `svc_election` elects the active VIP holder within that pool; VIP migrates on node failure via ARP within the configured lease duration (≤15s default)
- Pinning `nodeSelector` to a single hostname creates SPOF — operators MUST use a role/group label

**Alternatives considered**:
- kube-vip egress annotation + Cilium as CNI only: rejected — double-SNAT conflict; `externalTrafficPolicy: Local` incompatible with Cilium routing
- Pure Cilium egress with static `egressIP` (no kube-vip): rejected — no HA for the egress IP; VIP would be lost on gateway node failure
- kube-vip egress annotation alone (no Cilium EgressGatewayPolicy): rejected — requires all egress pods to follow the VIP node; no cluster-wide pod selection

---

## Decision 2: Cilium as CNI

**Decision**: New `ansible/roles/cilium` role installs Cilium, replacing Flannel. k3s must start with `--flannel-backend=none` and `--disable-network-policy`.

**Rationale**:
- `docs/ansible-k3s-baseline.md` line 170 explicitly states "No Calico/Cilium integration" — confirms not present (observed directly)
- Cilium Egress Gateway (CiliumEgressGatewayPolicy) provides pod-level traffic steering to a specific gateway node with a stable egress IP
- Cilium installation on k3s requires Flannel disabled at k3s server startup; this is a k3s-specific constraint (§III)
- `CiliumEgressGatewayPolicy` uses `podSelector` + `namespaceSelector` to match pods and `egressGateway` to select the gateway node and egress IP

**Version**: `cilium_version` variable, MUST be pinned. Recommended baseline: `v1.16.x` (LTS series, eBPF-based, confirmed stable for on-prem k3s deployments per https://cilium.io/use-cases/egress-gateway/). Exact patch version MUST be verified against https://github.com/cilium/cilium/releases before implementation. **This is an assumption — must be confirmed at task execution time.**

**Alternatives considered**:
- Calico: rejected — spec explicitly chose Cilium
- Flannel + host-routing egress: rejected — no stable egress IP mechanism without Cilium policy
- Cilium pre-installed (not managed by Ansible): rejected — spec FR-003c requires Ansible role

---

## Decision 3: Service Election (svc_election)

**Decision**: `svc_election: "true"` env var in kube-vip DaemonSet, auto-enabled when `kube_vip_egress_enabled: true`.

**Rationale**: kube-vip docs confirm service election (per-service leader election) available since v0.5.0 (observed: https://kube-vip.io/docs/usage/kubernetes-services/#load-balancing-load-balancers-when-using-arp-mode-yes-you-read-that-correctly-kube-vip-v050). Current v1.1.2 supports it. Required for egress v2 (`externalTrafficPolicy: Local` needs svc_election). Spec FR-004/FR-005 align.

**Mechanics**: Each LoadBalancer service holds its own Lease in `coordination.k8s.io`. All kube-vip instances participate; leader wins the service VIP. Multiple services can spread across different nodes.

**Alternatives considered**:
- Global leader election (existing `vip_leaderelection`): rejected — all services pinned to one node, creates bottleneck and breaks egress `Local` policy

---

## Decision 4: DHCP for LoadBalancer Services

**Decision**: DHCP mode triggered by `loadBalancerIP: 0.0.0.0` (or annotation `kube-vip.io/loadbalancerIPs: "0.0.0.0"`) on a Service. kube-vip creates a `macvlan` interface and requests IP from network DHCP server.

**Rationale**: Confirmed in kube-vip docs (https://kube-vip.io/docs/usage/kubernetes-services/#using-dhcp-for-load-balancers-experimental-kube-vip-v021). Available since v0.2.1; current v1.1.2 includes it. Marked "experimental" in upstream docs.

**Ansible approach**: `kube_vip_lb_dhcp_enabled: true` configures the kube-vip ConfigMap to omit static IP range; operator must set `loadBalancerIP: 0.0.0.0` per-service. Mutually exclusive with `kube_vip_lb_ip_range` (non-empty) — playbook fails with error if both set (FR-007).

**Prerequisites** (operator must provide):
- External DHCP server reachable on cluster node network
- DHCP server must support macvlan client requests (standard DHCP, not IPAM-specific)
- `macvlan` kernel module available on all nodes (standard Linux)

**Alternatives considered**:
- Multus DHCP: independent feature (already present), not related to kube-vip LB DHCP
- Static IP range always required: rejected — spec explicitly requires DHCP option

---

## Decision 5: RBAC Consolidation

**Decision**: Merge kube-vip and kube-vip-cloud-controller ClusterRoles into one shared `kube-vip` ClusterRole. Both service accounts bind to it via separate ClusterRoleBindings.

**Rationale**: Plan prompt explicitly states "The ClusterRole for both service accounts should be merged and updated as needed." Combined ClusterRole union of permissions from both current templates:

Current kube-vip ClusterRole rules (observed: `kube-vip-daemonset.yaml.j2`):
- `""`: services, services/status, nodes, endpoints → list, get, watch, update
- `discovery.k8s.io`: endpointslices → list, get, watch
- `coordination.k8s.io`: leases → list, get, watch, update, create

Current kube-vip-cloud-controller ClusterRole rules (observed: `kube-vip-cloud-controller.yaml.j2`):
- `""`: services, services/status, endpoints, nodes → get, list, watch, update, patch
- `""`: configmaps → get, list, watch
- `discovery.k8s.io`: endpointslices → list, get, watch
- `""`: events → create, patch
- `coordination.k8s.io`: leases → list, get, watch, update, create

**Merged ClusterRole** must include union of all verbs per resource:
- `""`: services, services/status → list, get, watch, update, patch
- `""`: nodes, endpoints → list, get, watch, update, patch
- `""`: configmaps → get, list, watch
- `""`: events → create, patch
- `discovery.k8s.io`: endpointslices → list, get, watch
- `coordination.k8s.io`: leases → list, get, watch, update, create

**Additional verbs for egress** (from kube-vip egress v2 requirements): `services` needs `patch` for annotation updates; `pods` may be needed for active-endpoint tracking — **assumption, must be verified against kube-vip v1.1.2 source at implementation time**.

**Spec note**: Spec FR-008/FR-009 stated separate ClusterRoles. Plan prompt (user intent) overrides — single shared ClusterRole with two ClusterRoleBindings is the chosen design.

**Alternatives considered**:
- Keep separate ClusterRoles per spec: rejected by plan prompt direction
- One ClusterRoleBinding with multiple subjects: rejected — ServiceAccounts are in same namespace, functionally equivalent but less explicit

---

## Decision 6: k3s Configuration for Cilium

**Decision**: When `cilium_enabled: true`, k3s server ExecStart must include `--flannel-backend=none --disable-network-policy`. k3s agents require no additional flags for Cilium.

**Rationale**: k3s-specific constraint (§III). Flannel is k3s's default CNI; disabling it at startup is the only supported method (confirmed by Cilium + k3s documentation patterns — assumption based on standard practice, must be validated against https://docs.k3s.io at task execution time).

**Impact**: This is a cluster-wide startup flag change. Applying to an existing Flannel-based cluster requires coordinated rolling restart of k3s-server service. Documented in quickstart.md.

---

## Resolved Unknowns

| Unknown | Resolution |
|---------|------------|
| kube-vip v1.1.2 supports egress? | Confirmed: egress v2 available v1.0+; v1.1.2 qualifies |
| kube-vip v1.1.2 supports svc_election? | Confirmed: available v0.5.0+; v1.1.2 qualifies |
| kube-vip v1.1.2 supports DHCP? | Confirmed: available v0.2.1+; v1.1.2 qualifies |
| Cilium version for k3s | Assumption: v1.16.x LTS; must pin exact patch at implementation |
| CiliumEgressGatewayPolicy + kube-vip VIP interaction | Complementary: Cilium routes to gateway node; kube-vip rewrites source IP to VIP |
| k3s flags for Cilium | Assumption: --flannel-backend=none --disable-network-policy; must verify vs k3s docs |
