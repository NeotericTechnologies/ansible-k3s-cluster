# Data Model: Kube-VIP Hardening

**Feature**: 006-kube-vip-hardening
**Date**: 2026-07-12

## Entities

### 1. EgressServiceProfile

Defines the documented kube-vip egress prerequisites and Service-level request shape.

- Fields:
  - enabled: boolean
  - internal_mode: boolean
  - pod_cidr: string
  - service_cidr: string
  - service_annotations: list
  - external_traffic_policy: enum (`Local`)
- Validation Rules:
  - When enabled is true, service election must also be enabled.
  - Services opting into kube-vip egress must set `externalTrafficPolicy: Local`.

### 2. ServiceEgressRequest

Represents one Service that opts into or out of kube-vip processing using documented annotations.

- Fields:
  - service_ref: string (`namespace/name`)
  - egress_enabled: boolean
  - ignored_by_kube_vip: boolean
  - external_traffic_policy: string
- Validation Rules:
  - `egress_enabled=true` requires the documented kube-vip egress annotations.
  - `ignored_by_kube_vip=true` is represented through `kube-vip.io/ignore=true`.

### 3. ServiceLeadershipState

Tracks ownership and election health for kube-vip-managed services.

- Fields:
  - service_ref: string (`namespace/name`)
  - leader_node: string
  - election_enabled: boolean
  - external_traffic_policy: string
- Validation Rules:
  - `election_enabled` is derived from kube-vip runtime configuration.
  - LoadBalancer Services used for election validation should set `externalTrafficPolicy: Local`.

### 4. LoadBalancerAddressLease

Represents DHCP-backed service address lifecycle.

- Fields:
  - service_ref: string (`namespace/name`)
  - allocation_mode: enum (`dhcp`)
  - request_surface: enum (`loadBalancerIP_zero`, `annotation_zero`, `hostname_annotation`)
  - requested_hostname: string (nullable)
  - address: string (nullable)
- Validation Rules:
  - DHCP-backed Services must use one documented request surface.
  - Hostname requests require the hostname annotation to be present.

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
  - egress_status: enum (`enabled`, `disabled`)
  - election_status: enum (`enabled`, `disabled`)
  - dhcp_status: enum (`enabled`, `disabled`)
  - rbac_status: enum (`in_sync`, `reconciled`, `error`)
  - timestamp: datetime
- Validation Rules:
  - Any error sub-state must be surfaced in playbook output.

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

### Egress service request

- enabled -> service annotations present -> eligible for kube-vip egress
- ignored -> `kube-vip.io/ignore=true` -> ignored by kube-vip

### Service election readiness

- disabled -> daemonset rendered with `svc_election=false`
- enabled -> daemonset rendered with `svc_election=true`

### DHCP lease lifecycle

- request created -> address allocation observed
- request created -> hostname annotation observed

### RBAC drift lifecycle

- in_sync -> drift_detected -> reconciled
- drift_detected -> error (if reconcile fails)

### Automated validation lifecycle

- planned -> executed -> pass
- planned -> executed -> fail
- planned -> skipped (manual_fallback with documented feasibility constraints)
