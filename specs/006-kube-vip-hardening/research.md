# Research: Kube-VIP Hardening

**Feature**: 006-kube-vip-hardening
**Date**: 2026-07-12

## R-001: Egress scope model

- Decision: Use cluster-wide managed egress as the default behavior, with explicit per-workload opt-out.
- Rationale: The clarified operator expectation is default managed egress for predictable firewall/allow-list management, while preserving a controlled escape hatch for exceptional workloads.
- Alternatives considered:
  - Opt-in label selector only: rejected due to operational drift risk and missed workload onboarding.
  - Namespace-only scoping: rejected because it is coarse and can force unnecessary exceptions.

## R-002: Invalid opt-out safety behavior

- Decision: Fail safe by ignoring invalid/conflicting opt-out configuration, keeping managed egress active, and emitting warning diagnostics.
- Rationale: This prevents accidental policy bypass and aligns with security-first networking behavior.
- Alternatives considered:
  - Fail open (bypass egress): rejected as unsafe for firewall policy.
  - Hard deny all traffic for invalid config: rejected due to avoidable availability impact.

## R-003: Service election behavior under quorum loss

- Decision: Hold existing healthy leadership assignments, block new leadership changes, and report degraded state until quorum is restored.
- Rationale: This avoids split-brain style churn while preserving availability for already healthy leader paths.
- Alternatives considered:
  - Continue best-effort leader reassignment without quorum: rejected for safety risk.
  - Release all leadership immediately: rejected due to avoidable service outage.

## R-004: DHCP allocation failure handling

- Decision: Keep service in pending allocation state and retry automatically until DHCP is reachable/available.
- Rationale: DHCP unavailability is often transient; automatic reconciliation prevents manual re-apply loops.
- Alternatives considered:
  - Immediate hard failure with manual retry: rejected due to operator overhead.
  - Silent static fallback pool: rejected due to implicit behavior changes and address-management drift.

## R-005: RBAC hardening strategy

- Decision: Maintain a consolidated least-privilege RBAC baseline for kube-vip and kube-vip-cloud-provider, and reconcile it on every deploy/upgrade.
- Rationale: A baseline contract reduces drift and directly addresses prior RBAC regression history while keeping permissions auditable.
- Alternatives considered:
  - Ad hoc permission patches: rejected due to recurring break/fix cycle.
  - Broad admin privileges: rejected for violating least-privilege security expectations.

## R-006: Operator-visible status signaling

- Decision: Standardize status outputs for egress mode, leadership health (normal/degraded), and DHCP allocation state via playbook logs and Kubernetes resource status checks.
- Rationale: This provides deterministic observability and aligns with requirement FR-011.
- Alternatives considered:
  - Log-only without structured states: rejected as too ambiguous for operations.
  - External monitoring dependency for basic state visibility: rejected as unnecessary coupling for baseline feature behavior.

## R-007: Automated validation strategy (feasible coverage)

- Decision: Add feasible automated validation scenarios for managed egress behavior, service election behavior, DHCP lease acquisition/renewal lifecycle, and RBAC binding correctness, executed through repository-native Ansible validation paths.
- Rationale: The updated spec requires automated validation where feasible and success criteria now include automated coverage across fresh-deploy and upgrade-path scenarios.
- Alternatives considered:
  - Manual validation only: rejected because it does not satisfy FR-018 and SC-007.
  - Full end-to-end simulation for every network failure mode: rejected as disproportionate and brittle for baseline automation; keep complex fault injection in documented manual validation paths.
