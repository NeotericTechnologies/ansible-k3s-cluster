# Implementation Plan: Egress Gateway and Kube-VIP Enhancements

**Branch**: `006-egress-gateway-kube-vip` | **Date**: 2026-07-25 | **Spec**: [spec.md](spec.md)

**Input**: [specs/006-egress-gateway-kube-vip/spec.md](spec.md)

## Summary

Add load-balanced egress gateway (kube-vip egress v2 + Cilium `CiliumEgressGatewayPolicy`), per-service leader election, DHCP-based LB IP assignment, and consolidated RBAC to the `kube-vip` Ansible role. Add new `cilium` Ansible role to replace Flannel as CNI. All features are variable-gated and default to disabled. Cilium is required when egress gateway is enabled.

## Technical Context

**Language/Version**: YAML (Ansible 2.14+), Jinja2 templates

**Primary Dependencies**:
- kube-vip v1.1.2 (pinned; confirmed supports egress v2, svc_election, DHCP — see [research.md](research.md))
- kube-vip-cloud-provider v0.0.12 (pinned; observed in `group_vars/all.yml`)
- Cilium (pinned via `cilium_version`; `v1.16.x` LTS recommended — assumption, verify at implementation)
- Helm (for Cilium install; assumed available on control node — verify at implementation)
- k3s v1.28.5+k3s1 (current; no version upgrade required)

**Storage**: Kubernetes Lease objects (`coordination.k8s.io`) for leader election; ConfigMap `kubevip` for IP range

**Testing**: `tests/ansible/smoke/` (observed); new test `tests/ansible/smoke/egress-gateway-test.yml`

**Target Platform**: k3s on Debian/Ubuntu-like, systemd-based Linux, x86_64/arm64

**Project Type**: Ansible roles + Kubernetes manifests

**Performance Goals**: Egress VIP failover ≤15s (lease duration); service election stabilization ≤10s

**Constraints**: k3s-specific flags only (§III NON-NEGOTIABLE); no "latest" versions; idempotent re-runs

**Scale/Scope**: Single-node and HA multi-node clusters; DaemonSet on control-plane nodes only

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **§I Minimal**: All capabilities role-scoped, variable-gated (`false` default). Core provisioning flow unchanged.
- [x] **§II Idempotent**: `kubernetes.core` module `state: present` for all K8s resources. Mutual exclusion guards. Second run = zero changes.
- [x] **§III k3s-Specific**: k3s version unchanged. k3s server flags used for Cilium. DaemonSet on control-plane only.
- [x] **§IV Inventory**: Behavior derived from inventory variables. No hardcoded hostnames or IPs in defaults.
- [x] **§V Security/Traceability**: Defaults `false`. RBAC declared in full, clean overwrite. `docs/ansible-k3s-baseline.md` + smoke test per FR-012/FR-013.
- [x] **Token Optimization**: Caveman active, `rtk` for CLI, diff-only changes.
- [x] **Content Generation**: All claims grounded in observation or cited external refs. Assumptions labeled.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output — resolved decisions on capabilities, Cilium version, RBAC design
├── data-model.md        # Phase 1 output — entities, variables, state transitions, dependency graph
├── quickstart.md        # Phase 1 output — 5 runnable validation scenarios
├── contracts/
│   └── ansible-variable-contracts.md  # Phase 1 output — public variable interface + RBAC contract
└── tasks.md             # Phase 2 output (/speckit.tasks command — NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
ansible/
├── group_vars/
│   └── all.yml                        # Add defaults for new feature flags (all false)
├── roles/
│   ├── kube-vip/
│   │   ├── defaults/main.yml          # New variables (egress, election, DHCP)
│   │   ├── tasks/
│   │   │   ├── main.yml               # Add validate.yml include + egress/election task conditions
│   │   │   ├── install.yml            # RBAC consolidation, egress Service, CiliumEgressGatewayPolicy
│   │   │   └── validate.yml           # New: pre-flight assertions (mutual exclusion, required vars)
│   │   ├── templates/
│   │   │   ├── kube-vip-daemonset.yaml.j2        # Add svc_election, egress env vars; consolidated RBAC
│   │   │   ├── kube-vip-cloud-controller.yaml.j2 # Remove ClusterRole; bind to kube-vip ClusterRole
│   │   │   ├── kube-vip-configmap.yaml.j2         # Conditional: omit range-global when DHCP enabled
│   │   │   ├── kube-vip-egress-service.yaml.j2    # New: egress LoadBalancer Service
│   │   │   └── kube-vip-egress-policy.yaml.j2     # New: CiliumEgressGatewayPolicy
│   │   └── README.md                  # Document all new variables + DHCP prerequisites
│   └── cilium/                        # New role
│       ├── defaults/main.yml          # cilium_enabled, cilium_version, cilium_namespace, etc.
│       ├── tasks/
│       │   ├── main.yml               # Entry point with guards
│       │   └── install.yml            # Helm install; wait for DaemonSet ready
│       └── README.md                  # k3s flag requirements; Flannel migration note
docs/
└── ansible-k3s-baseline.md            # Remove "No Calico/Cilium" statement; add Cilium CNI section (FR-012)
tests/
└── ansible/
    └── smoke/
        └── egress-gateway-test.yml    # New: verify pod egress exits through configured VIP (FR-013)
```

## Complexity Tracking

No constitution violations requiring justification.
