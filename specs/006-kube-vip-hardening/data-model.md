# Data Model: Kube-VIP Hardening

**Feature**: 006-kube-vip-hardening
**Date**: 2026-07-12

## Entities

### 1. ManagedEgressPolicy

Defines global egress behavior and workload exception rules.

- Fields:
  - enabled: boolean
  - default_mode: enum (`managed`, fixed to managed when enabled)
  - opt_out_selector_type: enum (`label`, `annotation`)
  - opt_out_selector_value: string
  - invalid_opt_out_behavior: enum (`ignore_and_warn`)
- Validation Rules:
  - When enabled is true, default_mode must be `managed`.
  - invalid_opt_out_behavior must keep managed egress active.

### 2. WorkloadEgressDecision

Runtime outcome per workload for outbound path selection.

- Fields:
  - workload_ref: string (`namespace/name`)
  - matched_opt_out: boolean
  - opt_out_valid: boolean
  - effective_mode: enum (`managed`, `standard`)
  - warning_emitted: boolean
- Validation Rules:
  - If matched_opt_out is true and opt_out_valid is false, effective_mode must remain `managed` and warning_emitted must be true.
  - If matched_opt_out is true and opt_out_valid is true, effective_mode may be `standard`.

### 3. ServiceLeadershipState

Tracks ownership and election health for kube-vip-managed services.

- Fields:
  - service_ref: string (`namespace/name`)
  - leader_node: string
  - election_state: enum (`healthy`, `degraded`)
  - quorum_available: boolean
  - leadership_changes_blocked: boolean
- Validation Rules:
  - When quorum_available is false, election_state must be `degraded`.
  - When quorum_available is false, leadership_changes_blocked must be true.

### 4. LoadBalancerAddressLease

Represents DHCP-backed service address lifecycle.

- Fields:
  - service_ref: string (`namespace/name`)
  - allocation_mode: enum (`dhcp`)
  - lease_state: enum (`pending`, `allocated`, `released`, `failed`)
  - address: string (nullable)
  - last_error: string (nullable)
  - retry_count: integer
- Validation Rules:
  - During DHCP unavailability, lease_state must remain `pending` with retries.
  - `allocated` requires a non-null address.

### 5. RBACBaseline

Versioned least-privilege permission contract for kube-vip components.

- Fields:
  - baseline_id: string
  - subjects: list (service accounts)
  - ruleset: list (apiGroups/resources/verbs tuples)
  - enforced_on_deploy: boolean
  - enforced_on_upgrade: boolean
  - drift_status: enum (`in_sync`, `drift_detected`, `reconciled`)
- Validation Rules:
  - enforced_on_deploy and enforced_on_upgrade must both be true.
  - `drift_detected` must transition to `reconciled` by reconciliation tasks or fail clearly.

### 6. KubeVipOperationalStatus

Operator-visible high-level state for the feature set.

- Fields:
  - egress_status: enum (`enabled`, `disabled`, `degraded`)
  - election_status: enum (`healthy`, `degraded`)
  - dhcp_status: enum (`healthy`, `degraded`, `unavailable`)
  - rbac_status: enum (`in_sync`, `reconciled`, `error`)
  - timestamp: datetime
- Validation Rules:
  - Any degraded/error sub-state must be surfaced in playbook output.

### 7. AutomatedValidationCase

Represents one feasible automated validation scenario tied to feature requirements.

- Fields:
  - case_id: string
  - capability: enum (`egress`, `service_election`, `dhcp_lease`, `rbac_binding`)
  - lifecycle_path: enum (`fresh_deploy`, `upgrade_path`)
  - execution_mode: enum (`automated`, `manual_fallback`)
  - status: enum (`pass`, `fail`, `skipped`)
  - evidence_ref: string
- Validation Rules:
  - At least one automated case per capability must exist where feasible.
  - At least one `fresh_deploy` and one `upgrade_path` automated case must be present across the full set.
  - `manual_fallback` is only valid when feasibility constraints are documented.

## Relationships

- ManagedEgressPolicy 1->N WorkloadEgressDecision
- ServiceLeadershipState 1->1 KubeVipOperationalStatus.election_status (aggregated)
- LoadBalancerAddressLease 1->1 ServiceLeadershipState by service_ref
- RBACBaseline 1->1 KubeVipOperationalStatus.rbac_status (aggregated)
- AutomatedValidationCase N->1 KubeVipOperationalStatus (aggregated verification evidence)

## State Transitions

### Egress decision

- default-managed -> explicit-opt-out-valid -> standard-egress
- default-managed -> explicit-opt-out-invalid -> managed-egress-with-warning

### Leadership under quorum events

- healthy + quorum=true -> healthy
- healthy + quorum=false -> degraded + leadership_changes_blocked=true
- degraded + quorum=true -> healthy + leadership_changes_blocked=false

### DHCP lease lifecycle

- pending -> allocated
- pending -> pending (retry on DHCP unavailable)
- allocated -> released
- pending/allocated -> failed (terminal error after policy limit)

### RBAC drift lifecycle

- in_sync -> drift_detected -> reconciled
- drift_detected -> error (if reconcile fails)

### Automated validation lifecycle

- planned -> executed -> pass
- planned -> executed -> fail
- planned -> skipped (manual_fallback with documented feasibility constraints)
