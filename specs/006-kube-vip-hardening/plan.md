# Implementation Plan: Kube-VIP Hardening

**Branch**: `006-kube-vip-hardening` | **Date**: 2026-07-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-kube-vip-hardening/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Enhance kube-vip operations for production-grade HA networking by wiring documented kube-vip runtime controls into the existing DaemonSet and validation flows. The evidence-based implementation uses daemonset environment variables for service election, egress CIDR support, and DHCP mode, uses Kubernetes Service annotations and request fields for egress and DHCP behavior, and enforces a consolidated least-privilege RBAC baseline for kube-vip and kube-vip-cloud-provider. Automated validation focuses on documented runtime knobs and Service API patterns.

## Technical Context

**Language/Version**: Ansible 2.15+ (YAML playbooks, Jinja2 templates), Kubernetes manifests

**Primary Dependencies**: k3s, kube-vip, kube-vip-cloud-provider, kubectl, Helm 3

**Storage**: N/A (configuration/state managed via Kubernetes API resources)

**Testing**: `ansible-playbook --check` via `ansible/playbooks/site.yml`, repository smoke/integration scenarios in `tests/ansible/smoke/`, automated validation where feasible for egress/election/DHCP/RBAC, plus runtime verification via `kubectl` status checks

**Target Platform**: Debian/Ubuntu-like Linux nodes (systemd, x86_64/arm64) running k3s

**Project Type**: Infrastructure-as-code Ansible repository for k3s cluster lifecycle

**Performance Goals**: Automatic leader failover within 30 seconds for >=95% events; DHCP assignment within 60 seconds for >=95% of new services; no-op re-run remains idempotent

**Constraints**: Preserve existing lifecycle entrypoints with `ansible/playbooks/site.yml` as preferred path; configure only documented kube-vip runtime surfaces (daemonset env, Service annotations, Service request fields, cloud-provider pool ConfigMap); no default broad RBAC privileges; automated validation must cover both fresh-deploy and upgrade-path scenarios where feasible

**Scale/Scope**: Single-node through small HA clusters (1-5 servers, 1-20 agents) with kube-vip service election enabled, service-driven egress support, DHCP-capable LoadBalancer services, and enforced RBAC reconciliation

## Evidence-Based Adjustment

The implementation was audited against upstream kube-vip documentation during implementation. That audit changed the design in these ways:

- Service election is configured through documented daemonset env (`svc_election`) rather than a standalone ConfigMap.
- Egress support is configured through documented daemonset env plus per-Service annotations and `externalTrafficPolicy: Local`, not through a role-owned ConfigMap.
- DHCP support is requested through documented Service fields and annotations such as `loadBalancerIP: 0.0.0.0`, with daemonset `dhcp_mode` controlling address family behavior.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Minimal, Focused Playbooks | PASS | Changes are constrained to kube-vip-related role/playbook paths and documented contracts |
| II. Idempotent Cluster Provisioning | PASS | Design requires re-runnable RBAC reconciliation, deterministic fallback behavior, and repeatable automated validation checks |
| III. k3s-Specific Constraints | PASS | Feature is k3s-native and uses existing k3s cluster lifecycle semantics |
| IV. Clear Inventory and Node Roles | PASS | Behavior remains inventory-driven; no hard-coded host decisions introduced |
| V. Security, Networking, and Upgrades | PASS | Least-privilege RBAC baseline, explicit networking behavior, upgrade-safe reconciliation, and automated validation gates are required |

**Post-Phase 1 Re-check**: PASS. Research and design artifacts preserve repository role boundaries, keep security defaults explicit, include feasible automated validation commitments, and avoid non-idempotent or destructive operations.

## Project Structure

### Documentation (this feature)

```text
specs/006-kube-vip-hardening/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── kube-vip-lifecycle-contracts.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
ansible/
├── group_vars/
│   └── all.yml                               # global defaults and feature flags
├── playbooks/
│   ├── cluster-core.yml                      # lifecycle entrypoint
│   ├── cluster-addons.yml                    # lifecycle entrypoint
│   ├── upgrade-k3s.yml                       # lifecycle entrypoint
│   ├── includes/
│   │   └── upgrade-kube-vip.yml              # kube-vip orchestration include
│   └── site.yml                              # top-level orchestrator
└── roles/
    └── kube-vip/
        ├── defaults/main.yml                 # kube-vip configurable variables
        ├── tasks/install.yml                 # install/upgrade/reconcile flow
        └── templates/                        # manifests (daemonsets, RBAC, config)

tests/
└── ansible/
    ├── smoke/                                # executable validation scenarios
    └── integration/                          # automated kube-vip hardening coverage (egress/election/DHCP/RBAC)

docs/
├── ansible-k3s-baseline.md                   # operator-facing behavior docs
└── ai-prompts/kube-vip-configuration.md      # feature input context
```

**Structure Decision**: Reuse the existing ansible lifecycle architecture and keep all implementation changes inside kube-vip role/playbook paths plus shared group variables. No new top-level project structure is introduced.

## Complexity Tracking

No constitution violations requiring justification.
