# Data Model: HA Component Deployment

## Overview

This model defines topology-aware HA policy entities and how they map to existing Ansible-managed k3s lifecycle flows.

## Entities

### 1. TopologyProfile

Represents the target cluster topology classification for a run.

- **Fields**:
  - `server_count`: Integer count of hosts in `k3s_servers`.
  - `is_ha`: Boolean derived as `server_count >= 3`.
  - `source`: Inventory-derived source identifier (group membership).

- **Validation Rules**:
  - `is_ha` MUST be `true` when `server_count >= 3`.
  - `is_ha` MUST be `false` when `server_count < 3`.

### 2. ManagedComponent

Represents one repository-managed component role/playbook target.

- **Fields**:
  - `name`: Canonical component name (e.g., `kube-vip`, `traefik`).
  - `role_name`: Role identifier in `ansible/roles`.
  - `version_var`: Top-level version variable name in `group_vars`.
  - `enabled_var`: Inventory-controlled enablement variable (if applicable).
  - `lifecycle_touchpoints`: List of playbooks where component behavior is enforced.

- **Relationships**:
  - One-to-one with `ComponentAvailabilityPolicy`.
  - Zero-or-one with `OperatorAvailabilityOverride` per run.

### 3. ComponentAvailabilityPolicy

Defines expected availability targets per component by topology.

- **Fields**:
  - `component_name`: Reference to `ManagedComponent.name`.
  - `ha_min_target`: Component-specific minimum target used when `TopologyProfile.is_ha=true`.
  - `non_ha_default`: Baseline expected behavior when `TopologyProfile.is_ha=false`.
  - `policy_var_name`: Top-level variable storing the HA target.
  - `policy_scope`: Scope location (`ansible/group_vars/all.yml`, inventory override allowed).

- **Validation Rules**:
  - `ha_min_target` MUST be defined for every managed component.
  - `policy_var_name` MUST exist at the same top-level configuration scope as `version_var`.

### 4. OperatorAvailabilityOverride

Represents explicit user intent to override default availability targets.

- **Fields**:
  - `component_name`: Target component.
  - `override_value`: User-defined target/value.
  - `source_file`: Inventory/group var file location.
  - `precedence`: Resolution precedence over defaults.

- **Validation Rules**:
  - Overrides are authoritative when present and valid.
  - Overrides MUST be preserved on reruns and across lifecycle operations.

### 5. AvailabilityValidationResult

Captures post-run validation status for each enabled in-scope component.

- **Fields**:
  - `component_name`: Component validated.
  - `topology`: `ha` or `non-ha`.
  - `expected_target`: Target resolved from policy/override.
  - `observed_state`: Observed post-run availability state.
  - `status`: `pass` or `fail`.
  - `failure_reason`: Required when status is `fail`.

- **Validation Rules**:
  - In HA topology, any `fail` on an enabled in-scope component MUST fail the run.
  - Validation output MUST identify component and unmet target.

### 6. CriticalComponentSubset

Explicit subset used for disruption validation success criteria.

- **Fields**:
  - `components`: Fixed list from spec: `k3s control plane server service`, `kube-vip`, `Traefik`.
  - `availability_threshold`: `>=99%` request availability during defined disruption test window.

- **Validation Rules**:
  - All listed components MUST be included in disruption checks for HA topology.

## Relationships Summary

- `TopologyProfile` determines which branch of `ComponentAvailabilityPolicy` applies.
- `ManagedComponent` is authoritative repository scope, independent of runtime enablement.
- `OperatorAvailabilityOverride` supersedes default policy for a component.
- `AvailabilityValidationResult` enforces hard-fail behavior in HA when targets are unmet.
- `CriticalComponentSubset` provides stricter resilience checks used by success criteria.

## State Transitions

### Topology-Aware Policy Application

1. `inventory_loaded` -> `topology_classified`
2. `topology_classified` -> `policy_resolved`
3. `policy_resolved` -> `component_config_applied`
4. `component_config_applied` -> `availability_validated`
5. `availability_validated` -> `completed` or `failed`

### Failure Transition

- When in `ha` topology and any enabled in-scope component misses target:
  - `availability_validated` -> `failed` with explicit `failure_reason`.

## Canonical In-Scope Managed Components

- `k3s-common`
- `k3s-server`
- `k3s-agent`
- `kube-vip`
- `cert-manager`
- `multus`
- `traefik`
- `rancher`
- `rancher-monitoring`
- `synology-csi`
