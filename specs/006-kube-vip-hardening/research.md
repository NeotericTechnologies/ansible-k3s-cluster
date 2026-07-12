# Research: Kube-VIP Hardening

**Feature**: 006-kube-vip-hardening
**Date**: 2026-07-12

## R-001: Egress scope model

- Decision: Use documented kube-vip egress prerequisites by default and treat eligible, non-opted-out Services as in scope for kube-vip egress handling.
- Rationale: Upstream kube-vip documents Service-driven egress behavior rather than a repository-defined cluster-wide workload selector model.
- Alternatives considered:
  - Namespace-only scoping: rejected because the documented surface is Service-specific annotations.

## R-002: Service election configuration model

- Decision: Configure documented per-Service election through `svc_election` and validate live failover behavior without inventing undeclared quorum policy controls.
- Rationale: Upstream kube-vip documents service election enablement through runtime configuration on the daemonset.

## R-003: DHCP request model

- Decision: Support documented DHCP request paths through `loadBalancerIP: 0.0.0.0`, `kube-vip.io/loadbalancerIPs`, optional hostname annotation, and daemonset `dhcp_mode`.
- Rationale: These are the DHCP-related runtime surfaces clearly documented by kube-vip.

## R-004: RBAC hardening strategy

- Decision: Maintain a consolidated least-privilege RBAC baseline for kube-vip and kube-vip-cloud-provider, and reconcile it on every deploy/upgrade.
- Rationale: A baseline contract reduces drift and directly addresses prior RBAC regression history while keeping permissions auditable.
- Alternatives considered:
  - Ad hoc permission patches: rejected due to recurring break/fix cycle.
  - Broad admin privileges: rejected for violating least-privilege security expectations.

## R-005: Operator-visible status signaling

- Decision: Standardize status outputs for egress prerequisite wiring, service-election runtime configuration, DHCP request/runtime configuration, and RBAC state via playbook logs and Kubernetes resource status checks.
- Rationale: This provides deterministic observability and aligns with requirement FR-011.
- Alternatives considered:
  - Log-only without structured states: rejected as too ambiguous for operations.
  - External monitoring dependency for basic state visibility: rejected as unnecessary coupling for baseline feature behavior.

## R-006: Automated validation strategy (feasible coverage)

- Decision: Add feasible automated validation scenarios for egress prerequisites, service election runtime configuration, DHCP request behavior, and RBAC binding correctness, executed through repository-native Ansible validation paths.
- Rationale: The updated spec requires automated validation where feasible and success criteria now include automated coverage across fresh-deploy and upgrade-path scenarios.
- Alternatives considered:
  - Manual validation only: rejected because it does not satisfy FR-018 and SC-007.
  - Full end-to-end simulation for every network failure mode: rejected as disproportionate and brittle for baseline automation; keep environment-specific runtime observations outside this repository-defined implementation surface.
