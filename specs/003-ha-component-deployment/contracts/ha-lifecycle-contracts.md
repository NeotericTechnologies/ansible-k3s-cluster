# Contracts: HA Component Deployment Lifecycle

This document defines the operational contracts that enforce topology-aware HA behavior across repository-managed components.

## Cross-Cutting Rules

- In-scope component universe is all repository-managed roles/playbooks, regardless of enablement in a specific inventory.
- HA topology is defined as `k3s_servers` count >= 3.
- Component-specific HA minimum targets are maintained at the same top-level scope as corresponding component versions.
- Explicit operator overrides are allowed and preserved.
- In HA topology, unmet targets for any enabled in-scope component are hard failures.

## Contract C-001: Topology Classification

- **Action**: Evaluate target inventory before lifecycle operation.
- **Inputs**:
  - `groups['k3s_servers']`
- **Output**:
  - `TopologyProfile.is_ha=true` when `|k3s_servers| >= 3`, else `false`.
- **Failure Conditions**:
  - Missing or invalid server group data.

## Contract C-002: HA Policy Resolution

- **Action**: Resolve per-component availability policy for all managed components.
- **Inputs**:
  - Top-level version variables and corresponding top-level HA target variables.
  - Optional inventory overrides.
- **Output**:
  - Deterministic policy map for each component (`ha_min_target`, `non_ha_default`, `effective_target`).
- **Failure Conditions**:
  - Missing HA target for any managed component.
  - HA target variable not co-located at required top-level scope.

## Contract C-003: Provisioning Enforcement (`cluster-core.yml` + `cluster-addons.yml`)

- **Action**: Apply topology-aware component behavior during cluster provisioning and addon deployment.
- **Inputs**:
  - Topology profile.
  - Effective per-component target map.
  - Component enablement flags.
- **Output**:
  - Enabled components in HA topology converge to documented minimum targets.
  - Non-HA topology preserves existing defaults unless explicitly overridden.
- **Failure Conditions**:
  - Enabled HA component does not meet its target after convergence checks.

## Contract C-004: Scale Consistency (`scale-nodes.yml`)

- **Action**: Re-apply and validate topology-aware policy after inventory-driven scale operations.
- **Inputs**:
  - Updated inventory and computed post-scale topology profile.
- **Output**:
  - HA policy remains satisfied after node add/remove operations.
- **Failure Conditions**:
  - Post-scale HA target violations for enabled components.

## Contract C-005: Upgrade Consistency (`upgrade-k3s.yml`)

- **Action**: Preserve and validate HA policy across rolling upgrades.
- **Inputs**:
  - Target `k3s_version` plus effective HA policy map.
- **Output**:
  - Component availability remains compliant with topology-specific targets during/after upgrade.
- **Failure Conditions**:
  - Upgrade completion with unmet HA target for any enabled in-scope component.

## Contract C-006: Hard-Fail Validation and Reporting

- **Action**: Perform final availability validation for enabled in-scope components.
- **Inputs**:
  - Observed runtime states per component.
  - Expected target values.
- **Output**:
  - Structured validation result per component.
  - Overall run status = fail if any HA violation occurs.
- **Failure Report Requirements**:
  - Component name.
  - Expected target.
  - Observed state.
  - Clear failure reason and remediation hint.

## Contract C-007: Critical Subset Resilience Validation

- **Action**: Execute disruption validation for explicit critical subset.
- **Critical Subset**:
  - `k3s control plane server service`
  - `kube-vip`
  - `Traefik`
- **Success Condition**:
  - Each critical component remains available for >=99% of requests over the defined test window.
- **Failure Conditions**:
  - Any critical subset component falls below threshold.
